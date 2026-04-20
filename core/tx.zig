const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const rlp = @import("rlp.zig");

pub const EthEip1559Tx = struct {
    chain_id: u64,
    nonce: u64,
    max_priority_fee_per_gas: u128,
    max_fee_per_gas: u128,
    gas_limit: u64,
    to: ?types.EthAddress,
    value: u128,
    data: []const u8,
    access_list: []const u8 = &[_]u8{}, // Simplificado para xB77
};

pub fn buildEthEip1559Tx(allocator: std.mem.Allocator, tx: EthEip1559Tx, keypair: *const types.EthKeypair) ![]u8 {
    // Helper para codificar y añadir al buffer liberando la memoria intermedia
    const helpers = struct {
        fn encodeAndAppend(alloc: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), item: anytype) !void {
            const encoded = try rlp.encode(alloc, item);
            defer alloc.free(encoded);
            try list.appendSlice(alloc, encoded);
        }
    };

    // 1. Construir el payload para firmar
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);

    try helpers.encodeAndAppend(allocator, &list, tx.chain_id);
    try helpers.encodeAndAppend(allocator, &list, tx.nonce);
    try helpers.encodeAndAppend(allocator, &list, tx.max_priority_fee_per_gas);
    try helpers.encodeAndAppend(allocator, &list, tx.max_fee_per_gas);
    try helpers.encodeAndAppend(allocator, &list, tx.gas_limit);
    
    if (tx.to) |addr| {
        try helpers.encodeAndAppend(allocator, &list, &addr);
    } else {
        try helpers.encodeAndAppend(allocator, &list, "");
    }
    
    try helpers.encodeAndAppend(allocator, &list, tx.value);
    try helpers.encodeAndAppend(allocator, &list, tx.data);
    
    const empty_access_list = try rlp.encodeListFixed(allocator, "");
    defer allocator.free(empty_access_list);
    try list.appendSlice(allocator, empty_access_list);

    const encoded_fields = try rlp.encodeListFixed(allocator, list.items);
    defer allocator.free(encoded_fields);

    // 2. Hash del payload prefijado con 0x02
    var sig_payload = try allocator.alloc(u8, 1 + encoded_fields.len);
    defer allocator.free(sig_payload);
    sig_payload[0] = 0x02;
    @memcpy(sig_payload[1..], encoded_fields);

    var msg_hash: [32]u8 = undefined;
    crypto.Keccak256.hash(sig_payload, &msg_hash, .{});

    // 3. Firmar el hash
    const signature = try crypto.signEthMessage(msg_hash, keypair.secret);

    // 4. Construir RLP final: [chain_id, nonce, ..., v, r, s]
    list.clearRetainingCapacity();
    try helpers.encodeAndAppend(allocator, &list, tx.chain_id);
    try helpers.encodeAndAppend(allocator, &list, tx.nonce);
    try helpers.encodeAndAppend(allocator, &list, tx.max_priority_fee_per_gas);
    try helpers.encodeAndAppend(allocator, &list, tx.max_fee_per_gas);
    try helpers.encodeAndAppend(allocator, &list, tx.gas_limit);
    
    if (tx.to) |addr| {
        try helpers.encodeAndAppend(allocator, &list, &addr);
    } else {
        try helpers.encodeAndAppend(allocator, &list, "");
    }
    
    try helpers.encodeAndAppend(allocator, &list, tx.value);
    try helpers.encodeAndAppend(allocator, &list, tx.data);
    try list.appendSlice(allocator, empty_access_list); // Reutilizamos el access list vacio
    
    try helpers.encodeAndAppend(allocator, &list, signature.v);
    try helpers.encodeAndAppend(allocator, &list, &signature.r);
    try helpers.encodeAndAppend(allocator, &list, &signature.s);

    const final_list = try rlp.encodeListFixed(allocator, list.items);
    defer allocator.free(final_list);

    var result = try allocator.alloc(u8, 1 + final_list.len);
    result[0] = 0x02;
    @memcpy(result[1..], final_list);
    
    return result;
}

/// Serialización de Compact-u16 (formato Solana).
pub fn writeCompactU16(writer: anytype, value: u16) !void {
    var val = value;
    while (true) {
        var byte: u8 = @intCast(val & 0x7F);
        val >>= 7;
        if (val > 0) {
            byte |= 0x80;
        }
        try writer.writeByte(byte);
        if (val == 0) break;
    }
}

pub const AccountMeta = struct {
    pubkey: types.Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub const Instruction = struct {
    program_id: types.Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

pub const Transfer = struct {
    to: types.Pubkey,
    lamports: u64,
};

/// Construye una transacción con múltiples transferencias (System Program).
pub fn buildMultiTransferTx(
    allocator: std.mem.Allocator,
    from: types.Pubkey,
    transfers: []const Transfer,
    recent_blockhash: types.Hash,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Recolectar llaves únicas
    // Las llaves siempre son: [0] From, [1..N] Recipients, [Last] System Program
    var keys = std.ArrayListUnmanaged(types.Pubkey){};
    defer keys.deinit(allocator);
    try keys.append(allocator, from);
    for (transfers) |t| {
        // Evitar duplicados si enviamos a varias cuentas o a nosotros mismos (raro pero posible)
        var found = false;
        for (keys.items) |k| {
            if (std.mem.eql(u8, &k, &t.to)) {
                found = true;
                break;
            }
        }
        if (!found) try keys.append(allocator, t.to);
    }
    const system_program_idx = @as(u8, @intCast(keys.items.len));
    const system_program = [_]u8{0} ** 32;
    try keys.append(allocator, system_program);

    // --- SERIALIZACIÓN ---
    
    // Firmas (1 sola requerida: From)
    try writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // Header: num_required_sigs=1, num_readonly_signed=0, num_readonly_unsigned=1 (System Program)
    try writer.writeByte(1);
    try writer.writeByte(0);
    try writer.writeByte(1);

    // Account Keys
    try writeCompactU16(writer, @intCast(keys.items.len));
    for (keys.items) |k| try buf.appendSlice(allocator, &k);

    // Recent Blockhash
    try buf.appendSlice(allocator, &recent_blockhash);

    // Instructions
    try writeCompactU16(writer, @intCast(transfers.len));
    for (transfers) |t| {
        // Encontrar índice del recipient
        var recipient_idx: u8 = 0;
        for (keys.items, 0..) |k, i| {
            if (std.mem.eql(u8, &k, &t.to)) {
                recipient_idx = @intCast(i);
                break;
            }
        }

        try writer.writeByte(system_program_idx); // Program ID Index
        try writeCompactU16(writer, 2); // 2 accounts: from, to
        try writer.writeByte(0); // From (siempre es el 0)
        try writer.writeByte(recipient_idx);

        // Data (12 bytes: u32 instruction_type=2, u64 lamports)
        try writeCompactU16(writer, 12);
        try writer.writeInt(u32, 2, .little);
        try writer.writeInt(u64, t.lamports, .little);
    }

    return buf.toOwnedSlice(allocator);
}

/// Construye una transacción de transferencia simple (System Program).
pub fn buildTransferTx(
    allocator: std.mem.Allocator,
    from: types.Pubkey,
    to: types.Pubkey,
    lamports: u64,
    recent_blockhash: types.Hash,
) ![]u8 {
    const transfers = [_]Transfer{.{ .to = to, .lamports = lamports }};
    return buildMultiTransferTx(allocator, from, &transfers, recent_blockhash);
}

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

pub fn buildEthEip1559Tx(allocator: std.mem.Allocator, tx: EthEip1559Tx) ![]u8 {
    // Para EIP-1559, firmamos: rlp([chain_id, nonce, max_priority_fee, max_fee, gas_limit, destination, amount, data, access_list])
    // Prefijado con 0x02.

    var list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (list.items) |i| allocator.free(i);
        list.deinit();
    }

    try list.append(try rlp.encode(allocator, tx.chain_id));
    try list.append(try rlp.encode(allocator, tx.nonce));
    try list.append(try rlp.encode(allocator, tx.max_priority_fee_per_gas));
    try list.append(try rlp.encode(allocator, tx.max_fee_per_gas));
    try list.append(try rlp.encode(allocator, tx.gas_limit));
    
    if (tx.to) |addr| {
        try list.append(try rlp.encode(allocator, &addr));
    } else {
        try list.append(try rlp.encode(allocator, &[_]u8{}));
    }
    
    try list.append(try rlp.encode(allocator, tx.value));
    try list.append(try rlp.encode(allocator, tx.data));
    
    // Access list (vacia por ahora)
    try list.append(try rlp.encode(allocator, tx.access_list));

    // Consolidar lista en RLP
    var payload = std.ArrayList(u8).init(allocator);
    defer payload.deinit();
    for (list.items) |i| try payload.appendSlice(i);

    const encoded_list = try rlp.encodeListFixed(allocator, payload.items);
    defer allocator.free(encoded_list);

    var result = try allocator.alloc(u8, 1 + encoded_list.len);
    result[0] = 0x02; // EIP-1559 type prefix
    @memcpy(result[1..], encoded_list);
    
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

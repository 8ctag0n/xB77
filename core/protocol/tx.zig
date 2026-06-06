const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../security/crypto.zig");
const rlp = @import("../protocol/rlp.zig");

pub const Transfer = struct {
    to: types.Pubkey,
    lamports: u64,
};

/// Build a Solana transaction that sends lamports to one or more recipients.
/// Optional facilitator receives a fee from each transfer.
pub fn buildMultiTransferTx(
    allocator: std.mem.Allocator,
    payer: types.Pubkey,
    transfers: []const Transfer,
    blockhash: [32]u8,
    fee_lamports: u64,
    facilitator: ?types.Pubkey,
) ![]u8 {
    const use_compute_budget = fee_lamports > 0;
    var buf = std.ArrayListUnmanaged(u8).empty;
    defer buf.deinit(allocator);

    // 1 sig placeholder
    try appendCompactU16(allocator, &buf, 1);
    try buf.appendNTimes(allocator, 0, 64);

    const msg_start = buf.items.len;
    try buf.append(allocator, 1); // num_required_signatures
    try buf.append(allocator, 0); // num_readonly_signed
    var num_readonly: u8 = if (facilitator != null) 2 else 1; // system_program [+ fac]
    if (use_compute_budget) num_readonly += 1;
    try buf.append(allocator, num_readonly);

    // Build account list: payer, each recipient (deduped), [facilitator,] system_program, [compute_budget]
    var accounts = std.ArrayListUnmanaged(types.Pubkey).empty;
    defer accounts.deinit(allocator);
    try accounts.append(allocator, payer);
    for (transfers) |t| {
        var found = false;
        for (accounts.items) |a| {
            if (std.mem.eql(u8, &a, &t.to)) { found = true; break; }
        }
        if (!found) try accounts.append(allocator, t.to);
    }
    if (facilitator) |f| try accounts.append(allocator, f);
    const system_program = [_]u8{0} ** 32;
    try accounts.append(allocator, system_program);
    if (use_compute_budget) {
        const cb = try crypto.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");
        try accounts.append(allocator, cb);
    }

    try appendCompactU16(allocator, &buf, @intCast(accounts.items.len));
    for (accounts.items) |a| try buf.appendSlice(allocator, &a);
    try buf.appendSlice(allocator, &blockhash);

    // Instructions: [ComputeBudget::SetComputeUnitPrice] + N SystemProgram::Transfer
    const num_ix: u16 = @intCast(transfers.len + @intFromBool(use_compute_budget));
    try appendCompactU16(allocator, &buf, num_ix);

    if (use_compute_budget) {
        const cb_idx: u8 = @intCast(accounts.items.len - 1);
        try buf.append(allocator, cb_idx);
        try appendCompactU16(allocator, &buf, 0); // no accounts
        // SetComputeUnitPrice: discriminator=3, micro_lamports u64 LE
        var cb_data: [9]u8 = undefined;
        cb_data[0] = 3;
        std.mem.writeInt(u64, cb_data[1..9], fee_lamports, .little);
        try appendCompactU16(allocator, &buf, 9);
        try buf.appendSlice(allocator, &cb_data);
    }

    const sys_idx: u8 = @intCast(accounts.items.len - 1 - @intFromBool(use_compute_budget));
    for (transfers) |t| {
        try buf.append(allocator, sys_idx); // program = system
        try appendCompactU16(allocator, &buf, 2); // 2 accounts: payer, to
        try buf.append(allocator, 0); // payer
        // find recipient index
        var to_idx: u8 = 1;
        for (accounts.items, 0..) |a, i| {
            if (std.mem.eql(u8, &a, &t.to)) { to_idx = @intCast(i); break; }
        }
        try buf.append(allocator, to_idx);
        // SystemProgram::Transfer ix data: discriminator=2 (u32 LE) + lamports (u64 LE)
        var ix_data: [12]u8 = undefined;
        std.mem.writeInt(u32, ix_data[0..4], 2, .little);
        std.mem.writeInt(u64, ix_data[4..12], t.lamports, .little);
        try appendCompactU16(allocator, &buf, 12);
        try buf.appendSlice(allocator, &ix_data);
    }

    _ = msg_start;
    return buf.toOwnedSlice(allocator);
}

/// Build an SPL Token transfer transaction (associated token accounts assumed to exist).
pub fn buildSplTransferTx(
    allocator: std.mem.Allocator,
    payer: types.Pubkey,
    mint: []const u8,
    owner: types.Pubkey,
    recipient: types.Pubkey,
    amount: u64,
    blockhash: [32]u8,
) ![]u8 {
    _ = mint;
    _ = owner;
    // Simplified: treat as a regular transfer for compilation; real SPL transfer
    // would derive ATAs and invoke the SPL Token program.
    const transfers = [_]Transfer{.{ .to = recipient, .lamports = amount }};
    return buildMultiTransferTx(allocator, payer, &transfers, blockhash, 0, null);
}

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
    var list = std.ArrayListUnmanaged(u8).empty;
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

/// Serialización de Compact-u16 (formato Solana) para ArrayList.
pub fn appendCompactU16(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), value: u16) !void {
    var val = value;
    while (true) {
        var byte: u8 = @intCast(val & 0x7F);
        val >>= 7;
        if (val > 0) {
            byte |= 0x80;
        }
        try list.append(allocator, byte);
        if (val == 0) break;
    }
}

/// Borsh Serialization Helpers (Solana/Rust compatibility) for ArrayList
pub const borsh = struct {
    pub fn appendU64(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), val: u64) !void {
        var buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &buf, val, .little);
        try list.appendSlice(allocator, &buf);
    }

    pub fn appendVecU8(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), data: []const u8) !void {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, @intCast(data.len), .little);
        try list.appendSlice(allocator, &buf);
        try list.appendSlice(allocator, data);
    }
};

/// Construye la data de la instrucción 'AnchorStateZk' para el programa xB77 (Batch Mode).
pub fn buildAnchorStateZkInstruction(
    allocator: std.mem.Allocator,
    initial_root: [32]u8,
    final_root: [32]u8,
    indices: [5]u64,
    siblings: [5][14][32]u8,
    amounts: [5]u64,
    entry_types: [5]u8,
    tx_hashes: [5][32]u8,
    total_tax: u64,
    zk_proof: []const u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    // 1. Discriminador del Enum CoreInstruction::AnchorStateZk (4) - 4 bytes LE
    var disc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &disc_buf, 4, .little);
    try buf.appendSlice(allocator, &disc_buf);

    // 2. Payload serializado (Borsh-compatible)
    try buf.appendSlice(allocator, &initial_root);
    try buf.appendSlice(allocator, &final_root);
    
    // indices [u64; 5]
    for (indices) |idx| try borsh.appendU64(allocator, &buf, idx);
    
    // siblings [[ [u8; 32]; 14]; 5]
    for (siblings) |batch_s| {
        for (batch_s) |s| {
            try buf.appendSlice(allocator, &s);
        }
    }
    
    for (amounts) |amt| try borsh.appendU64(allocator, &buf, amt);
    for (entry_types) |t| try buf.append(allocator, t);
    for (tx_hashes) |h| try buf.appendSlice(allocator, &h);
    
    try borsh.appendU64(allocator, &buf, total_tax);
    
    // Vec<u8> (zk_proof)
    try borsh.appendVecU8(allocator, &buf, zk_proof);

    return buf.toOwnedSlice(allocator);
}

pub fn buildInitMerchantInstruction(
    allocator: std.mem.Allocator,
    merchant_id: [32]u8,
    methods: u64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    const discriminator = [_]u8{ 0xd1, 0x0b, 0xd6, 0xc3, 0xde, 0x9d, 0x7c, 0xc0 };
    try buf.appendSlice(allocator, &discriminator);
    try borsh.appendVecU8(allocator, &buf, &merchant_id);
    try borsh.appendU64(allocator, &buf, methods);

    return buf.toOwnedSlice(allocator);
}

pub fn buildAddCatalogInstruction(
    allocator: std.mem.Allocator,
    merchant_id: [32]u8,
    catalog_id: u64,
    category: u8,
    catalog_url: []const u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    const discriminator = [_]u8{ 0xf5, 0xa5, 0x19, 0xd1, 0xd4, 0x7f, 0xe2, 0x1f };
    try buf.appendSlice(allocator, &discriminator);
    try borsh.appendVecU8(allocator, &buf, &merchant_id);
    try borsh.appendU64(allocator, &buf, catalog_id);
    try buf.append(allocator, category);
    try borsh.appendVecU8(allocator, &buf, catalog_url);
    try buf.append(allocator, 0); // None

    return buf.toOwnedSlice(allocator);
}

pub fn buildOpenPerSessionInstruction(
    allocator: std.mem.Allocator,
    amount: u64,
    session_id: [32]u8,
    expiry: i64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    var disc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &disc_buf, 5, .little);
    try buf.appendSlice(allocator, &disc_buf);

    try borsh.appendU64(allocator, &buf, amount);
    try buf.appendSlice(allocator, &session_id);
    try borsh.appendU64(allocator, &buf, @bitCast(expiry));

    return buf.toOwnedSlice(allocator);
}

pub fn buildRegisterAgentInstruction(
    allocator: std.mem.Allocator,
    agent_id: [32]u8,
    initial_limit: u64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    var disc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &disc_buf, 1, .little);
    try buf.appendSlice(allocator, &disc_buf);

    try buf.appendSlice(allocator, &agent_id);
    try borsh.appendU64(allocator, &buf, initial_limit);

    return buf.toOwnedSlice(allocator);
}

pub fn buildRequestPaymentInstruction(
    allocator: std.mem.Allocator,
    request_id: u64,
    amount: u64,
    vendor: [32]u8,
    memo_hash: [32]u8,
    zk_proof: []const u8,
    current_root: [32]u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    var disc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &disc_buf, 3, .little);
    try buf.appendSlice(allocator, &disc_buf);

    try borsh.appendU64(allocator, &buf, request_id);
    try borsh.appendU64(allocator, &buf, amount);
    try buf.appendSlice(allocator, &vendor);
    try buf.appendSlice(allocator, &memo_hash);
    try borsh.appendVecU8(allocator, &buf, zk_proof);
    try buf.appendSlice(allocator, &current_root);

    return buf.toOwnedSlice(allocator);
}

pub fn buildClosePerSessionInstruction(
    allocator: std.mem.Allocator,
    session_id: [32]u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    try buf.append(allocator, 6);
    try buf.appendSlice(allocator, &session_id);

    return buf.toOwnedSlice(allocator);
}

pub fn buildMemoTx(allocator: std.mem.Allocator, payer: types.Pubkey, memo: []const u8, blockhash: [32]u8) ![]u8 {
    const memo_program = [_]u8{
        0x05, 0x4a, 0x53, 0x53, 0x6f, 0x72, 0x71, 0x34,
        0x54, 0x48, 0x41, 0x71, 0x59, 0x66, 0x35, 0x35,
        0x74, 0x62, 0x6e, 0x35, 0x36, 0x57, 0x63, 0x41,
        0x72, 0x59, 0x46, 0x58, 0x77, 0x6a, 0x4b, 0x78,
    }; // MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr
    var buf = std.ArrayListUnmanaged(u8).empty;
    defer buf.deinit(allocator);
    // 1 signature placeholder
    try appendCompactU16(allocator, &buf, 1);
    try buf.appendNTimes(allocator, 0, 64);
    const msg_start = buf.items.len;
    try buf.append(allocator, 1); // num_sigs
    try buf.append(allocator, 0); // num_signed_readonly
    try buf.append(allocator, 1); // num_unsigned_readonly (memo program)
    try appendCompactU16(allocator, &buf, 2); // payer + memo_program
    try buf.appendSlice(allocator, &payer);
    try buf.appendSlice(allocator, &memo_program);
    try buf.appendSlice(allocator, &blockhash);
    try appendCompactU16(allocator, &buf, 1); // 1 instruction
    try buf.append(allocator, 1); // program index
    try appendCompactU16(allocator, &buf, 0); // 0 accounts
    try appendCompactU16(allocator, &buf, @intCast(memo.len));
    try buf.appendSlice(allocator, memo);
    _ = msg_start;
    return buf.toOwnedSlice(allocator);
}

pub fn writeCompactU16(writer: anytype, value: u16) !void {
    if (value < 0x80) {
        try writer.writeByte(@intCast(value));
    } else if (value < 0x4000) {
        try writer.writeByte(@intCast((value & 0x7F) | 0x80));
        try writer.writeByte(@intCast(value >> 7));
    } else {
        try writer.writeByte(@intCast((value & 0x7F) | 0x80));
        try writer.writeByte(@intCast(((value >> 7) & 0x7F) | 0x80));
        try writer.writeByte(@intCast(value >> 14));
    }
}

pub fn signTx(tx_buf: []u8, keypair: *const types.Keypair) void {
    const message = tx_buf[65..];
    const signature = crypto.sign(message, keypair);
    @memcpy(tx_buf[1..65], &signature);
}

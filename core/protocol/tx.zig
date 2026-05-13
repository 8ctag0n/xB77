const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../security/crypto.zig");
const rlp = @import("../protocol/rlp.zig");

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

/// Borsh Serialization Helpers (Solana/Rust compatibility)
pub const borsh = struct {
    pub fn writeU64(writer: anytype, val: u64) !void {
        try writer.writeInt(u64, val, .little);
    }

    pub fn writeVecU8(writer: anytype, data: []const u8) !void {
        try writer.writeInt(u32, @intCast(data.len), .little);
        try writer.writeAll(data);
    }

    pub fn writePubkey(writer: anytype, pk: types.Pubkey) !void {
        try writer.writeAll(&pk);
    }
};

/// Construye la data de la instrucción 'InitMerchant' para el registro xB77.
pub fn buildInitMerchantInstruction(
    allocator: std.mem.Allocator,
    merchant_id: [32]u8,
    methods: u64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador Anchor (8 bytes): SHA256("global:init_merchant")[0..8]
    const discriminator = [_]u8{ 0xd1, 0x0b, 0xd6, 0xc3, 0xde, 0x9d, 0x7c, 0xc0 };
    try writer.writeAll(&discriminator);

    // 2. Payload: merchantId (bytes -> u32 len + data)
    try borsh.writeVecU8(writer, &merchant_id);

    // 3. Payload: supportedMethods (u64)
    try borsh.writeU64(writer, methods);

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'AddCatalog' para el registro xB77.
pub fn buildAddCatalogInstruction(
    allocator: std.mem.Allocator,
    merchant_id: [32]u8,
    catalog_id: u64,
    category: u8,
    catalog_url: []const u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador Anchor (8 bytes): SHA256("global:add_catalog")[0..8]
    const discriminator = [_]u8{ 0xf5, 0xa5, 0x19, 0xd1, 0xd4, 0x7f, 0xe2, 0x1f };
    try writer.writeAll(&discriminator);

    // 2. Payload: merchantId
    try borsh.writeVecU8(writer, &merchant_id);

    // 3. Payload: catalogId
    try borsh.writeU64(writer, catalog_id);

    // 4. Payload: category
    try writer.writeByte(category);

    // 5. Payload: catalogUrl (bytes)
    try borsh.writeVecU8(writer, catalog_url);

    // 6. Payload: metadataHash (Option<[u8; 32]> -> None = 0)
    try writer.writeByte(0);

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'AnchorStateZk' para el programa xB77 (Batch Mode).
/// Formato: [Discriminador (4)] + [Payload serializado con Borsh]
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
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador del Enum CoreInstruction::AnchorStateZk (4) - 4 bytes LE
    try writer.writeInt(u32, 4, .little);

    // 2. Payload serializado (Borsh-compatible)
    try writer.writeAll(&initial_root);
    try writer.writeAll(&final_root);
    
    // indices [u64; 5]
    for (indices) |idx| try borsh.writeU64(writer, idx);
    
    // siblings [[ [u8; 32]; 14]; 5]
    for (siblings) |batch_s| {
        for (batch_s) |s| {
            try writer.writeAll(&s);
        }
    }
    
    for (amounts) |amt| try borsh.writeU64(writer, amt);
    for (entry_types) |t| try writer.writeByte(t);
    for (tx_hashes) |h| try writer.writeAll(&h);
    
    try borsh.writeU64(writer, total_tax);
    
    // Vec<u8> (zk_proof)
    try borsh.writeVecU8(writer, zk_proof);

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'OpenPerSession' para el programa xB77.
pub fn buildOpenPerSessionInstruction(
    allocator: std.mem.Allocator,
    amount: u64,
    session_id: [32]u8,
    expiry: i64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador del Enum CoreInstruction::OpenPerSession (5) - 4 bytes LE
    try writer.writeInt(u32, 5, .little);

    // 2. Payload serializado
    try borsh.writeU64(writer, amount);
    try writer.writeAll(&session_id);
    try borsh.writeU64(writer, @bitCast(expiry));

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'RegisterAgent' para el programa xB77.
pub fn buildRegisterAgentInstruction(
    allocator: std.mem.Allocator,
    agent_id: [32]u8,
    initial_limit: u64,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador del Enum CoreInstruction::RegisterAgent (1) - 4 bytes LE
    try writer.writeInt(u32, 1, .little);

    // 2. Payload serializado
    try writer.writeAll(&agent_id);
    try borsh.writeU64(writer, initial_limit);

    return buf.toOwnedSlice(allocator);
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

/// Construye una transacción de transferencia de SPL Token.
/// Nota: Simplificado para el demo (asume que la cuenta asociada ya existe).
pub fn buildSplTransferTx(
    allocator: std.mem.Allocator,
    signer: types.Pubkey,
    token_mint: types.Pubkey,
    source_ata: types.Pubkey,
    dest_ata: types.Pubkey,
    amount: u64,
    recent_blockhash: types.Hash,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    const token_program = try crypto.stringToPubkey(allocator, "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
    
    // Firmas
    try writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // Message Header
    try writer.writeByte(1); // 1 required sig
    try writer.writeByte(0); // 0 readonly signed
    try writer.writeByte(2); // 2 readonly unsigned (mint, program)

    // Accounts
    try writeCompactU16(writer, 5);
    try buf.appendSlice(allocator, &signer);
    try buf.appendSlice(allocator, &source_ata);
    try buf.appendSlice(allocator, &dest_ata);
    try buf.appendSlice(allocator, &token_mint);
    try buf.appendSlice(allocator, &token_program);

    try buf.appendSlice(allocator, &recent_blockhash);

    // Instructions
    try writeCompactU16(writer, 1);
    try writer.writeByte(4); // Program index (token_program)
    try writeCompactU16(writer, 3); // 3 accounts
    try writer.writeByte(1); // Source
    try writer.writeByte(2); // Dest
    try writer.writeByte(0); // Authority (Signer)

    // Data: [3 (Transfer instruction index)] + [amount (u64)]
    try writeCompactU16(writer, 9);
    try writer.writeByte(3);
    try writer.writeInt(u64, amount, .little);

    return buf.toOwnedSlice(allocator);
}

/// Construye una transacción con múltiples transferencias (System Program)
/// y opcionalmente una Priority Fee (Compute Budget).
pub fn buildMultiTransferTx(
    allocator: std.mem.Allocator,
    from: types.Pubkey,
    transfers: []const Transfer,
    recent_blockhash: types.Hash,
    priority_fee: ?u64,
    facilitator: ?types.Pubkey,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Recolectar llaves únicas
    var keys = std.ArrayListUnmanaged(types.Pubkey){};
    defer keys.deinit(allocator);
    try keys.append(allocator, from);

    // Final transfers with tax if applicable
    var final_transfers = std.ArrayListUnmanaged(Transfer){};
    defer final_transfers.deinit(allocator);
    try final_transfers.appendSlice(allocator, transfers);

    if (facilitator) |fac_key| {
        var total: u64 = 0;
        for (transfers) |t| total += t.lamports;
        // 2.011% Infra + Tx Tax
        const tax = (total * 2011) / 100000;
        if (tax > 0) {
            try final_transfers.append(allocator, .{ .to = fac_key, .lamports = tax });
            std.debug.print("[Tx] Applied 2.011% Hosted Infra Tax: {d} lamports\n", .{tax});
        }
    }

    for (final_transfers.items) |t| {
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

    var compute_budget_idx: ?u8 = null;
    if (priority_fee != null) {
        compute_budget_idx = @as(u8, @intCast(keys.items.len));
        // Compute Budget Program ID
        const cb_program = try crypto.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");
        try keys.append(allocator, cb_program);
    }

    // --- SERIALIZACIÓN ---
    
    // Firmas (1 sola requerida: From)
    try writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // Header: num_required_sigs=1, num_readonly_signed=0, num_readonly_unsigned=X
    // El System Program y Compute Budget son readonly unsigned.
    const num_readonly_unsigned = 1 + (if (priority_fee != null) @as(u8, 1) else 0);
    try writer.writeByte(1);
    try writer.writeByte(0);
    try writer.writeByte(num_readonly_unsigned);

    // Account Keys
    try writeCompactU16(writer, @intCast(keys.items.len));
    for (keys.items) |k| try buf.appendSlice(allocator, &k);

    // Recent Blockhash
    try buf.appendSlice(allocator, &recent_blockhash);

    // Instructions
    const num_instructions = final_transfers.items.len + (if (priority_fee != null) @as(usize, 1) else 0);
    try writeCompactU16(writer, @intCast(num_instructions));

    // 1. Priority Fee Instruction (si existe)
    if (priority_fee) |fee| {
        try writer.writeByte(compute_budget_idx.?);
        try writeCompactU16(writer, 0); // 0 accounts
        
        // Data: u8 instruction_type=3 (SetComputeUnitPrice), u64 micro_lamports
        try writeCompactU16(writer, 9);
        try writer.writeByte(3);
        try writer.writeInt(u64, fee, .little);
    }

    // 2. Transfer Instructions
    for (final_transfers.items) |t| {
        var recipient_idx: u8 = 0;
        for (keys.items, 0..) |k, i| {
            if (std.mem.eql(u8, &k, &t.to)) {
                recipient_idx = @intCast(i);
                break;
            }
        }

        try writer.writeByte(system_program_idx);
        try writeCompactU16(writer, 2);
        try writer.writeByte(0); // From
        try writer.writeByte(recipient_idx);

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
    facilitator: ?types.Pubkey,
) ![]u8 {
    const transfers = [_]Transfer{.{ .to = to, .lamports = lamports }};
    return buildMultiTransferTx(allocator, from, &transfers, recent_blockhash, null, facilitator);
}

/// Construye una transacción con una instrucción Memo para anclaje de datos off-chain.
pub fn buildMemoTx(
    allocator: std.mem.Allocator,
    signer: types.Pubkey,
    memo_data: []const u8,
    recent_blockhash: types.Hash,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    const memo_program = try crypto.stringToPubkey(allocator, "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");

    // --- SERIALIZACIÓN ---
    
    // 1. Array de Firmas (1 firma: del signer, rellena con ceros por ahora)
    try writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // --- INICIO DEL MENSAJE (Lo que se firma) ---
    
    // 2. Cabecera del Mensaje
    try writer.writeByte(1); // num_required_signatures
    try writer.writeByte(0); // num_readonly_signed_accounts
    try writer.writeByte(1); // num_readonly_unsigned_accounts (el Memo Program)

    // 3. Claves de Cuentas (Signer, Memo Program)
    try writeCompactU16(writer, 2);
    try writer.writeAll(&signer);
    try writer.writeAll(&memo_program);

    // 4. Blockhash Reciente
    try writer.writeAll(&recent_blockhash);

    // 5. Instrucciones
    try writeCompactU16(writer, 1); // 1 instrucción

    // Memo Instruction
    try writer.writeByte(1); // Program ID index (1 = memo_program)
    
    // Cuentas de la instrucción: 1 (signer)
    try writeCompactU16(writer, 1);
    try writer.writeByte(0); // Account index (0 = signer)

    // Data del Memo
    try writeCompactU16(writer, @intCast(memo_data.len));
    try writer.writeAll(memo_data);

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'RequestPayment' para el programa xB77.
/// Formato: [Discriminador (1)] + Payload { request_id, amount, vendor, memo_hash, zk_proof, current_root }
pub fn buildRequestPaymentInstruction(
    allocator: std.mem.Allocator,
    request_id: u64,
    amount: u64,
    vendor: [32]u8,
    memo_hash: [32]u8,
    zk_proof: []const u8,
    current_root: [32]u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador del Enum CoreInstruction::RequestPayment
    // Rust Enum: InitCore=0, RegisterAgent=1, VerifyAndCredit=2, RequestPayment=3
    try writer.writeInt(u32, 3, .little);

    // 2. Payload
    try borsh.writeU64(writer, request_id);
    try borsh.writeU64(writer, amount);
    try writer.writeAll(&vendor);
    try writer.writeAll(&memo_hash);
    
    // xB77 Sovereign Compression params
    try borsh.writeVecU8(writer, zk_proof);
    try writer.writeAll(&current_root);

    return buf.toOwnedSlice(allocator);
}

/// Construye la data de la instrucción 'ClosePerSession' para el programa xB77.
pub fn buildClosePerSessionInstruction(
    allocator: std.mem.Allocator,
    session_id: [32]u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1. Discriminador del Enum CoreInstruction::ClosePerSession (6)
    try writer.writeByte(6);

    // 2. Payload serializado
    try writer.writeAll(&session_id);

    return buf.toOwnedSlice(allocator);
}

/// Firma una transacción in-place.
/// Asume que el buffer empieza con [1] (compact-u16 para 1 firma),
/// seguido de 64 bytes reservados para la firma,
/// y luego el cuerpo del mensaje.
pub fn signTx(tx_buf: []u8, keypair: *const types.Keypair) void {
    // El mensaje comienza después del byte de longitud de firmas (1) y los 64 bytes de la firma
    const message = tx_buf[65..];
    
    // Solana firma directamente el buffer del mensaje con Ed25519 (sin pre-hashing)
    const signature = crypto.sign(message, keypair);
    
    // Inyectamos la firma en el espacio reservado
    @memcpy(tx_buf[1..65], &signature);
}

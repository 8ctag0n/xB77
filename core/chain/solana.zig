const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const http = @import("../net/http.zig");

pub const SignatureInfo = struct {
    signature: []const u8,
    slot: u64,
    err: bool,
};

pub const SolanaClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    http_client: http.HttpClient,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) SolanaClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .http_client = http.HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *SolanaClient) void {
        _ = self;
    }

    pub fn getBalance(self: *SolanaClient, address: []const u8) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getBalance","params":["{s}", {{"commitment": "confirmed"}}]}}
        , .{address});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        // Estructura de Solana: { "jsonrpc": "2.0", "result": { "context": { "slot": 1 }, "value": 0 }, "id": 1 }
        const result = parsed.value.object.get("result") orelse {
            std.debug.print("\n[SOLANA] ❌ Error in response: {s}", .{response.body});
            return error.InvalidResponse;
        };
        const value = result.object.get("value") orelse return error.InvalidResponse;

        return @intCast(value.integer);
    }

    /// Obtiene la data cruda de una cuenta en base64.
    pub fn getAccountInfo(self: *SolanaClient, address: []const u8) ![]u8 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getAccountInfo","params":["{s}", {{"encoding": "base64", "commitment": "confirmed"}}]}}
        , .{address});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();
        
        if (response.status != 200) {
            std.debug.print("\n[SOLANA] RPC Error {d}: {s}", .{response.status, response.body});
            return error.RpcError;
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{
            .ignore_unknown_fields = true,
        }) catch |err| {
            std.debug.print("\n[SOLANA] JSON Parse Error: {any}. Body: {s}", .{err, response.body});
            return err;
        };
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        if (result == .null) return error.AccountNotFound;
        
        const value = result.object.get("value") orelse return error.AccountNotFound;
        if (value == .null) return error.AccountNotFound;

        const data_array = value.object.get("data") orelse return error.InvalidResponse;
        const base64_data = data_array.array.items[0].string;

        const decoder = std.base64.standard.Decoder;
        const decoded_len = try decoder.calcSizeForSlice(base64_data);
        const decoded_buf = try self.allocator.alloc(u8, decoded_len);
        try decoder.decode(decoded_buf, base64_data);
        
        return decoded_buf;
    }

    /// Solicita fondos al faucet del nodo local/devnet
    pub fn requestAirdrop(self: *SolanaClient, address: []const u8, lamports: u64) !void {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"requestAirdrop","params":["{s}", {d}]}}
        , .{address, lamports});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("error")) |err| {
            std.debug.print("\n[SOLANA] ❌ Airdrop failed: {any}", .{err});
            return error.AirdropFailed;
        }
        std.debug.print("\n[SOLANA] 💸 Airdrop requested for {s} ({d} lamports)", .{address, lamports});
    }

    /// Anclaje de Estado Soberano (L1 Anchoring) Real
    /// Envía el Root del CMT y la Prueba ZK al programa xB77 en Solana.
    pub fn anchorMeshState(self: *SolanaClient, root: [32]u8, proof: []const u8, signer_kp: *const types.Keypair) ![]u8 {
        const tx_mod = @import("../protocol/tx.zig");
        std.debug.print("\n[SOLANA] ⚓ Anchoring Mesh State (ZK) to L1...", .{});

        // 1. Obtener Blockhash fresco y Priority Fee
        const blockhash = try self.getLatestBlockhash();
        const signer_pubkey = signer_kp.public;
        const signer_addr = try crypto.pubkeyToString(self.allocator, &signer_pubkey);
        defer self.allocator.free(signer_addr);
        
        const priority_fee = try self.getQuickNodePriorityFee(signer_addr);
        std.debug.print("\n[SOLANA] 🚀 Dynamic Priority Fee: {d} micro-lamports", .{priority_fee});

        // 2. Construir la data de la instrucción
        const ix_data = try tx_mod.buildAnchorStateZkInstruction(self.allocator, root, proof);
        defer self.allocator.free(ix_data);

        // 3. Definir el Programa (xB77 Core) y Cuentas
        const program_id = try crypto.stringToPubkey(self.allocator, "FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv");

        // 4. Construir la Transacción (Genérica con Priority Fee)
        // Usaremos un constructor genérico o adaptaremos el multi-transfer
        // Por simplicidad, aquí definimos el cuerpo de la TX real:
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        // -- Serialización de la TX Real (Versioned Transaction / Legacy) --
        // (Simplificado para la demo pero siguiendo el protocolo real)
        try tx_mod.writeCompactU16(writer, 1); // 1 Firma
        try buf.appendNTimes(self.allocator, 0, 64); // Reserva para firma
        
        const message_start = buf.items.len;
        try writer.writeByte(1); // num_required_signatures
        try writer.writeByte(0); // num_readonly_signed
        try writer.writeByte(1); // num_readonly_unsigned (el programa)
        
        try tx_mod.writeCompactU16(writer, 2); // 2 Cuentas: Signer, Program
        try buf.appendSlice(self.allocator, &signer_pubkey);
        try buf.appendSlice(self.allocator, &program_id);
        
        try buf.appendSlice(self.allocator, &blockhash); // Blockhash
        
        try tx_mod.writeCompactU16(writer, 1); // 1 Instrucción
        try writer.writeByte(1); // Index del Programa (1)
        try tx_mod.writeCompactU16(writer, 1); // 1 Cuenta en IX
        try writer.writeByte(0); // Signer index (0)
        
        try tx_mod.writeCompactU16(writer, @intCast(ix_data.len));
        try buf.appendSlice(self.allocator, ix_data);

        // 5. Firmar
        const message = buf.items[message_start..];
        const signature = crypto.sign(message, signer_kp);
        @memcpy(buf.items[1..65], &signature);

        // 6. Enviar!
        const sig = try self.sendTransaction(buf.items);
        std.debug.print("\n[SOLANA] ✅ Anchor TX Sent. Sig: {s}", .{sig});
        
        return sig;
    }

    pub fn getLatestBlockhash(self: *SolanaClient) !types.Hash {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[]}}
        , .{});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        const blockhash_str = value.object.get("blockhash") orelse return error.InvalidResponse;

        return try crypto.stringToPubkey(self.allocator, blockhash_str.string);
    }

    pub fn sendTransaction(self: *SolanaClient, tx_bytes: []const u8) ![]u8 {
        const encoded_buf = try self.encodeBase64(tx_bytes);
        defer self.allocator.free(encoded_buf);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"sendTransaction","params":["{s}", {{"encoding":"base64","preflightCommitment":"confirmed"}}]}}
        , .{encoded_buf});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse {
            std.debug.print("\n[SOLANA] ❌ Tx failed: {s}", .{response.body});
            return error.InvalidResponse;
        };
        return try self.allocator.dupe(u8, result.string);
    }

    pub fn simulateTransaction(self: *SolanaClient, tx_bytes: []const u8) !void {
        const encoded_buf = try self.encodeBase64(tx_bytes);
        defer self.allocator.free(encoded_buf);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"simulateTransaction","params":["{s}", {{"encoding":"base64"}}]}}
        , .{encoded_buf});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        
        if (value.object.get("err")) |err| {
            std.debug.print("[Solana] Simulation FAILED: {any}\n", .{err});
            return error.SimulationFailed;
        }

        const logs = value.object.get("logs");
        if (logs) |l| {
            std.debug.print("[Solana] Simulation success. CU consumed: {any}\n", .{value.object.get("unitsConsumed")});
            _ = l;
        }
    }

    fn encodeBase64(self: *SolanaClient, bytes: []const u8) ![]u8 {
        const base64_encoder = std.base64.standard.Encoder;
        const encoded_len = base64_encoder.calcSize(bytes.len);
        const encoded_buf = try self.allocator.alloc(u8, encoded_len);
        _ = base64_encoder.encode(encoded_buf, bytes);
        return encoded_buf;
    }

    pub fn getRecentPrioritizationFees(self: *SolanaClient, addresses: []const []const u8) !u64 {
        var params_buf = std.ArrayListUnmanaged(u8){};
        defer params_buf.deinit(self.allocator);
        const writer = params_buf.writer(self.allocator);

        try writer.writeAll("[");
        for (addresses, 0..) |addr, i| {
            try writer.print("\"{s}\"", .{addr});
            if (i < addresses.len - 1) try writer.writeAll(",");
        }
        try writer.writeAll("]");

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getRecentPrioritizationFees","params":[{s}]}}
        , .{params_buf.items});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const array = result.array;

        if (array.items.len == 0) return 0;

        var max_fee: u64 = 0;
        for (array.items) |item| {
            const fee = item.object.get("prioritizationFee").?.integer;
            if (fee > max_fee) max_fee = @intCast(fee);
        }

        return max_fee;
    }

    /// Implementa la API específica de QuickNode para estimación de Priority Fees.
    /// Esto es mucho más preciso que el método estándar de Solana.
    pub fn getQuickNodePriorityFee(self: *SolanaClient, account: []const u8) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"qn_estimatePriorityFees","params":{{"last_n_blocks":20,"account":"{s}","api_version":2}}}}
        , .{account});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return 0;
        const per_addr = result.object.get("per_account_estimate") orelse return 0;
        const extreme = per_addr.object.get("extreme") orelse return 0;
        
        // Retornamos el fee 'extreme' para asegurar que el Agente siempre gane la subasta de bloques
        return @intCast(extreme.integer);
    }

    pub fn getSignaturesForAddress(self: *SolanaClient, address: []const u8, limit: usize) ![]SignatureInfo {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getSignaturesForAddress","params":["{s}", {{"limit":{d}}}]}}
        , .{ address, limit });
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const array = result.array;

        var signatures = try self.allocator.alloc(SignatureInfo, array.items.len);
        for (array.items, 0..) |item, i| {
            const obj = item.object;
            signatures[i] = .{
                .signature = try self.allocator.dupe(u8, obj.get("signature").?.string),
                .slot = @intCast(obj.get("slot").?.integer),
                .err = obj.get("err") != null,
            };
        }

        return signatures;
    }

    /// Obtiene el saldo comprimido (ZK-Compression) de una dirección.
    /// Requiere un RPC compatible con Light Protocol / Photon.
    pub fn getCompressedBalanceByOwner(self: *SolanaClient, address: []const u8) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getCompressedBalanceByOwner","params":["{s}"]}}
        , .{address});
        defer self.allocator.free(payload);

        var response = self.http_client.post(self.endpoint, payload) catch |err| {
            std.debug.print("[Solana] ⚠️ Error fetching compressed balance: {any}. Falling back to 0.\n", .{err});
            return 0;
        };
        defer response.deinit();

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{}) catch |err| {
             std.debug.print("[Solana] ⚠️ JSON Parse error on compressed balance: {any}\n", .{err});
             return 0;
        };
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return 0;
        const value = result.object.get("value") orelse return 0;

        return @intCast(value.integer);
    }
};

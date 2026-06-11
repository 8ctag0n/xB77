const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const http = @import("../mesh/http.zig");
const tx_mod = @import("../protocol/tx.zig");
const poseidon = @import("../security/poseidon.zig");
const bn254 = @import("../security/bn254.zig");

/// xb77_compression program — verifies a Merkle state transition on-chain via
/// the native Poseidon BN254 syscall (no ZK proof needed on Solana).
const COMPRESSION_PROGRAM_ID = "6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN";

pub const SignatureInfo = struct {
    signature: []const u8,
    slot: u64,
    err: ?std.json.Value,
    memo: ?[]const u8,
    confirmationStatus: ?[]const u8,
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

    pub fn getLatestBlockhash(self: *SolanaClient) ![32]u8 {
        const payload = 
            \\{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[{"commitment":"finalized"}]}
        ;
        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        const blockhash_base58 = value.object.get("blockhash") orelse return error.InvalidResponse;
        
        var blockhash: [32]u8 = undefined;
        _ = try crypto.base58ToBytes(&blockhash, blockhash_base58.string);
        return blockhash;
    }

    pub fn sendTransaction(self: *SolanaClient, tx_bytes: []const u8) ![]u8 {
        const base64_tx = try self.toBase64(tx_bytes);
        defer self.allocator.free(base64_tx);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"sendTransaction","params":["{s}", {{"encoding":"base64"}}]}}
        , .{base64_tx});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.object.get("error")) |err| {
            std.debug.print("\n[SOLANA] Error en RPC: {any}", .{err});
            return error.RpcError;
        }

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        return try self.allocator.dupe(u8, result.string);
    }

    fn toBase64(self: *SolanaClient, bytes: []const u8) ![]u8 {
        const base64_encoder = std.base64.standard.Encoder;
        const encoded_len = base64_encoder.calcSize(bytes.len);
        const encoded_buf = try self.allocator.alloc(u8, encoded_len);
        _ = base64_encoder.encode(encoded_buf, bytes);
        return encoded_buf;
    }

    pub fn getRecentPrioritizationFees(self: *SolanaClient, addresses: []const []const u8) !u64 {
        var params_buf = std.ArrayListUnmanaged(u8).empty;
        defer params_buf.deinit(self.allocator);

        try params_buf.appendSlice(self.allocator, "[");
        for (addresses, 0..) |addr, i| {
            try params_buf.print(self.allocator, "\"{s}\"", .{addr});
            if (i < addresses.len - 1) try params_buf.appendSlice(self.allocator, ",");
        }
        try params_buf.appendSlice(self.allocator, "]");

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getRecentPrioritizationFees","params":[{s}]}}
        , .{params_buf.items});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return 0;
        const arr = result.array;
        var max_fee: u64 = 0;
        for (arr.items) |item| {
            const fee = item.object.get("prioritizationFee") orelse continue;
            if (fee.integer > max_fee) max_fee = @intCast(fee.integer);
        }
        return max_fee;
    }

    pub fn getQuickNodePriorityFee(self: *SolanaClient, account: []const u8) !u64 {
        _ = account;
        return self.getRecentPrioritizationFees(&[_][]const u8{});
    }

    pub fn getSignatureStatuses(self: *SolanaClient, signature: []const u8) !?SignatureInfo {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getSignatureStatuses","params":[["{s}"]]}}
        , .{signature});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return null;
        const value = result.object.get("value") orelse return null;
        const arr = value.array;
        if (arr.items.len == 0 or arr.items[0] == .null) return null;

        const status = arr.items[0].object;
        return SignatureInfo{
            .signature = try self.allocator.dupe(u8, signature),
            .slot = 0, // Mock
            .err = null,
            .memo = null,
            .confirmationStatus = if (status.get("confirmationStatus")) |cs| try self.allocator.dupe(u8, cs.string) else null,
        };
    }

    pub fn getBalance(self: *SolanaClient, address: []const u8) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getBalance","params":["{s}"]}}
        , .{address});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        return @intCast(value.integer);
    }

    pub fn anchorMeshState(
        self: *SolanaClient,
        initial_root: [32]u8,
        final_root: [32]u8,
        batch_indices: [5]u64,
        batch_siblings: [5][14][32]u8,
        amounts: [5]u64,
        entry_types: [5]u8,
        tx_hashes: [5][32]u8,
        total_tax: u64,
        proof: []const u8,
        signer: anytype,
    ) ![]u8 {
        // The xb77_compression program verifies one Merkle transition per ix via
        // the Poseidon syscall — it does not consume a ZK proof, so `proof` and
        // `total_tax` (circuit-only public inputs) are unused on this path.
        _ = proof;
        _ = total_tax;
        _ = initial_root;

        const program_id = try crypto.stringToPubkey(self.allocator, COMPRESSION_PROGRAM_ID);

        var last_sig: ?[]u8 = null;
        errdefer if (last_sig) |s| self.allocator.free(s);

        var i: usize = 0;
        while (i < 5) : (i += 1) {
            // Recompute leaf and climb to this transition's post-root, exactly as
            // the on-chain program will, so we can assert consistency and supply
            // `new_root`. All field elements go on the wire big-endian (the program
            // hashes with Endianness::BigEndian); the CMT stores them little-endian.
            const tx_hash_field = std.mem.readInt(u256, &tx_hashes[i], .little) % bn254.Fr.P;
            const node = computeTransitionRoot(
                amounts[i],
                entry_types[i],
                tx_hash_field,
                batch_indices[i],
                batch_siblings[i],
            );

            // On the last transition the recomputed root must equal final_root.
            if (i == 4) {
                const final_field = std.mem.readInt(u256, &final_root, .little);
                if (node != final_field) return error.BatchRootMismatch;
            }

            const ix_data = try buildVerifyTransitionData(
                self.allocator,
                node,
                batch_indices[i],
                batch_siblings[i],
                amounts[i],
                entry_types[i],
                tx_hash_field,
            );
            defer self.allocator.free(ix_data);

            const blockhash = try self.getLatestBlockhash();
            const tx_bytes = try buildCompressionTx(self.allocator, signer.public, program_id, ix_data, blockhash, 600_000);
            defer self.allocator.free(tx_bytes);

            const signed_tx = try signTx(self.allocator, tx_bytes, signer);
            defer self.allocator.free(signed_tx);

            const sig = try self.sendTransaction(signed_tx);
            if (last_sig) |s| self.allocator.free(s);
            last_sig = sig;
        }

        return last_sig orelse error.NoTransitionsAnchored;
    }

    /// Recompute a transition's post-root: leaf = Poseidon((amount<<8)|type, tx_hash),
    /// then climb the Merkle co-path. Sibling bytes are little-endian field elements
    /// (CMT storage); the returned root is the field element value. Mirrors both
    /// cmt.append and the on-chain xb77_compression climb.
    pub fn computeTransitionRoot(
        amount: u64,
        entry_type: u8,
        tx_hash_field: u256,
        index: u64,
        siblings_le: [14][32]u8,
    ) u256 {
        const amount_combined = (@as(u256, amount) << 8) | @as(u256, entry_type);
        var node = poseidon.Poseidon.hash2(amount_combined, tx_hash_field);
        for (siblings_le, 0..) |sib_le, j| {
            const sib: u256 = @bitCast(sib_le);
            const bit = (index >> @intCast(j)) & 1;
            node = if (bit == 1)
                poseidon.Poseidon.hash2(sib, node)
            else
                poseidon.Poseidon.hash2(node, sib);
        }
        return node;
    }

    /// wincode-encode CompressionInstruction::VerifyTransition. Field elements
    /// (new_root, siblings, tx_hash) are written big-endian to match the program's
    /// Poseidon BigEndian convention; amount/type are sent raw (the program packs).
    fn buildVerifyTransitionData(
        allocator: std.mem.Allocator,
        new_root_field: u256,
        index: u64,
        siblings_le: [14][32]u8,
        amount: u64,
        entry_type: u8,
        tx_hash_field: u256,
    ) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8).empty;
        errdefer buf.deinit(allocator);

        var w8: [8]u8 = undefined;
        var w32: [32]u8 = undefined;

        // disc u32 LE = 0 (VerifyTransition)
        var disc: [4]u8 = undefined;
        std.mem.writeInt(u32, &disc, 0, .little);
        try buf.appendSlice(allocator, &disc);

        // old_root [32] — ignored by verify_transition(), send zeros
        try buf.appendNTimes(allocator, 0, 32);

        // new_root [32] big-endian
        std.mem.writeInt(u256, &w32, new_root_field, .big);
        try buf.appendSlice(allocator, &w32);

        // index u64 LE
        std.mem.writeInt(u64, &w8, index, .little);
        try buf.appendSlice(allocator, &w8);

        // siblings: len u64 LE = 14, then each [32] big-endian
        std.mem.writeInt(u64, &w8, siblings_le.len, .little);
        try buf.appendSlice(allocator, &w8);
        for (siblings_le) |sib_le| {
            const sib: u256 = @bitCast(sib_le);
            std.mem.writeInt(u256, &w32, sib, .big);
            try buf.appendSlice(allocator, &w32);
        }

        // amount u64 LE, type u8 (program packs (amount<<8)|type itself)
        std.mem.writeInt(u64, &w8, amount, .little);
        try buf.appendSlice(allocator, &w8);
        try buf.append(allocator, entry_type);

        // tx_hash [32] big-endian
        std.mem.writeInt(u256, &w32, tx_hash_field, .big);
        try buf.appendSlice(allocator, &w32);

        return buf.toOwnedSlice(allocator);
    }

    /// Build a Solana tx with a ComputeBudget limit ix + one VerifyTransition ix.
    fn buildCompressionTx(
        allocator: std.mem.Allocator,
        signer: types.Pubkey,
        program_id: types.Pubkey,
        instruction_data: []const u8,
        recent_blockhash: [32]u8,
        cu_limit: u32,
    ) ![]u8 {
        const cb_program = try crypto.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

        var buf = std.ArrayListUnmanaged(u8).empty;
        errdefer buf.deinit(allocator);

        // Signatures (1 placeholder, filled by signTx)
        try tx_mod.appendCompactU16(allocator, &buf, 1);
        try buf.appendNTimes(allocator, 0, 64);

        // Message header: 1 signer, 0 readonly signed, 2 readonly unsigned
        try buf.append(allocator, 1);
        try buf.append(allocator, 0);
        try buf.append(allocator, 2);

        // Account keys: signer (writable signer), program (ro), cb_program (ro)
        try tx_mod.appendCompactU16(allocator, &buf, 3);
        try buf.appendSlice(allocator, &signer);
        try buf.appendSlice(allocator, &program_id);
        try buf.appendSlice(allocator, &cb_program);

        // Recent blockhash
        try buf.appendSlice(allocator, &recent_blockhash);

        // Instructions (2)
        try tx_mod.appendCompactU16(allocator, &buf, 2);

        // ix0: ComputeBudget SetComputeUnitLimit
        try buf.append(allocator, 2); // program idx (cb_program)
        try tx_mod.appendCompactU16(allocator, &buf, 0); // accounts
        try tx_mod.appendCompactU16(allocator, &buf, 5); // data len
        try buf.append(allocator, 2); // discriminant (SetComputeUnitLimit)
        var limit_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &limit_buf, cu_limit, .little);
        try buf.appendSlice(allocator, &limit_buf);

        // ix1: compression VerifyTransition (no accounts)
        try buf.append(allocator, 1); // program idx
        try tx_mod.appendCompactU16(allocator, &buf, 0); // accounts
        try tx_mod.appendCompactU16(allocator, &buf, @intCast(instruction_data.len));
        try buf.appendSlice(allocator, instruction_data);

        return buf.toOwnedSlice(allocator);
    }

    pub fn getCompressedBalanceByOwner(self: *SolanaClient, address: []const u8) !u64 {
        _ = address;
        _ = self;
        return 0; // ZK-compressed balance not yet implemented
    }

    pub fn getAccountInfo(self: *SolanaClient, address: []const u8) ![]const u8 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getAccountInfo","params":["{s}", {{"encoding":"base64"}}]}}
        , .{address});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        if (value == .null) return error.AccountNotFound;
        const data_arr = value.object.get("data") orelse return error.InvalidResponse;
        const base64_data = data_arr.array.items[0].string;
        
        const base64_decoder = std.base64.standard.Decoder;
        const decoded_len = try base64_decoder.calcSizeUpperBound(base64_data.len);
        const decoded_buf = try self.allocator.alloc(u8, decoded_len);
        errdefer self.allocator.free(decoded_buf);
        try base64_decoder.decode(decoded_buf, base64_data);
        return decoded_buf;
    }

    pub fn requestAirdrop(self: *SolanaClient, address: []const u8, lamports: u64) !void {
        const req = try std.fmt.allocPrint(self.allocator,
            "{{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"requestAirdrop\",\"params\":[\"{s}\",{d}]}}",
            .{ address, lamports });
        defer self.allocator.free(req);
        var response = try self.http_client.post(self.endpoint, req);
        defer response.deinit();
    }

    pub fn getSignatureStatus(self: *SolanaClient, signature: []const u8) !?[]const u8 {
        const info = try self.getSignatureStatuses(signature) orelse return null;
        return info.confirmationStatus;
    }
};

pub fn signTx(allocator: std.mem.Allocator, tx_buf: []const u8, keypair: *const types.Keypair) ![]u8 {
    var signed = try allocator.dupe(u8, tx_buf);
    const message = signed[65..];
    const signature = crypto.sign(message, keypair);
    @memcpy(signed[1..65], &signature);
    return signed;
}

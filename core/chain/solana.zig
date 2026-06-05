const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const http = @import("../mesh/http.zig");

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
        _ = initial_root; _ = final_root; _ = batch_indices;
        _ = batch_siblings; _ = amounts; _ = entry_types;
        _ = tx_hashes; _ = total_tax; _ = proof; _ = signer;
        return try self.allocator.dupe(u8, "stub_anchor_sig_not_implemented");
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

const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("types.zig");

pub const SignatureInfo = struct {
    signature: []const u8,
    slot: u64,
    err: bool,
};

pub const SolanaClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    http_client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) SolanaClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .http_client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *SolanaClient) void {
        self.http_client.deinit();
    }

    pub fn getBalance(self: *SolanaClient, address: []const u8) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getBalance","params":["{s}"]}}
        , .{address});
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;

        return @intCast(value.integer);
    }

    pub fn getLatestBlockhash(self: *SolanaClient) !types.Hash {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[]}}
        , .{});
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const value = result.object.get("value") orelse return error.InvalidResponse;
        const blockhash_str = value.object.get("blockhash") orelse return error.InvalidResponse;

        return try crypto.stringToPubkey(self.allocator, blockhash_str.string);
    }

    pub fn sendTransaction(self: *SolanaClient, tx_bytes: []const u8) ![]u8 {
        const base64_encoder = std.base64.standard.Encoder;
        const encoded_len = base64_encoder.calcSize(tx_bytes.len);
        const encoded_buf = try self.allocator.alloc(u8, encoded_len);
        defer self.allocator.free(encoded_buf);
        _ = base64_encoder.encode(encoded_buf, tx_bytes);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"sendTransaction","params":["{s}", {{"encoding":"base64"}}]}}
        , .{encoded_buf});
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        return try self.allocator.dupe(u8, result.string);
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

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const array = result.array;

        if (array.items.len == 0) return 0;

        // Calcular el promedio o simplemente el máximo de los últimos slots
        var max_fee: u64 = 0;
        for (array.items) |item| {
            const fee = item.object.get("prioritizationFee").?.integer;
            if (fee > max_fee) max_fee = @intCast(fee);
        }

        return max_fee;
    }

    pub fn getSignaturesForAddress(self: *SolanaClient, address: []const u8, limit: usize) ![]SignatureInfo {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getSignaturesForAddress","params":["{s}", {{"limit":{d}}}]}}
        , .{ address, limit });
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{ .ignore_unknown_fields = true });
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

    fn rpcRequest(self: *SolanaClient, payload: []const u8) ![]u8 {
        const uri = try std.Uri.parse(self.endpoint);
        
        var req = try self.http_client.request(.POST, uri, .{});
        defer req.deinit();

        req.accept_encoding = [_]bool{false} ** @typeInfo(std.http.ContentEncoding).@"enum".fields.len;
        req.accept_encoding[@intFromEnum(std.http.ContentEncoding.identity)] = true;
        req.headers.accept_encoding = .{ .override = "identity" };
        req.transfer_encoding = .{ .content_length = payload.len };
        req.headers.content_type = .{ .override = "application/json" };
        
        try req.sendBodyComplete(@constCast(payload));
        var redirect_buffer: [1024]u8 = undefined;
        var res = try req.receiveHead(&redirect_buffer);

        if (res.head.status != .ok) {
            return error.RpcError;
        }

        var transfer_buffer: [4096]u8 = undefined;
        const body_reader = res.reader(&transfer_buffer);
        const body = try body_reader.allocRemaining(self.allocator, .unlimited);
        return body;
    }
};

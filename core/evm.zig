const std = @import("std");
const types = @import("types.zig");
const http = @import("http.zig");

pub const EvmClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    http_client: http.HttpClient,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) EvmClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .http_client = http.HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *EvmClient) void {
        _ = self;
    }

    pub fn getNonce(self: *EvmClient, address: types.EthAddress) !u64 {
        const addr_hex = try addressToHex(self.allocator, address);
        defer self.allocator.free(addr_hex);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionCount","params":["{s}", "latest"]}}
        , .{addr_hex});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try std.fmt.parseInt(u64, clean_hex, 16);
    }

    pub fn getBalance(self: *EvmClient, address: types.EthAddress) !u256 {
        const addr_hex = try addressToHex(self.allocator, address);
        defer self.allocator.free(addr_hex);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["{s}", "latest"]}}
        , .{addr_hex});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try std.fmt.parseInt(u256, clean_hex, 16);
    }

    pub fn getGasPrice(self: *EvmClient) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_gasPrice","params":[]}}
        , .{});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try std.fmt.parseInt(u64, clean_hex, 16);
    }

    pub fn sendRawTransaction(self: *EvmClient, tx_hex: []const u8) !types.Hash {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_sendRawTransaction","params":["{s}"]}}
        , .{tx_hex});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("error")) |err| {
            std.debug.print("RPC Error: {s}\n", .{err.object.get("message").?.string});
            return error.RpcError;
        }

        const result = parsed.value.object.get("result") orelse return error.RpcError;
        const result_str = result.string;
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        
        var hash: types.Hash = undefined;
        _ = try std.fmt.hexToBytes(&hash, clean_hex);
        return hash;
    }
};

pub fn addressToHex(allocator: std.mem.Allocator, addr: types.EthAddress) ![]u8 {
    const crypto = @import("crypto.zig");
    const hex_encoded = try crypto.bytesToHex(allocator, &addr);
    defer allocator.free(hex_encoded);
    return try std.fmt.allocPrint(allocator, "0x{s}", .{hex_encoded});
}

pub fn hexToAddress(hex: []const u8) !types.EthAddress {
    const clean_hex = if (std.mem.startsWith(u8, hex, "0x")) hex[2..] else hex;
    var addr: types.EthAddress = undefined;
    _ = try std.fmt.hexToBytes(&addr, clean_hex);
    return addr;
}

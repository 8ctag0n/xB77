const std = @import("std");
const types = @import("types.zig");

pub const Keccak256 = std.crypto.hash.sha3.Keccak256;

/// Genera una dirección de Ethereum a partir de una llave pública SECP256K1 (64 bytes).
pub fn addressFromPubkey(pubkey: [64]u8) types.EthAddress {
    var hash: [32]u8 = undefined;
    Keccak256.hash(&pubkey, &hash, .{});
    
    var addr: types.EthAddress = undefined;
    @memcpy(&addr, hash[12..32]);
    return addr;
}

/// Helper para imprimir direcciones EVM en Hex.
pub fn addressToHex(allocator: std.mem.Allocator, addr: types.EthAddress) ![]u8 {
    const hex_encoded = std.fmt.bytesToHex(addr, .lower);
    return try std.fmt.allocPrint(allocator, "0x{s}", .{hex_encoded});
}

/// Parsear dirección Hex a bytes.
pub fn hexToAddress(hex: []const u8) !types.EthAddress {
    const clean_hex = if (std.mem.startsWith(u8, hex, "0x")) hex[2..] else hex;
    if (clean_hex.len != 40) return error.InvalidAddressLength;
    
    var addr: types.EthAddress = undefined;
    _ = try std.fmt.hexToBytes(&addr, clean_hex);
    return addr;
}

pub const EvmClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    http_client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) EvmClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .http_client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *EvmClient) void {
        self.http_client.deinit();
    }

    pub fn getNonce(self: *EvmClient, address: types.EthAddress) !u64 {
        const addr_hex = try addressToHex(self.allocator, address);
        defer self.allocator.free(addr_hex);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionCount","params":["{s}", "latest"]}}
        , .{addr_hex});
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        
        // El resultado es un hex string
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try std.fmt.parseInt(u64, clean_hex, 16);
    }

    pub fn getGasPrice(self: *EvmClient) !u64 {
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_gasPrice","params":[]}}
        , .{});
        defer self.allocator.free(payload);

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
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

        const response = try self.rpcRequest(payload);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse {
            if (parsed.value.object.get("error")) |err| {
                std.debug.print("RPC Error: {s}\n", .{err});
            }
            return error.RpcError;
        };
        
        const result_str = result.string;
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        
        var hash: types.Hash = undefined;
        _ = try std.fmt.hexToBytes(&hash, clean_hex);
        return hash;
    }

    fn rpcRequest(self: *EvmClient, payload: []const u8) ![]u8 {
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
        const res = try req.receiveHead(&redirect_buffer);

        if (res.head.status != .ok) {
            return error.RpcError;
        }

        const body = try req.reader().allocAll(self.allocator, 10 * 1024 * 1024); // 10MB limit
        return body;
    }
};

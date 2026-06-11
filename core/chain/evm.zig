const std = @import("std");
const types = @import("../protocol/types.zig");
const http = @import("../mesh/http.zig");

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

    pub fn getChainId(self: *EvmClient) !u64 {
        const payload =
            \\{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}
        ;
        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();
        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const s = result.string;
        const clean = if (std.mem.startsWith(u8, s, "0x")) s[2..] else s;
        return try std.fmt.parseInt(u64, clean, 16);
    }

    // Sign and broadcast a transaction via eth_sendRawTransaction (EIP-155).
    // Works on any network including Sepolia — does not require an unlocked node account.
    // `to_str`: "0x…" or bare hex address. `data_hex`: calldata without 0x prefix.
    // `sk`: 32-byte secp256k1 private key. `from`: 20-byte address (for nonce lookup).
    // Returns the tx hash as an owned hex string ("0x…").
    pub fn sendSignedTx(
        self: *EvmClient,
        to_str: []const u8,
        data_hex: []const u8,
        sk: [32]u8,
        from: types.EthAddress,
    ) ![]u8 {
        const crypto = @import("../security/crypto.zig");
        const Keccak256 = std.crypto.hash.sha3.Keccak256;

        const nonce     = try self.getNonce(from);
        const gas_price = try self.getGasPrice();
        const chain_id  = try self.getChainId();
        const gas_limit: u64 = 500_000;

        const to_clean = if (std.mem.startsWith(u8, to_str, "0x")) to_str[2..] else to_str;
        var to_addr: [20]u8 = undefined;
        _ = try std.fmt.hexToBytes(&to_addr, to_clean);

        const data = try self.allocator.alloc(u8, data_hex.len / 2);
        defer self.allocator.free(data);
        _ = try std.fmt.hexToBytes(data, data_hex);

        // ── signing payload: RLP([nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0])
        const a = self.allocator;
        var items = std.ArrayList(u8).empty;
        defer items.deinit(a);
        try rlpUint(a, &items, nonce);
        try rlpUint(a, &items, gas_price);
        try rlpUint(a, &items, gas_limit);
        try rlpBytes(a, &items, &to_addr);
        try items.append(a, 0x80);     // value = 0
        try rlpBytes(a, &items, data);
        try rlpUint(a, &items, chain_id);
        try items.append(a, 0x80);     // r = 0
        try items.append(a, 0x80);     // s = 0

        const signing_rlp = try rlpList(a, items.items);
        defer a.free(signing_rlp);

        var hash: [32]u8 = undefined;
        Keccak256.hash(signing_rlp, &hash, .{});

        const sig = try crypto.signEthMessage(hash, sk);
        const v: u64 = chain_id * 2 + 35 + @as(u64, sig.v);

        // ── final tx: RLP([nonce, gasPrice, gasLimit, to, value, data, v, r, s])
        items.clearRetainingCapacity();
        try rlpUint(a, &items, nonce);
        try rlpUint(a, &items, gas_price);
        try rlpUint(a, &items, gas_limit);
        try rlpBytes(a, &items, &to_addr);
        try items.append(a, 0x80);
        try rlpBytes(a, &items, data);
        try rlpUint(a, &items, v);
        try rlpBigInt(a, &items, &sig.r);
        try rlpBigInt(a, &items, &sig.s);

        const raw_tx = try rlpList(a, items.items);
        defer a.free(raw_tx);

        const raw_hex = try crypto.bytesToHex(a, raw_tx);
        defer a.free(raw_hex);
        const tx_hex = try std.fmt.allocPrint(a, "0x{s}", .{raw_hex});
        defer a.free(tx_hex);

        const hash_bytes = try self.sendRawTransaction(tx_hex);
        const hash_hex = try crypto.bytesToHex(a, &hash_bytes);
        defer a.free(hash_hex);
        return try std.fmt.allocPrint(a, "0x{s}", .{hash_hex});
    }

    // Send a tx via eth_sendTransaction (no signing — use for local/dev nodes).
    // `to_str`: hex address string like "0x1234..." or "1234..."
    // `data_hex`: hex-encoded calldata (no 0x prefix)
    // Returns the tx hash as an owned slice.
    pub fn sendTx(self: *EvmClient, to_str: []const u8, data_hex: []const u8) ![]u8 {
        const to_addr = if (std.mem.startsWith(u8, to_str, "0x")) to_str else
            try std.fmt.allocPrint(self.allocator, "0x{s}", .{to_str});
        defer if (!std.mem.startsWith(u8, to_str, "0x")) self.allocator.free(to_addr);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_sendTransaction","params":[{{"to":"{s}","data":"0x{s}"}}]}}
        , .{ to_addr, data_hex });
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("error")) |err_val| {
            std.debug.print("[EVM] sendTx error: {s}\n", .{err_val.object.get("message").?.string});
            return error.RpcError;
        }

        const result = parsed.value.object.get("result") orelse return error.RpcError;
        return try self.allocator.dupe(u8, result.string);
    }

    // callView but with a string address (for Stylus contract addresses stored as []const u8)
    pub fn callViewStr(self: *EvmClient, to_str: []const u8, data_hex: []const u8) ![]u8 {
        const to_addr = if (std.mem.startsWith(u8, to_str, "0x")) to_str else
            try std.fmt.allocPrint(self.allocator, "0x{s}", .{to_str});
        defer if (!std.mem.startsWith(u8, to_str, "0x")) self.allocator.free(to_addr);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{{"to":"{s}","data":"0x{s}"}},"latest"]}}
        , .{ to_addr, data_hex });
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        const clean = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try self.allocator.dupe(u8, clean);
    }

    pub fn callView(self: *EvmClient, to: types.EthAddress, data_hex: []const u8) ![]u8 {
        const to_hex = try addressToHex(self.allocator, to);
        defer self.allocator.free(to_hex);

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[ {{"to":"{s}", "data":"0x{s}"}}, "latest"]}}
        , .{to_hex, data_hex});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.endpoint, payload);
        defer response.deinit();

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const result_str = result.string;
        
        const clean_hex = if (std.mem.startsWith(u8, result_str, "0x")) result_str[2..] else result_str;
        return try self.allocator.dupe(u8, clean_hex);
    }
};

pub fn addressToHex(allocator: std.mem.Allocator, addr: types.EthAddress) ![]u8 {
    const crypto = @import("../security/crypto.zig");
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

// ── Minimal RLP encoder (EIP-155 legacy tx) ──────────────────────────────────

fn rlpUint(a: std.mem.Allocator, buf: *std.ArrayList(u8), value: u64) !void {
    if (value == 0) { try buf.append(a, 0x80); return; }
    var be: [8]u8 = undefined;
    std.mem.writeInt(u64, &be, value, .big);
    var i: usize = 0;
    while (i < 8 and be[i] == 0) i += 1;
    try rlpBytes(a, buf, be[i..]);
}

fn rlpBigInt(a: std.mem.Allocator, buf: *std.ArrayList(u8), be32: *const [32]u8) !void {
    var i: usize = 0;
    while (i < 32 and be32[i] == 0) i += 1;
    try rlpBytes(a, buf, be32[i..]);
}

fn rlpBytes(a: std.mem.Allocator, buf: *std.ArrayList(u8), data: []const u8) !void {
    if (data.len == 0) { try buf.append(a, 0x80); return; }
    if (data.len == 1 and data[0] < 0x80) { try buf.append(a, data[0]); return; }
    if (data.len <= 55) {
        try buf.append(a, @intCast(0x80 + data.len));
        try buf.appendSlice(a, data);
        return;
    }
    var lb: [8]u8 = undefined;
    std.mem.writeInt(u64, &lb, @as(u64, data.len), .big);
    var i: usize = 0;
    while (i < 8 and lb[i] == 0) i += 1;
    try buf.append(a, @intCast(0xb7 + (8 - i)));
    try buf.appendSlice(a, lb[i..]);
    try buf.appendSlice(a, data);
}

fn rlpList(a: std.mem.Allocator, items: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(a);
    if (items.len <= 55) {
        try out.append(a, @intCast(0xc0 + items.len));
    } else {
        var lb: [8]u8 = undefined;
        std.mem.writeInt(u64, &lb, @as(u64, items.len), .big);
        var i: usize = 0;
        while (i < 8 and lb[i] == 0) i += 1;
        try out.append(a, @intCast(0xf7 + (8 - i)));
        try out.appendSlice(a, lb[i..]);
    }
    try out.appendSlice(a, items);
    return out.toOwnedSlice(a);
}

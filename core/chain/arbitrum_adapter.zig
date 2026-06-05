const std = @import("std");
const core = @import("../core.zig");
const types = @import("../protocol/types.zig");
const evm = @import("evm.zig");
const semantic = @import("../security/semantic.zig");

const SEL_VALIDATE_SEMANTIC = [_]u8{ 0x12, 0x34, 0x56, 0x78 }; // Placeholder
const SEL_BRIDGE_VERIFY     = [_]u8{ 0x3a, 0x4b, 0x5c, 0x6d };
const SEL_GET_AGENT_GDP     = [_]u8{ 0xf1, 0xe2, 0xd3, 0xc4 };

pub const PreFlightResult = struct {
    approved: bool,
    similarity: i32,
};

pub fn neutralIntent() semantic.Semantic.FixedVector {
    return [_]i32{0} ** semantic.Semantic.DIMENSIONS;
}

pub fn intentFromTransfer(recipient: []const u8, amount: u64) semantic.Semantic.FixedVector {
    _ = recipient;
    if (amount > 500_000_000) {
        return [_]i32{semantic.Semantic.SCALE} ** semantic.Semantic.DIMENSIONS;
    }
    var v = [_]i32{0} ** semantic.Semantic.DIMENSIONS;
    for (0..semantic.Semantic.DIMENSIONS) |i| {
        v[i] = if (i % 2 == 0) @as(i32, @intCast(amount % 100)) else 0;
    }
    return v;
}

pub const ArbitrumAdapter = struct {
    allocator: std.mem.Allocator,
    constitution_address: []const u8,
    evm_client: evm.EvmClient,

    pub fn init(allocator: std.mem.Allocator, constitution_addr: []const u8, rpc_url: []const u8) ArbitrumAdapter {
        return .{
            .allocator = allocator,
            .constitution_address = constitution_addr,
            .evm_client = evm.EvmClient.init(allocator, rpc_url),
        };
    }

    pub const Provider = struct {
        addr: []const u8,
        pub fn getAddress(self: @This()) []const u8 { return self.addr; }
    };

    pub fn provider(self: *ArbitrumAdapter) Provider {
        return .{ .addr = self.constitution_address };
    }

        pub fn deinit(self: *ArbitrumAdapter) void {
        _ = self;
    }

    fn toHex(buf: []u8, bytes: []const u8) []const u8 {
        const charset = "0123456789abcdef";
        for (bytes, 0..) |b, i| {
            buf[i * 2] = charset[b >> 4];
            buf[i * 2 + 1] = charset[b & 15];
        }
        return buf[0 .. bytes.len * 2];
    }

    // ── Stylus constitution calls ───────────────────────────────────────────

    pub fn check_constitution(self: *ArbitrumAdapter, intent: semantic.Semantic.FixedVector) !PreFlightResult {
        var payload = std.ArrayList(u8).empty;
        defer payload.deinit(self.allocator);

        try payload.appendSlice(self.allocator, &SEL_VALIDATE_SEMANTIC);
        for (intent) |val| {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(i32, &buf, val, .big);
            try payload.appendSlice(self.allocator, &buf);
        }

        var hex_tmp: [1024]u8 = undefined;
        const hex_str = toHex(&hex_tmp, payload.items);

        const result_hex = try self.evm_client.callView(self.constitution_address, hex_str);
        defer self.allocator.free(result_hex);

        const approved = result_hex.len >= 64 and
            (try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16)) == 1;

        return PreFlightResult{
            .approved = approved,
            .similarity = 0, // Mocked for now
        };
    }

    pub fn verify_cross_chain_state(
        self: *ArbitrumAdapter,
        chain_id: u8,
        agent_id: [32]u8,
        proof: [32]u8,
    ) !bool {
        var payload = std.ArrayList(u8).empty;
        defer payload.deinit(self.allocator);

        try payload.appendSlice(self.allocator, &SEL_BRIDGE_VERIFY);
        var chain_padded = [_]u8{0} ** 32;
        chain_padded[31] = chain_id;
        try payload.appendSlice(self.allocator, &chain_padded);
        try payload.appendSlice(self.allocator, &agent_id);
        try payload.appendSlice(self.allocator, &proof);

        var hex_tmp: [1024]u8 = undefined;
        const hex_str = toHex(&hex_tmp, payload.items);

        const result_hex = try self.evm_client.callView(self.constitution_address, hex_str);
        defer self.allocator.free(result_hex);

        return result_hex.len >= 64 and
            (try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16)) == 1;
    }

    pub fn get_agent_gdp(self: *ArbitrumAdapter, settlement: []const u8, agent: [20]u8) !u256 {
        var payload = std.ArrayList(u8).empty;
        defer payload.deinit(self.allocator);

        try payload.appendSlice(self.allocator, &SEL_GET_AGENT_GDP);
        var padded = [_]u8{0} ** 32;
        @memcpy(padded[12..32], &agent);
        try payload.appendSlice(self.allocator, &padded);

        var hex_tmp: [1024]u8 = undefined;
        const hex_str = toHex(&hex_tmp, payload.items);

        const result_hex = try self.evm_client.callView(settlement, hex_str);
        defer self.allocator.free(result_hex);

        if (result_hex.len < 64) return 0;
        return try std.fmt.parseInt(u256, result_hex[0..64], 16);
    }
};

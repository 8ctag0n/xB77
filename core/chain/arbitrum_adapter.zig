const std = @import("std");
const core = @import("../core.zig");
const types = @import("../protocol/types.zig");
const evm = @import("evm.zig");
const semantic = @import("../security/semantic.zig");

const SEL_VALIDATE_SEMANTIC = [_]u8{ 0x12, 0x34, 0x56, 0x78 }; // Placeholder
const SEL_BRIDGE_VERIFY     = [_]u8{ 0x3a, 0x4b, 0x5c, 0x6d };
const SEL_GET_AGENT_GDP     = [_]u8{ 0xf1, 0xe2, 0xd3, 0xc4 };

// ── Stylus contract selectors (comptime keccak256) ────────────────────────────
fn keccak4(comptime sig: []const u8) [4]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(sig, &hash, .{});
    return hash[0..4].*;
}

const SEL_ANCHOR_ROOT  = keccak4("anchorRoot(bytes32)");
const SEL_GET_ROOT     = keccak4("getRoot()");
const SEL_SETTLE       = keccak4("settle(address,uint256,bytes32)");
const SEL_VERIFY_PROOF = keccak4("verifyProof(bytes,bytes32[])");

// Stylus contract addresses — populated after deploy via onchain/stylus/deploy.sh.
// The CLI reads these from env vars XB77_ANCHOR_ADDR, XB77_SETTLEMENT_ADDR, etc.
pub var STYLUS_ANCHOR_ADDR:      []const u8 = "0x0000000000000000000000000000000000000000";
pub var STYLUS_SETTLEMENT_ADDR:  []const u8 = "0x0000000000000000000000000000000000000000";
pub var STYLUS_ZK_VERIFIER_ADDR: []const u8 = "0x0000000000000000000000000000000000000000";

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

    // ── Stylus contract integration ───────────────────────────────────────────

    /// Anchor a compression state root on the xb77_anchor Stylus contract.
    /// Equivalent to calling anchorRoot(bytes32) on-chain.
    pub fn anchorStateRoot(self: *ArbitrumAdapter, new_root: [32]u8) ![]u8 {
        var payload: [4 + 32]u8 = undefined;
        @memcpy(payload[0..4], &SEL_ANCHOR_ROOT);
        @memcpy(payload[4..36], &new_root);

        var hex_tmp: [80]u8 = undefined;
        const hex_str = toHex(&hex_tmp, &payload);

        return self.evm_client.sendTx(STYLUS_ANCHOR_ADDR, hex_str);
    }

    /// Read the current compression state root from the anchor contract.
    pub fn getStateRoot(self: *ArbitrumAdapter) ![32]u8 {
        var payload: [4]u8 = SEL_GET_ROOT;
        var hex_tmp: [10]u8 = undefined;
        const hex_str = toHex(&hex_tmp, &payload);

        const result_hex = try self.evm_client.callViewStr(STYLUS_ANCHOR_ADDR, hex_str);
        defer self.allocator.free(result_hex);

        if (result_hex.len < 64) return error.InvalidResponse;
        var root: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&root, result_hex[0..64]);
        return root;
    }

    /// Settle an agent payment via the SettlementEngine Stylus contract.
    pub fn settlePayment(
        self: *ArbitrumAdapter,
        agent: [20]u8,
        amount: u64,
        commitment: [32]u8,
    ) ![]u8 {
        // ABI encode: settle(address agent, uint256 amount, bytes32 commitment)
        var payload: [4 + 32 + 32 + 32]u8 = undefined;
        @memcpy(payload[0..4], &SEL_SETTLE);
        // address: zero-pad to 32 bytes
        @memset(payload[4..16], 0);
        @memcpy(payload[16..36], &agent);
        // uint256 amount: zero-pad u64 to 32 bytes
        @memset(payload[36..60], 0);
        std.mem.writeInt(u64, payload[60..68][0..8], amount, .big);
        // bytes32 commitment
        @memcpy(payload[68..100], &commitment);

        var hex_tmp: [200 + 10]u8 = undefined;
        const hex_str = toHex(&hex_tmp, &payload);

        return self.evm_client.sendTx(STYLUS_SETTLEMENT_ADDR, hex_str);
    }

    /// Verify a Noir ZK proof on-chain via the ZKVerifier Stylus contract.
    /// Returns true if the proof is valid for the given public root.
    pub fn verifyZKProof(
        self: *ArbitrumAdapter,
        proof: []const u8,
        public_root: [32]u8,
    ) !bool {
        // ABI encode: verifyProof(bytes proof, bytes32[] publicInputs)
        // head: [proof_offset(32), array_offset(32)]
        // tail: [proof_len(32), proof_data(padded), array_len(32), root(32)]
        const proof_padded = ((proof.len + 31) / 32) * 32;
        const total = 4 + 32 + 32 + 32 + proof_padded + 32 + 32;
        const payload = try self.allocator.alloc(u8, total);
        defer self.allocator.free(payload);

        @memcpy(payload[0..4], &SEL_VERIFY_PROOF);
        // proof offset = 64 (two head words)
        @memset(payload[4..36], 0); payload[35] = 0x40;
        // publicInputs offset = 64 + 32 + proof_padded
        const arr_offset: u64 = 64 + 32 + proof_padded;
        @memset(payload[36..68], 0);
        std.mem.writeInt(u64, payload[60..68][0..8], arr_offset, .big);
        // proof length
        @memset(payload[68..100], 0);
        std.mem.writeInt(u64, payload[92..100][0..8], @intCast(proof.len), .big);
        // proof data
        @memcpy(payload[100..][0..proof.len], proof);
        if (proof_padded > proof.len) @memset(payload[100 + proof.len ..][0 .. proof_padded - proof.len], 0);
        // array length = 1
        const arr_start = 100 + proof_padded;
        @memset(payload[arr_start..][0..32], 0);
        payload[arr_start + 31] = 1;
        // array[0] = public_root
        @memcpy(payload[arr_start + 32 ..][0..32], &public_root);

        const hex_payload = try self.allocator.alloc(u8, total * 2 + 2);
        defer self.allocator.free(hex_payload);
        const hex_str = toHex(hex_payload, payload);

        const result_hex = try self.evm_client.callViewStr(STYLUS_ZK_VERIFIER_ADDR, hex_str);
        defer self.allocator.free(result_hex);

        if (result_hex.len < 64) return false;
        const last_byte = try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16);
        return last_byte == 1;
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

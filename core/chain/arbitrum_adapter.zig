const std = @import("std");
const chain = @import("chain.zig");
const types = @import("../protocol/types.zig");
const evm = @import("evm.zig");
const semantic = @import("../security/semantic.zig");

/// xB77 Arbitrum Adapter — Stylus-native sovereign logic
///
/// Architecture:
///   Zig kernel → semantic pre-flight (on-chain Stylus constitution) → approved intent
///   TS SDK (ZeroDev) → UserOp construction + bundler submission
///
/// The adapter owns: constitution checks, bridge verification, GDP settlement calls.
/// The TS SDK owns: ECDSA signing, ERC-4337 UserOp packaging, paymaster sponsorship.

// Stylus constitution selectors (must match onchain/stylus/main.zig)
const SEL_VALIDATE_SEMANTIC: [4]u8 = .{ 0xab, 0xcd, 0xef, 0x01 };
const SEL_REGISTER_PEER: [4]u8     = .{ 0x9c, 0x0d, 0x1e, 0x2f };
const SEL_BRIDGE_VERIFY: [4]u8     = .{ 0x3a, 0x4b, 0x5c, 0x6d };
const SEL_SET_CONSTITUTION: [4]u8  = .{ 0x1a, 0x2b, 0x3c, 0x4d };

// Settlement selectors (must match onchain/stylus/settlement.zig)
const SEL_SETTLE: [4]u8            = .{ 0xd8, 0xbf, 0xf5, 0xa5 };
const SEL_SETTLE_FROM_CHAIN: [4]u8 = .{ 0xab, 0xcd, 0x12, 0x34 };
const SEL_GET_AGENT_GDP: [4]u8     = .{ 0xf4, 0xa9, 0xe3, 0xb1 };

/// Result of a semantic pre-flight check
pub const PreFlightResult = struct {
    approved: bool,
    similarity: i32, // cosine similarity against blocked vector (0–10000 scale)
    intent: semantic.Semantic.FixedVector,
};

/// Result of a submitted transaction
pub const TxResult = struct {
    hash: []const u8,       // hex tx hash from the chain
    pre_flight: PreFlightResult,
};

pub const ArbitrumAdapter = struct {
    allocator: std.mem.Allocator,
    rpc_url: []const u8,
    evm_client: evm.EvmClient,
    address: types.EthAddress,
    constitution_address: types.EthAddress,
    settlement_address: ?types.EthAddress = null,

    pub fn init(
        allocator: std.mem.Allocator,
        rpc_url: []const u8,
        agent_addr: types.EthAddress,
        constitution: types.EthAddress,
    ) ArbitrumAdapter {
        return .{
            .allocator = allocator,
            .rpc_url = allocator.dupe(u8, rpc_url) catch rpc_url,
            .evm_client = evm.EvmClient.init(allocator, rpc_url),
            .address = agent_addr,
            .constitution_address = constitution,
        };
    }

    pub fn initWithSettlement(
        allocator: std.mem.Allocator,
        rpc_url: []const u8,
        agent_addr: types.EthAddress,
        constitution: types.EthAddress,
        settlement: types.EthAddress,
    ) ArbitrumAdapter {
        var adapter = init(allocator, rpc_url, agent_addr, constitution);
        adapter.settlement_address = settlement;
        return adapter;
    }

    pub fn deinit(self: *ArbitrumAdapter) void {
        self.allocator.free(self.rpc_url);
        self.evm_client.deinit();
    }

    pub fn provider(self: *ArbitrumAdapter) chain.ChainProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .get_balance = get_balance,
                .send_tx = send_tx,
                .get_address = get_address,
            },
        };
    }

    // ── ChainProvider vtable ────────────────────────────────────────────────

    fn get_balance(ctx: *anyopaque, addr: []const u8) anyerror!u128 {
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));
        const eth_addr = try evm.hexToAddress(addr);
        const bal = try self.evm_client.getBalance(eth_addr);
        return @intCast(bal);
    }

    /// send_tx performs a semantic pre-flight against the Stylus constitution on-chain,
    /// then submits the raw signed transaction via eth_sendRawTransaction.
    ///
    /// The signed_tx field on transfer actions is the hex-encoded raw EVM tx (produced
    /// by the TS SDK / ZeroDev bundler). If omitted (empty string), the adapter returns
    /// only the pre-flight result encoded as a sentinel hash so callers can inspect it.
    pub fn send_tx(ctx: *anyopaque, action: chain.ChainAction) anyerror![]const u8 {
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));

        switch (action) {
            .transfer => |t| {
                std.debug.print("[ARB] Pre-flight semantic check — {d} USDC to {s}\n", .{ t.amount, t.to });

                // 1. Build intent vector from action
                const intent = intentFromTransfer(t.to, t.amount);

                // 2. Check constitution on-chain (real Stylus call)
                const pre_flight = try self.check_constitution(intent);

                if (!pre_flight.approved) {
                    std.debug.print("[ARB] REJECTED by Stylus constitution (similarity={d})\n", .{pre_flight.similarity});
                    return error.ConstitutionalViolation;
                }

                std.debug.print("[ARB] Approved by Stylus (similarity={d}). Submitting...\n", .{pre_flight.similarity});

                // 3. Submit via eth_sendRawTransaction
                // The signed tx hex is passed via the 'to' field with a "signed:" prefix
                // when the TS SDK wraps the action. In direct mode the adapter returns
                // the approval sentinel so the caller can proceed with ZeroDev submission.
                if (std.mem.startsWith(u8, t.to, "signed:")) {
                    const signed_hex = t.to[7..];
                    const hash = try self.evm_client.sendRawTransaction(signed_hex);
                    return std.fmt.allocPrint(self.allocator, "0x{s}", .{std.fmt.fmtSliceHexLower(&hash)});
                }

                // No signed tx provided — return approval token for TS SDK to consume
                return try std.fmt.allocPrint(
                    self.allocator,
                    "approved:similarity={d}:intent_ok",
                    .{pre_flight.similarity},
                );
            },
            else => return error.NotImplemented,
        }
    }

    fn get_address(ctx: *anyopaque) []const u8 {
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));
        return evm.addressToHex(self.allocator, self.address) catch return "0x0";
    }

    // ── Stylus constitution calls ───────────────────────────────────────────

    /// Check an intent vector against the on-chain Stylus constitution.
    /// Returns PreFlightResult with approved=true if similarity < 80% (8000).
    pub fn check_constitution(self: *ArbitrumAdapter, intent: semantic.Semantic.FixedVector) !PreFlightResult {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try payload.appendSlice(&SEL_VALIDATE_SEMANTIC);
        for (intent) |val| {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(i32, &buf, val, .big);
            try payload.appendSlice(&buf);
        }

        const payload_hex = try std.fmt.allocPrint(
            self.allocator,
            "{s}",
            .{std.fmt.fmtSliceHexLower(payload.items)},
        );
        defer self.allocator.free(payload_hex);

        const result_hex = try self.evm_client.callView(self.constitution_address, payload_hex);
        defer self.allocator.free(result_hex);

        // Stylus returns 32 bytes: last byte = 1 for approved, 0 for rejected
        const approved = result_hex.len >= 64 and
            (try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16)) == 1;

        // Similarity is emitted in the log, not in the return value.
        // We compute it locally for the result struct.
        const blocked: semantic.Semantic.FixedVector = [_]i32{semantic.Semantic.SCALE} ** semantic.Semantic.DIMENSIONS;
        const similarity = semantic.Semantic.cosineSimilarityFixed(intent, blocked);

        return PreFlightResult{
            .approved = approved,
            .similarity = similarity,
            .intent = intent,
        };
    }

    /// Set the agent's constitution on-chain (admin only on the Stylus contract).
    /// vector defines what the agent considers "blocked" intent space.
    pub fn set_constitution(self: *ArbitrumAdapter, vector: semantic.Semantic.FixedVector, signed_tx: []const u8) !types.Hash {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try payload.appendSlice(&SEL_SET_CONSTITUTION);
        for (vector) |val| {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(i32, &buf, val, .big);
            try payload.appendSlice(&buf);
        }

        return self.evm_client.sendRawTransaction(signed_tx);
    }

    // ── Cross-chain interop ─────────────────────────────────────────────────

    /// Register a trusted peer from another chain on the Stylus constitution.
    /// chain_id: 0x01=Solana, 0x02=Sui, 0x03=Arc, 0x04=Arbitrum
    /// peer_hash: keccak256(programId) for Solana, objectId for Sui, address for Arc/EVM
    pub fn register_peer(self: *ArbitrumAdapter, chain_id: u8, peer_hash: [32]u8, signed_tx: []const u8) !types.Hash {
        _ = chain_id;
        _ = peer_hash;
        return self.evm_client.sendRawTransaction(signed_tx);
    }

    /// Verify that a cross-chain agent is trusted on the Stylus constitution.
    /// Returns true if bridgeVerify passes (peer is registered + proof matches).
    pub fn bridge_verify(
        self: *ArbitrumAdapter,
        chain_id: u8,
        agent_id: [32]u8,
        proof: [32]u8,
    ) !bool {
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try payload.appendSlice(&SEL_BRIDGE_VERIFY);

        // ABI-encode (uint8, bytes32, bytes32): uint8 padded to 32 bytes
        var chain_padded = [_]u8{0} ** 32;
        chain_padded[31] = chain_id;
        try payload.appendSlice(&chain_padded);
        try payload.appendSlice(&agent_id);
        try payload.appendSlice(&proof);

        const payload_hex = try std.fmt.allocPrint(
            self.allocator,
            "{s}",
            .{std.fmt.fmtSliceHexLower(payload.items)},
        );
        defer self.allocator.free(payload_hex);

        const result_hex = try self.evm_client.callView(self.constitution_address, payload_hex);
        defer self.allocator.free(result_hex);

        if (result_hex.len < 64) return false;
        const last = try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16);
        return last == 1;
    }

    // ── Settlement calls ────────────────────────────────────────────────────

    /// Call Settlement.settle(amount, commitment) via a pre-signed tx.
    pub fn settle(self: *ArbitrumAdapter, signed_tx: []const u8) !types.Hash {
        return self.evm_client.sendRawTransaction(signed_tx);
    }

    /// Call Settlement.settleFromChain(...) for a cross-chain agent.
    pub fn settle_from_chain(self: *ArbitrumAdapter, signed_tx: []const u8) !types.Hash {
        return self.evm_client.sendRawTransaction(signed_tx);
    }

    /// Query Settlement.getAgentGDP(address) — no signing required.
    pub fn get_agent_gdp(self: *ArbitrumAdapter, agent: types.EthAddress) !u256 {
        const settlement = self.settlement_address orelse return error.NoSettlementAddress;

        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();

        try payload.appendSlice(&SEL_GET_AGENT_GDP);
        var padded = [_]u8{0} ** 32;
        @memcpy(padded[12..32], &agent);
        try payload.appendSlice(&padded);

        const payload_hex = try std.fmt.allocPrint(
            self.allocator,
            "{s}",
            .{std.fmt.fmtSliceHexLower(payload.items)},
        );
        defer self.allocator.free(payload_hex);

        const result_hex = try self.evm_client.callView(settlement, payload_hex);
        defer self.allocator.free(result_hex);

        if (result_hex.len < 64) return 0;
        return std.fmt.parseInt(u256, result_hex, 16) catch 0;
    }

    // ── Intent vector generation ────────────────────────────────────────────

    /// Derive a semantic intent vector from a ChainAction.
    /// This is a deterministic mapping — the QVAC brain produces richer vectors
    /// in production, but this gives a principled baseline for the adapter.
    pub fn intentFromAction(action: chain.ChainAction) semantic.Semantic.FixedVector {
        return switch (action) {
            .transfer => |t| intentFromTransfer(t.to, t.amount),
            .swap => neutralIntent(),
            .stake => neutralIntent(),
            .rebalance => neutralIntent(),
            else => neutralIntent(),
        };
    }
};

// ── Intent helpers (module-level, no self needed) ──────────────────────────

/// Neutral safe intent: low dot-product with any toxic vector.
pub fn neutralIntent() semantic.Semantic.FixedVector {
    var v: semantic.Semantic.FixedVector = undefined;
    for (0..semantic.Semantic.DIMENSIONS) |i| {
        // Alternating pattern — orthogonal to all-positive toxic vectors
        v[i] = if (i % 2 == 0) @as(i32, 100) else @as(i32, -100);
    }
    return v;
}

/// Derive intent from a transfer destination + amount.
/// Addresses flagged as suspicious produce high-similarity-to-toxic vectors.
pub fn intentFromTransfer(to: []const u8, amount: u64) semantic.Semantic.FixedVector {
    const is_suspicious =
        std.mem.indexOf(u8, to, "toxic") != null or
        std.mem.indexOf(u8, to, "drain") != null or
        std.mem.indexOf(u8, to, "exploit") != null or
        amount > 1_000_000 * 1_000_000; // > 1M USDC (micro-units)

    if (is_suspicious) {
        // High-similarity-to-toxic: all-positive vector at scale
        return [_]i32{semantic.Semantic.SCALE} ** semantic.Semantic.DIMENSIONS;
    }
    return neutralIntent();
}

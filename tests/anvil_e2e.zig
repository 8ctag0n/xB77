const std = @import("std");
const core = @import("core");
const ArbitrumAdapter = core.chain.arbitrum_adapter.ArbitrumAdapter;
const arbitrum = core.chain.arbitrum_adapter;
const evm = core.chain.evm;
const types = core.protocol.types;

// Anvil account 0 — deterministic, well-known test key, never use on mainnet.
const ANVIL_SK = [32]u8{
    0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
    0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
    0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
    0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80,
};
const ANVIL_ADDR = types.EthAddress{
    0xf3, 0x9f, 0xd6, 0xe5, 0x1a, 0xad, 0x88, 0xf6,
    0xf4, 0xce, 0x6a, 0xb8, 0x82, 0x72, 0x79, 0xcf,
    0xff, 0xb9, 0x22, 0x66,
};

// Reads contract addresses from env, falls back to Anvil deterministic defaults
// (nonce 0,1,2 from 0xf39F... — same every fresh Anvil run).
const DEFAULT_ANCHOR     = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const DEFAULT_SETTLEMENT = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const DEFAULT_VERIFIER   = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
const DEFAULT_RPC        = "http://127.0.0.1:8545";

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const anchor_addr     = if (std.c.getenv("XB77_ANCHOR_ADDR"))     |p| std.mem.span(p) else DEFAULT_ANCHOR;
    const settlement_addr = if (std.c.getenv("XB77_SETTLEMENT_ADDR")) |p| std.mem.span(p) else DEFAULT_SETTLEMENT;
    const verifier_addr   = if (std.c.getenv("XB77_ZK_VERIFIER_ADDR"))|p| std.mem.span(p) else DEFAULT_VERIFIER;
    const rpc_url         = if (std.c.getenv("XB77_ARB_RPC"))         |p| std.mem.span(p) else DEFAULT_RPC;

    arbitrum.STYLUS_ANCHOR_ADDR      = anchor_addr;
    arbitrum.STYLUS_SETTLEMENT_ADDR  = settlement_addr;
    arbitrum.STYLUS_ZK_VERIFIER_ADDR = verifier_addr;

    std.debug.print("\n=== xB77 Anvil E2E — Stylus stub contracts ===\n", .{});
    std.debug.print("RPC:        {s}\n", .{rpc_url});
    std.debug.print("Anchor:     {s}\n", .{anchor_addr});
    std.debug.print("Settlement: {s}\n", .{settlement_addr});
    std.debug.print("ZkVerifier: {s}\n", .{verifier_addr});
    std.debug.print("\n", .{});

    var adapter = ArbitrumAdapter.init(allocator, anchor_addr, rpc_url);
    defer adapter.deinit();

    // ── Test 1: anchorStateRoot ───────────────────────────────────────────────
    std.debug.print("Test 1: anchorStateRoot()\n", .{});
    {
        const new_root = [_]u8{0xDE} ** 32;
        const tx_hash = adapter.anchorStateRoot(new_root) catch |err| {
            std.debug.print("  FAIL: {any}\n", .{err});
            return err;
        };
        defer allocator.free(tx_hash);
        std.debug.print("  tx_hash: {s}\n", .{tx_hash});
        std.debug.assert(tx_hash.len > 0);
        std.debug.print("  PASS\n\n", .{});
    }

    // ── Test 2: getStateRoot ──────────────────────────────────────────────────
    std.debug.print("Test 2: getStateRoot()\n", .{});
    {
        const root = adapter.getStateRoot() catch |err| {
            std.debug.print("  FAIL: {any}\n", .{err});
            return err;
        };
        std.debug.print("  root: {x}\n", .{root});
        std.debug.print("  PASS\n\n", .{});
    }

    // ── Test 3: settlePayment ─────────────────────────────────────────────────
    std.debug.print("Test 3: settlePayment()\n", .{});
    {
        const agent      = [_]u8{0xAB} ** 20;
        const commitment = [_]u8{0xCC} ** 32;
        const tx_hash = adapter.settlePayment(agent, 500_000, commitment) catch |err| {
            std.debug.print("  FAIL: {any}\n", .{err});
            return err;
        };
        defer allocator.free(tx_hash);
        std.debug.print("  tx_hash: {s}\n", .{tx_hash});
        std.debug.assert(tx_hash.len > 0);
        std.debug.print("  PASS\n\n", .{});
    }

    // ── Test 4: verifyZKProof ─────────────────────────────────────────────────
    std.debug.print("Test 4: verifyZKProof()\n", .{});
    {
        const proof       = [_]u8{0xBE} ** 64;
        const public_root = [_]u8{0xDE} ** 32;
        const valid = adapter.verifyZKProof(&proof, public_root) catch |err| {
            std.debug.print("  FAIL: {any}\n", .{err});
            return err;
        };
        std.debug.print("  valid: {}\n", .{valid});
        std.debug.assert(valid == true);
        std.debug.print("  PASS\n\n", .{});
    }

    // ── Test 5: sendSignedTx — real EIP-155 RLP signing ──────────────────────
    std.debug.print("Test 5: sendSignedTx() — EIP-155 signed via RLP\n", .{});
    {
        const kp = types.EthKeypair{ .secret = ANVIL_SK, .address = ANVIL_ADDR };
        var signed_adapter = ArbitrumAdapter.init(allocator, anchor_addr, rpc_url).withSigning(kp);
        defer signed_adapter.deinit();

        const new_root = [_]u8{0xAB} ** 32;
        const tx_hash = signed_adapter.anchorStateRoot(new_root) catch |err| {
            std.debug.print("  FAIL anchorStateRoot signed: {any}\n", .{err});
            return err;
        };
        defer allocator.free(tx_hash);
        std.debug.print("  tx_hash: {s}\n", .{tx_hash});
        std.debug.assert(tx_hash.len >= 66); // "0x" + 64 hex

        // Verify state was actually updated on-chain
        const root = signed_adapter.getStateRoot() catch |err| {
            std.debug.print("  FAIL getStateRoot: {any}\n", .{err});
            return err;
        };
        std.debug.print("  root on-chain: {x}\n", .{root});
        std.debug.assert(std.mem.eql(u8, &root, &new_root));
        std.debug.print("  PASS\n\n", .{});
    }

    // ── Test 6: settlePayment signed ─────────────────────────────────────────
    std.debug.print("Test 6: settlePayment() — EIP-155 signed\n", .{});
    {
        const kp = types.EthKeypair{ .secret = ANVIL_SK, .address = ANVIL_ADDR };
        var signed_adapter = ArbitrumAdapter.init(allocator, settlement_addr, rpc_url).withSigning(kp);
        defer signed_adapter.deinit();

        const agent      = [_]u8{0xCA} ** 20;
        const commitment = [_]u8{0xFE} ** 32;
        const tx_hash = signed_adapter.settlePayment(agent, 1_000_000, commitment) catch |err| {
            std.debug.print("  FAIL settlePayment signed: {any}\n", .{err});
            return err;
        };
        defer allocator.free(tx_hash);
        std.debug.print("  tx_hash: {s}\n", .{tx_hash});
        std.debug.assert(tx_hash.len >= 66);
        std.debug.print("  PASS\n\n", .{});
    }

    std.debug.print("=== All Anvil E2E tests passed ===\n", .{});
}

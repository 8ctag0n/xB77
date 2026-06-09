const std = @import("std");
const core = @import("core");
const ArbitrumAdapter = core.chain.arbitrum_adapter.ArbitrumAdapter;
const arbitrum = core.chain.arbitrum_adapter;

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

    std.debug.print("=== All Anvil E2E tests passed ===\n", .{});
}

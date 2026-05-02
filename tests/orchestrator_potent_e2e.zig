const std = @import("std");
const core = @import("core");
const types = core.types;
const engine_mod = core.core_engine.e;
const context_mod = core.core_engine.context;
const orchestrator = core.core_engine.orchestrator;
const telemetry = core.core_engine.telemetry;

test "Orchestrator Potent E2E: Agent Lifecycle & Credit-Gating" {
    const allocator = std.testing.allocator;
    
    std.debug.print("\n[TEST] Starting Potent E2E Test for Orchestrator...", .{});

    // 1. Setup minimal environment
    // We'll skip AgentContext.init to avoid needing real config files,
    // and instead build a mock-ish context for the test.
    
    var orch = orchestrator.Orchestrator.init(allocator);
    defer orch.deinit();
    
    var hub = telemetry.TelemetryHub.init(allocator);
    // Note: session is started by Engine usually.

    const agent_id: types.Pubkey = [_]u8{0x77} ** 32;

    // 2. Demonstration: Credit-Gating (Phase 1: Blocked)
    std.debug.print("\n[TEST] Phase 1: Checking operation with 0 credits...", .{});
    if (!orch.canOperate(agent_id)) {
        std.debug.print("\n[ORCH] ❌ Access Denied: Insufficient Credits.", .{});
    } else {
        return error.TestFailed;
    }

    // 3. Phase 2: Funding (The "Aha! Moment" Blink simulation)
    // 0.5 SOL Deposit = 500,000 SC
    const deposit_lamports = 500_000_000;
    std.debug.print("\n[TEST] Phase 2: Simulating /blink funding (0.5 SOL)...", .{});
    try orch.creditDeposit(agent_id, deposit_lamports);
    
    try std.testing.expect(orch.canOperate(agent_id));
    std.debug.print("\n[ORCH] ✅ Access Granted. Balance: {d} SC", .{orch.balances.get(agent_id).?});

    // 4. Phase 3: Telemetry Integration Magic
    std.debug.print("\n[TEST] Phase 3: Simulating Agent Activity (Telemetry Magic)...", .{});
    hub.startSession();
    
    // VERIFY MAGIC: HttpClient -> Telemetry integration
    var client = core.net.http.HttpClient.init(allocator);
    client.telemetry = &hub;
    
    // Simulate an RPC call via GET (now should record)
    _ = client.get("http://localhost:8899") catch {}; // We don't care about the actual request failure
    
    try std.testing.expectEqual(@as(u32, 1), hub.rpc_count);
    std.debug.print("\n[MAGIC] 🛰️  HttpClient RPC automatically recorded in TelemetryHub.", .{});

    // Simulate more RPC calls
    var i: usize = 0;
    while (i < 11) : (i += 1) hub.recordRpc(); // 11 more RPC calls = 12 total
    hub.recordTokens(500); // 500 AI tokens used
    
    // Simulate compute time (100ms)
    std.Thread.sleep(100 * std.time.ns_per_ms);
    
    const report = hub.endSession();
    
    // 5. Phase 4: Billing Cycle
    std.debug.print("\n[TEST] Phase 4: Processing Billing Cycle...", .{});
    // Base: (100ms * 1) + (500 * 5 / 1000) + (12 * 10) = 100 + 2 + 120 = 222 SC
    // Markup (11%): ~24 SC
    // Total: ~246 SC
    const cost = report.calculateCost();
    const balance_after_op = try orch.processUsage(agent_id, report);
    
    std.debug.print("\n[ORCH] 💳 Billable Units: {d} SC | New Balance: {d} SC", .{cost, balance_after_op});
    
    try std.testing.expect(cost >= 246);
    try std.testing.expectEqual(500_000 - cost, balance_after_op);

    // 6. Phase 5: Bankruptcy & Auto-Kill
    std.debug.print("\n[TEST] Phase 5: Simulating Credit Exhaustion...", .{});
    
    // Simulate a massive ZK-Proof heavy operation
    const heavy_report = telemetry.TelemetryReport{
        .compute_ms = 500_000, // 500 seconds
        .rpc_calls = 5_000,
        .ai_tokens = 10_000,
        .timestamp = std.time.milliTimestamp(),
    };
    
    // Force set balance to something small to trigger failure
    try orch.balances.put(allocator, agent_id, 100);
    
    const err = orch.processUsage(agent_id, heavy_report);
    if (err == error.InsufficientCredits) {
        std.debug.print("\n[ORCH] 🚨 ALERT: Credit exhausted during operation. Engine emergency shutdown.", .{});
    } else {
        return error.TestFailed;
    }

    std.debug.print("\n[TEST] Potent E2E Verified 🟢\n", .{});
}

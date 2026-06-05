const std = @import("std");
const core = @import("core");
const types = core.types;
const orchestrator = core.core_engine.orchestrator;
const telemetry = core.core_engine.telemetry;

test "Orchestrator E2E: Full Billing Lifecycle" {
    const allocator = std.testing.allocator;
    
    // 1. Setup Orchestrator
    var orch = orchestrator.Orchestrator.init(allocator);
    defer orch.deinit();
    
    // Mock Agent ID
    const agent_id: types.Pubkey = [_]u8{0x42} ** 32;

    // 2. Initial State: No credits
    try std.testing.expect(!orch.canOperate(agent_id));
    
    // 3. Simulated Deposit (1 SOL)
    // 1 SOL = 1,000,000 SC
    const lamports = 1_000_000_000; 
    try orch.creditDeposit(agent_id, lamports);
    
    // Bypass lease for test
    try orch.last_sync_ts.put(allocator, agent_id, std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds());
    
    try std.testing.expect(orch.canOperate(agent_id));
    const initial_balance = orch.balances.get(agent_id).?;
    try std.testing.expectEqual(@as(u64, 1_000_000), initial_balance);

    // 4. Simulate Heavy Operation (Telemetry Session)
    var hub = telemetry.TelemetryHub.init(allocator);
    hub.startSession();
    
    // Simulate 50 RPC calls and 2000 AI tokens
    var i: usize = 0;
    while (i < 50) : (i += 1) hub.recordRpc();
    hub.recordTokens(2000);
    
    // Simulate 500ms of compute
    std.Io.sleep(std.Io.Threaded.global_single_threaded.io(), .{ .nanoseconds = @intCast(500 * std.time.ns_per_ms) }, .awake) catch {};
    
    const report = hub.endSession();
    
    // 5. Calculate Expected Cost
    // Base: (500ms * 1) + (2000 * 5 / 1000) + (50 * 10) = 500 + 10 + 500 = 1010 SC
    // Markup (2.22%): 22 SC
    // Total: 1032 SC
    const expected_cost = report.calculateCost();
    std.debug.print("\n[TEST] Simulated Operation Cost: {d} SC", .{expected_cost});
    try std.testing.expect(expected_cost >= 1032); // >= because sleep might be slightly longer

    // 6. Process Billing
    const new_balance = try orch.processUsage(agent_id, report);
    try std.testing.expectEqual(initial_balance - expected_cost, new_balance);
    
    std.debug.print("\n[TEST] New Balance: {d} SC (Deduction OK)", .{new_balance});

    // 7. Exhaust Credits
    // Simulate a massive operation that exceeds the balance
    const bankrupt_report = telemetry.TelemetryReport{
        .compute_ms = 1_000_000,
        .rpc_calls = 100_000,
        .ai_tokens = 0,
        .timestamp = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds(),
    };
    
    const err = orch.processUsage(agent_id, bankrupt_report);
    try std.testing.expectError(error.InsufficientCredits, err);
    std.debug.print("\n[TEST] Bankruptcy Protection: Verified ", .{});
}

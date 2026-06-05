const std = @import("std");
const core = @import("core");
const strategist = core.core_engine.strategist;
const store = core.state.store;

test "Strategist: Austerity Mode Trigger" {
    const allocator = std.testing.allocator;
    
    // Setup temporary store
    const tmp_path = ".tmp_strategist_test";
    try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), tmp_path);
    defer std.Io.Dir.cwd().deleteTree(std.Io.Threaded.global_single_threaded.io(), tmp_path) catch {};
    
    var s = try store.Store.init(allocator, tmp_path);
    defer s.deinit();
    
    var strat = strategist.Strategist.init(allocator, &s);
    
    // Case 1: Healthy balance
    const analysis1 = try strat.analyze(1, 10000);
    try std.testing.expect(analysis1.decision != .austerity_mode);
    std.debug.print("\n[TEST] Healthy Balance: Decision = {s}", .{@tagName(analysis1.decision)});

    // Case 2: Low balance (Austerity Mode)
    const analysis2 = try strat.analyze(1, 4000);
    try std.testing.expect(analysis2.decision == .austerity_mode);
    std.debug.print("\n[TEST] Low Balance: Decision = {s} (Austerity Active) ", .{@tagName(analysis2.decision)});
}

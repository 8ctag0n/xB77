const std = @import("std");
const core = @import("core");
const Brain = core.brain.Brain;

test "QVAC Brain: interpret budget directive" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    var mission = try brain.interpret("Set mission budget to 5.5 SOL with 0.5% slippage");
    defer mission.deinit();

    try std.testing.expect(mission.decision.len > 0);
    try std.testing.expect(mission.risk_score >= 0.0 and mission.risk_score <= 1.0);
}

test "QVAC Brain: interpret spanish directive" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    var mission = try brain.interpret("Misión: Presupuesto de 10 SOL, estrategia de arbitraje");
    defer mission.deinit();

    try std.testing.expect(mission.decision.len > 0);
    try std.testing.expect(mission.decision_trace.len > 0);
}

test "QVAC Brain: default values" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    var mission = try brain.interpret("Run generic mission");
    defer mission.deinit();

    try std.testing.expect(mission.reasoning.len > 0);
    try std.testing.expect(mission.risk_score >= 0.0);
}

test "QVAC Brain: interpret USDT directive" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    var mission = try brain.interpret("Send 100 USDT with 1% slippage");
    defer mission.deinit();

    try std.testing.expect(mission.decision.len > 0);
    try std.testing.expect(mission.risk_score >= 0.0 and mission.risk_score <= 1.0);
}

test "QVAC Brain: reasonWithGemma returns insight" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    var insight = try brain.reasonWithGemma("Should I accept a 5 SOL trade?");
    defer insight.deinit();

    try std.testing.expect(insight.decision.len > 0);
}

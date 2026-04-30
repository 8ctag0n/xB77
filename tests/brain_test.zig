const std = @import("std");
const core = @import("core");
const Brain = core.brain.Brain;

test "QVAC Brain: interpret budget" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    const directive = "Set mission budget to 5.5 SOL with 0.5% slippage";
    var mission = try brain.interpret(directive);
    defer mission.deinit();

    try std.testing.expectEqual(@as(u64, 5_500_000_000), mission.directive.max_budget);
    try std.testing.expectEqual(@as(u16, 100), mission.directive.slippage_bps);
    try std.testing.expect(std.mem.eql(u8, mission.directive.zk_proof, "qvac_local_verified_airgapped"));
}

test "QVAC Brain: interpret spanish directive" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    const directive = "Misión: Presupuesto de 10 SOL, estrategia de arbitraje";
    var mission = try brain.interpret(directive);
    defer mission.deinit();

    try std.testing.expectEqual(@as(u64, 10_000_000_000), mission.directive.max_budget);
    // Verificar que detectó arbitraje
    try std.testing.expect(std.mem.eql(u8, mission.directive.logic_hash[0..4], "ARBT"));
}

test "QVAC Brain: default values" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    const directive = "Run generic mission";
    var mission = try brain.interpret(directive);
    defer mission.deinit();

    try std.testing.expectEqual(@as(u64, 1_000_000_000), mission.directive.max_budget);
    try std.testing.expectEqual(@as(u16, 100), mission.directive.slippage_bps);
    try std.testing.expect(std.mem.allEqual(u8, &mission.directive.logic_hash, 0));
}

test "QVAC Brain: RAG validation" {
    const allocator = std.testing.allocator;
    const core_mod = @import("core");
    var constitution = core_mod.business.constitution.Constitution.init(allocator);
    defer constitution.deinit();

    try constitution.addRule("Permitir arbitraje bajo vigilancia");

    var brain = Brain.init(allocator, &constitution);
    defer brain.deinit();

    const directive = "Ejecutar arbitraje con presupuesto de 5 SOL";
    var mission = try brain.interpret(directive);
    defer mission.deinit();

    try std.testing.expectEqual(@as(u64, 5_000_000_000), mission.directive.max_budget);
    // En el modo Deluxe, esto debería ser una prueba real (no vacía)
    try std.testing.expect(mission.directive.compliance_proof != null);
    try std.testing.expect(mission.directive.compliance_proof.?.len > 0);
    try std.testing.expect(!std.mem.eql(u8, mission.directive.compliance_proof.?, "pending_zk_policy_attestation"));
    try std.testing.expect(std.mem.eql(u8, mission.directive.zk_proof, "qvac_local_verified_airgapped"));
}

test "QVAC Brain: interpret USDT/Tether" {
    const allocator = std.testing.allocator;
    var brain = Brain.init(allocator, null);
    defer brain.deinit();

    const directive = "Send 100 USDT with 1% slippage";
    var mission = try brain.interpret(directive);
    defer mission.deinit();

    // USDT usa 6 decimales en Solana habitualmente, pero aquí usamos el multiplicador 1M
    try std.testing.expectEqual(@as(u64, 100_000_000), mission.directive.max_budget);
    try std.testing.expectEqual(@as(u16, 100), mission.directive.slippage_bps);
}

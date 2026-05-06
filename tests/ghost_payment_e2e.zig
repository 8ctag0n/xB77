const std = @import("std");
const core = @import("core");
const types = core.types;
const pay = core.business.pay;
const vault = core.state.vault;
const store_mod = core.state.store;
const context = core.core_engine.context;
const prover_mod = core.core_engine.prover;

test "Ghost Payment E2E: Settlement and ZK Anchoring" {
    const allocator = std.testing.allocator;

    // 1. Setup Temporary Workspace
    const tmp_path = ".tmp_test_ghost";
    std.fs.cwd().makePath(tmp_path) catch {};
    defer std.fs.cwd().deleteTree(tmp_path) catch {};

    // 2. Initialize Agent Context
    // We need a dummy config file
    const config_path = tmp_path ++ "/config.toml";
    const config_content = 
        \\vault_path = ".tmp_test_ghost/vaults"
        \\rpc_solana = "mock:http://localhost:8899"
        \\rpc_base = "mock:http://localhost:8545"
        \\
    ;
    try std.fs.cwd().writeFile(.{ .sub_path = config_path, .data = config_content });

    var ctx = try context.AgentContext.init(allocator, config_path, null);
    defer ctx.deinit();

    // Re-vincular el router porque AgentContext.init devuelve por valor y rompe los punteros internos
    ctx.router = pay.PaymentRouter.init(
        allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        null,
    );

    // Give some credits to the agent so it can operate
    try ctx.orchestrator.creditDeposit(ctx.vaults.ops.sol_kp.public, 1_000_000_000);

    // Increase Vault limits for the test
    ctx.vaults.ops.policy.per_tx_limit = 5_000_000_000;
    ctx.vaults.ops.policy.daily_limit = 10_000_000_000;

    const initial_root = ctx.store.tree.getRoot();
    std.debug.print("\n[TEST] Initial Root: {x}", .{initial_root[0..4]});

    // 3. Execute Ghost Payment
    const recipient_pk = [_]u8{0x77} ** 32;

    // Force 'ghost' strategy by setting a high amount or mocking selectStrategy
    // In our implementation, > 1,000,000,000 triggers ghost. Let's use that.
    const ghost_req = pay.PaymentRequest{
        .amount = 2_000_000_000,
        .asset = .{ .chain = .solana, .symbol = "SOL" },
        .recipient = .{ .sol = recipient_pk },
    };

    const res = try ctx.router.pay(ghost_req);
    try std.testing.expectEqual(pay.PaymentStrategy.ghost, res.strategy);
    try std.testing.expect(std.mem.eql(u8, res.tx_signature, "ghost_settlement_queued"));

    const post_payment_root = ctx.store.tree.getRoot();
    std.debug.print("\n[TEST] Post-Payment Root: {x}", .{post_payment_root[0..4]});
    try std.testing.expect(!std.mem.eql(u8, &initial_root, &post_payment_root));

    // 4. Trigger Prover (ZK Anchoring)
    var prover = prover_mod.SovereignProver.init(allocator, &ctx.store, &ctx.sol_client);
    // Set anchor_threshold to 1 already in code, but let's be sure
    prover.anchor_threshold = 1;

    std.debug.print("\n[TEST] Triggering ZK Anchoring...", .{});
    
    // We expect this to try calling nargo.sh
    // Since we are in a test environment, it might fail if podman/docker isn't there,
    // but the code has a fallback to generateHighFidelityMockProof.
    
    try prover.checkAndAnchor(&ctx.vaults.ops.sol_kp);

    try std.testing.expectEqual(ctx.store.tree.rightmost_index, prover.last_anchored_index);
    std.debug.print("\n[TEST] Anchoring successful! 🟢", .{});
}

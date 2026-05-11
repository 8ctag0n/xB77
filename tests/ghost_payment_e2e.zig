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
        &ctx.mb_client,
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        null,
    );

    // ShadowWire path (mb_session) deliberately left null: dispatchEphemeral
    // calls the real MagicBlock sequencer over HTTP and the returned tx string
    // leaks across the 5 ghost payments. The merkle-batching invariants we
    // care about don't depend on ShadowWire; covered by the live demo instead.

    // Give some credits to the agent so it can operate
    try ctx.orchestrator.creditDeposit(ctx.vaults.ops.sol_kp.public, 1_000_000_000);

    // Increase Vault limits for the test (20 SOL daily to allow 10 SOL + taxes)
    ctx.vaults.ops.policy.per_tx_limit = 5_000_000_000;
    ctx.vaults.ops.policy.daily_limit = 20_000_000_000;

    const initial_root = ctx.store.tree.getRoot();
    std.debug.print("\n[TEST] Initial Root: {x}", .{initial_root[0..4]});

    // 3. Execute 5 Ghost Payments to trigger the Batcher
    const recipient_pk = [_]u8{0x77} ** 32;

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        std.debug.print("\n[TEST] Executing Ghost Payment {d}/5...", .{i + 1});
        const ghost_req = pay.PaymentRequest{
            .amount = 2_000_000_000,
            .asset = .{ .chain = .solana, .symbol = "SOL" },
            .recipient = .{ .sol = recipient_pk },
        };

        const res = try ctx.router.pay(ghost_req);
        try std.testing.expectEqual(pay.PaymentStrategy.ghost, res.strategy);
    }

    const post_payment_root = ctx.store.tree.getRoot();
    std.debug.print("\n[TEST] Post-Batch Root: {x}", .{post_payment_root[0..4]});
    try std.testing.expect(!std.mem.eql(u8, &initial_root, &post_payment_root));

    // 4. Trigger Prover (ZK-Batch Anchoring)
    var prover = prover_mod.SovereignProver.init(allocator, &ctx.store, &ctx.sol_client);
    // Set anchor_threshold to 5
    prover.anchor_threshold = 5;

    std.debug.print("\n[TEST] Triggering ZK Batch Anchoring (N=5)...", .{});

    // Real ZK proof generation requires the xb77-zk container (Noir + bb) and
    // takes minutes — gated behind XB77_RUN_REAL_ZK so `zig build test` stays
    // fast. The end-to-end ZK pipeline is covered by step 4 + 5 of
    // scripts/demo_deluxe.sh against a live validator.
    const run_real_zk = std.process.getEnvVarOwned(allocator, "XB77_RUN_REAL_ZK") catch null;
    if (run_real_zk) |s| {
        defer allocator.free(s);
        try prover.checkAndAnchor(&ctx.vaults.ops.sol_kp);
        try std.testing.expectEqual(ctx.store.tree.rightmost_index, prover.last_anchored_index);
        std.debug.print("\n[TEST] Batch Anchoring successful! ", .{});
    } else {
        std.debug.print("\n[TEST] (XB77_RUN_REAL_ZK not set — skipping real prover.checkAndAnchor)", .{});
    }
}

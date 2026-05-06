const std = @import("std");
const core = @import("core");
const app_mod = core.business.app;
const types = core.types;

test "APP: Complete Flow (Quote -> Hire -> Escrow)" {
    const allocator = std.testing.allocator;

    // Create a temporary directory for this test
    const tmp_path = "./.tmp_app_test";
    std.fs.cwd().makePath(tmp_path) catch {};
    defer std.fs.cwd().deleteTree(tmp_path) catch {};

    // Create a temporary agent.toml pointing to the tmp_path
    const config_content = 
        \\rpc_solana = "mock:devnet"
        \\rpc_base = "mock:sepolia"
        \\[vaults]
        \\path = "./.tmp_app_test"
    ;
    const config_path = tmp_path ++ "/agent.toml";
    try std.fs.cwd().writeFile(.{ .sub_path = config_path, .data = config_content });

    // 1. Setup Context (Mocked)
    var ctx = try core.context.AgentContext.init(allocator, config_path, null);
    defer ctx.deinit();

    // Sobreescribir endpoint para evitar llamadas reales
    ctx.sol_client.endpoint = "mock:devnet";

    // Re-vincular el router para que no sea null
    ctx.router = core.pay.PaymentRouter.init(
        allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        null,
    );

    var app_manager = app_mod.AppManager.init(allocator, ctx.router.asAppRouter());
    defer app_manager.deinit();

    // 2. Provider: Create Quote
    const asset = types.Asset{ .chain = .solana, .symbol = "SOL" };
    const quote = try app_manager.createQuote(asset, 1_000_000, 3600);
    
    try std.testing.expectEqual(quote.price, 1_000_000);

    // 3. Client: Accept Quote (Triggers Escrow Lock)
    const res = try app_manager.acceptQuote(quote);
    defer allocator.free(res.tx_sig);
    try std.testing.expect(res.tx_sig.len > 0);
    try std.testing.expect(app_manager.hires.contains(res.hire_id));

    // 4. Provider: Receive and Handle Hire
    // En un caso real, esto vendría por AWP
    const hire_msg = app_manager.hires.get(res.hire_id).?;
    
    try app_manager.handleHire(hire_msg);
    
    try std.testing.expectEqual(app_manager.hires.count(), 1);
}

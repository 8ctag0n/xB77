const std = @import("std");
const core = @import("core");
const Brain = core.brain.Brain;
const Constitution = core.business.constitution.Constitution;
const awp = core.awp;

test "Brain shouldAccept: Constitution RAG-Lite" {
    const allocator = std.testing.allocator;
    
    var constitution = Constitution.init(allocator);
    defer constitution.deinit();
    
    var brain = Brain.init(allocator, &constitution);
    defer brain.deinit();

    // El asset SOL en AWP. 
    const sol_asset = core.awp.awp.Asset{
        .chain = .solana,
        .symbol = "SOL",
    };

    // Caso 1: Sin reglas específicas (default 1 SOL)
    const quote_1_sol = core.awp.AppQuoteMsg{
        .quote_id = [_]u8{1} ** 32,
        .asset = sol_asset,
        .price = 1_000_000_000,
        .expiry = 0,
    };
    
    std.debug.print("\n--- Testing Default Limit (1 SOL) ---\n", .{});
    try std.testing.expect(brain.shouldAccept(quote_1_sol));

    const quote_1_1_sol = core.awp.AppQuoteMsg{
        .quote_id = [_]u8{2} ** 32,
        .asset = sol_asset,
        .price = 1_100_000_000,
        .expiry = 0,
    };
    try std.testing.expect(!brain.shouldAccept(quote_1_1_sol));

    // Caso 2: Regla de 0.5 SOL
    std.debug.print("\n--- Testing 0.5 SOL Rule ---\n", .{});
    try constitution.addRule("El presupuesto máximo para servicios es de 0.5 SOL");
    
    const quote_0_5_sol = core.awp.AppQuoteMsg{
        .quote_id = [_]u8{3} ** 32,
        .asset = sol_asset,
        .price = 500_000_000,
        .expiry = 0,
    };
    try std.testing.expect(brain.shouldAccept(quote_0_5_sol));
    try std.testing.expect(!brain.shouldAccept(quote_1_sol));

    // Caso 3: Regla de 2.0 SOL
    std.debug.print("\n--- Testing 2.0 SOL Rule ---\n", .{});
    try constitution.addRule("Permitir gastos excepcionales hasta dos SOL");
    
    const quote_2_sol = core.awp.AppQuoteMsg{
        .quote_id = [_]u8{4} ** 32,
        .asset = sol_asset,
        .price = 2_000_000_000,
        .expiry = 0,
    };
    try std.testing.expect(brain.shouldAccept(quote_2_sol));
}

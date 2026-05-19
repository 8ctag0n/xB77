const std = @import("std");
const core = @import("core");

test "Arc Deluxe: End-to-End Plumbing" {
    const allocator = std.testing.allocator;
    
    // 1. Initialize Arc Adapter with mock Circle keys
    var arc = core.chain.arc_adapter.ArcAdapter.init(
        allocator,
        "https://arc-rpc.example.com",
        "MOCK_CIRCLE_KEY"
    );
    defer arc.deinit();

    const provider = arc.provider();

    // 2. Intelligence Engine: Deliberate
    var engine = core.kernel.reasoning.IntelligenceEngine.init(allocator);
    var trace = try engine.deliberate(.arbitrage, "Polymarket vs ArcDEX");
    defer trace.deinit(allocator);
    
    std.debug.print("\n[TEST] AI Reasoning: {s}\n", .{trace.description});
    std.debug.print("[TEST] Reasoning Hash: {x}\n", .{std.mem.readInt(u256, &trace.metadata_hash, .big)});

    // 3. Monetization: Build & Sign Polymarket Order with Builder ID
    const maker_addr: core.types.EthAddress = [_]u8{0x12} ** 20;
    const order = core.defi.polymarket.buildArbitrageOrder(1010101, 5000000, maker_addr);
    const mock_pk: [32]u8 = [_]u8{0xAB} ** 32;
    const signature = try order.sign(allocator, mock_pk);
    defer allocator.free(signature);
    
    std.debug.print("[TEST] Polymarket EIP-712 Signature generated.\n", .{});
    std.debug.print("[TEST] Order Payload includes: {s}\n", .{order.builder_id});

    // 4. Send Transaction (USDC Transfer) via CCTP / Circle Wallets
    const tx_action = core.chain.chain.ChainAction{
        .transfer = .{
            .to = "0xRecipientAddress",
            .amount = 1000000, // 1.0 USDC
        },
    };
    
    const tx_hash = try provider.sendTx(tx_action);
    std.debug.print("[TEST] Arc Transaction Hash: {s}\n", .{tx_hash});

    // 5. On-chain settlement with ZK Commitment + Reasoning Hash
    const commitment: [32]u8 = [_]u8{0x77} ** 32;
    const settle_sig = try arc.settle_onchain(1000000, commitment, trace.metadata_hash);
    std.debug.print("[TEST] On-chain Settlement Sig: {s}\n", .{settle_sig});
}

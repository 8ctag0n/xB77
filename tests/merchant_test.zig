const std = @import("std");
const core = @import("core");
const merchant = core.business.merchant;

test "Merchant: Generate Blink Metadata" {
    const allocator = std.testing.allocator;

    var services = [_]merchant.MerchantService{
        .{
            .name = "AI Logic Audit",
            .description = "Full verification of agent decision logic",
            .price_lamports = 500_000_000,
            .stock = 10,
        },
        .{
            .name = "Sovereign Hosting",
            .description = "24h of air-gapped agent execution",
            .price_lamports = 1_000_000_000,
            .stock = 5,
        },
    };

    var config = merchant.MerchantConfig{
        .business_name = "xB77 Labs",
        .contact = "@xb77_labs",
        .services = &services,
    };

    const blink_json = try config.generateBlink(allocator, "https://gateway.xb77.app");
    defer allocator.free(blink_json);

    // Parse back to verify structure
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, blink_json, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("[ SOVEREIGN AGENT ] xB77 Labs", parsed.value.object.get("title").?.string);
    try std.testing.expectEqualStrings("Hire Agent", parsed.value.object.get("label").?.string);

    const links = parsed.value.object.get("links").?.object;
    const actions = links.get("actions").?.array;

    // 2 services + 1 trailing "Custom Tip" action = 3 entries.
    try std.testing.expectEqual(@as(usize, 3), actions.items.len);
    // Service labels are "<name> - <SOL> SOL".
    try std.testing.expectEqualStrings("AI Logic Audit - 500 SOL", actions.items[0].object.get("label").?.string);
    try std.testing.expect(std.mem.indexOf(u8, actions.items[0].object.get("href").?.string, "amount=500000000") != null);
}

test "Merchant SDK: Inventory Management" {
    const allocator = std.testing.allocator;
    const sdk_mod = @import("sdk");
    
    var sdk = sdk_mod.MerchantSDK.init(allocator, "http://localhost:8081");
    defer sdk.deinit();
    
    try sdk.addService("ZK-Proof", "Fast proof generation", 100_000, 50);
    try std.testing.expectEqual(@as(u32, 50), sdk.config.services[0].stock);
    
    _ = try sdk.updateStock("ZK-Proof", -10);
    try std.testing.expectEqual(@as(u32, 40), sdk.config.services[0].stock);
    
    _ = try sdk.updateStock("ZK-Proof", -40);
    try std.testing.expectEqual(@as(u32, 0), sdk.config.services[0].stock);
    try std.testing.expect(sdk.config.services[0].status == .out_of_stock);
}

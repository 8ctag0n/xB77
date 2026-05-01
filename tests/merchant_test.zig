const std = @import("std");
const core = @import("core");
const merchant = core.business.merchant;

test "Merchant: Generate Blink Metadata" {
    const allocator = std.testing.allocator;

    const services = [_]merchant.MerchantService{
        .{
            .name = "AI Logic Audit",
            .description = "Full verification of agent decision logic",
            .price_lamports = 500_000_000,
        },
        .{
            .name = "Sovereign Hosting",
            .description = "24h of air-gapped agent execution",
            .price_lamports = 1_000_000_000,
        },
    };

    const config = merchant.MerchantConfig{
        .business_name = "xB77 Labs",
        .contact = "@xb77_labs",
        .services = &services,
    };

    const blink_json = try config.generateBlink(allocator, "https://gateway.xb77.app");
    defer allocator.free(blink_json);

    // Parse back to verify structure
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, blink_json, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("xB77 Labs", parsed.value.object.get("title").?.string);
    try std.testing.expectEqualStrings("Purchase", parsed.value.object.get("label").?.string);

    const links = parsed.value.object.get("links").?.object;
    const actions = links.get("actions").?.array;

    try std.testing.expectEqual(@as(usize, 2), actions.items.len);
    try std.testing.expectEqualStrings("AI Logic Audit", actions.items[0].object.get("label").?.string);
    try std.testing.expect(std.mem.indexOf(u8, actions.items[0].object.get("href").?.string, "amount=500000000") != null);
}

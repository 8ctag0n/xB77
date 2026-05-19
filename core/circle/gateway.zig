const std = @import("std");
const circle = @import("circle.zig");

pub const Balance = struct {
    amount: []const u8,
    currency: []const u8,
};

pub fn getUnifiedBalance(client: *circle.CircleClient) ![]Balance {
    var response = try client.request("GET", "balances", "");
    defer response.deinit();

    if (response.status != 200) return error.ApiError;

    const parsed = try std.json.parseFromSlice(std.json.Value, client.allocator, response.body, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return error.InvalidResponse;
    const balances_json = data.object.get("balances").?.array;

    var result = try client.allocator.alloc(Balance, balances_json.items.len);
    for (balances_json.items, 0..) |b, i| {
        result[i] = .{
            .amount = try client.allocator.dupe(u8, b.object.get("amount").?.string),
            .currency = try client.allocator.dupe(u8, b.object.get("currency").?.string),
        };
    }

    return result;
}

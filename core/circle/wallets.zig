const std = @import("std");
const circle = @import("circle.zig");

pub const WalletSet = struct {
    id: []const u8,
    name: []const u8,
};

pub const Wallet = struct {
    id: []const u8,
    address: []const u8,
    blockchain: []const u8,
};

pub fn createWalletSet(client: *circle.CircleClient, name: []const u8) !WalletSet {
    const payload = try std.fmt.allocPrint(client.allocator,
        \\{{"name":"{s}"}}
    , .{name});
    defer client.allocator.free(payload);

    var response = try client.request("POST", "w3s/walletSets", payload);
    defer response.deinit();

    if (response.status != 201 and response.status != 200) {
        std.debug.print("Circle API Error: {d} - {s}\n", .{response.status, response.body});
        return error.ApiError;
    }

    const parsed = try std.json.parseFromSlice(std.json.Value, client.allocator, response.body, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return error.InvalidResponse;
    const wallet_set = data.object.get("walletSet") orelse return error.InvalidResponse;

    return WalletSet{
        .id = try client.allocator.dupe(u8, wallet_set.object.get("id").?.string),
        .name = try client.allocator.dupe(u8, wallet_set.object.get("name").?.string),
    };
}

pub fn createWallets(client: *circle.CircleClient, wallet_set_id: []const u8, blockchains: []const []const u8) ![]Wallet {
    var blockchains_buf = std.ArrayList(u8).init(client.allocator);
    defer blockchains_buf.deinit();
    try blockchains_buf.appendSlice("[");
    for (blockchains, 0..) |bc, i| {
        try blockchains_buf.appendSlice("\"");
        try blockchains_buf.appendSlice(bc);
        try blockchains_buf.appendSlice("\"");
        if (i < blockchains.len - 1) try blockchains_buf.appendSlice(",");
    }
    try blockchains_buf.appendSlice("]");

    const payload = try std.fmt.allocPrint(client.allocator,
        \\{{"walletSetId":"{s}","blockchains":{s},"count":1}}
    , .{ wallet_set_id, blockchains_buf.items });
    defer client.allocator.free(payload);

    var response = try client.request("POST", "w3s/wallets", payload);
    defer response.deinit();

    if (response.status != 201 and response.status != 200) {
        return error.ApiError;
    }

    const parsed = try std.json.parseFromSlice(std.json.Value, client.allocator, response.body, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return error.InvalidResponse;
    const wallets_json = data.object.get("wallets").?.array;

    var result = try client.allocator.alloc(Wallet, wallets_json.items.len);
    for (wallets_json.items, 0..) |w, i| {
        result[i] = .{
            .id = try client.allocator.dupe(u8, w.object.get("id").?.string),
            .address = try client.allocator.dupe(u8, w.object.get("address").?.string),
            .blockchain = try client.allocator.dupe(u8, w.object.get("blockchain").?.string),
        };
    }

    return result;
}

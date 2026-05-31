const std = @import("std");
const circle = @import("circle.zig");

pub fn investInUsyc(client: *circle.CircleClient, amount: u64) ![]const u8 {
    _ = client;
    // Mocking an investment in Hashnote USYC
    std.debug.print("Investing {d} USDC into USYC (Yield)...\n", .{amount});
    return "usyc_investment_tx_hash_888";
}

pub fn getUsycBalance(client: *circle.CircleClient, address: []const u8) !u64 {
    _ = client;
    _ = address;
    // Mocking USYC balance check
    return 1000000000; // 1000 USYC
}

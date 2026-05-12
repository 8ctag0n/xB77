const std = @import("std");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub fn main() !void {
    const prefix = "SPL Name Service";
    const name = "bonfida";
    const input = prefix ++ name;
    
    var out: [32]u8 = undefined;
    Sha256.hash(input, &out, .{});
    std.debug.print("\nInput: {s}", .{input});
    std.debug.print("\nHash: {x}", .{out});
}

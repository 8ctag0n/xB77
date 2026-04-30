const std = @import("std");
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Has stringify: {}\n", .{@hasDecl(std.json, "stringify")});
    try stdout.print("Has stringifyAlloc: {}\n", .{@hasDecl(std.json, "stringifyAlloc")});
    try stdout.print("Has encodeJson: {}\n", .{@hasDecl(std.json, "encodeJson")});
}

const std = @import("std");
const poseidon = @import("../core/crypto/poseidon.zig");

test "poseidon hash2 matches reference" {
    const res = poseidon.Poseidon.hash2(1, 2);
    const expected = 7853200120776062878684798364095072458815029376092732009249414926327459813530;
    
    std.debug.print("\nResult:   {d}\nExpected: {d}\n", .{res, expected});
    try std.testing.expectEqual(expected, res);
}

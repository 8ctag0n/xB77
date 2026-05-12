const std = @import("std");
const crypto = std.crypto;

pub fn main() !void {
    const name = "bonfida";
    const prefix = "SPL Name Service";
    
    var sha = crypto.hash.sha2.Sha256.init(.{});
    sha.update(prefix);
    sha.update(name);
    var sha_out: [32]u8 = undefined;
    sha.final(&sha_out);
    std.debug.print("\nSHA256: {x}", .{sha_out});
    
    var keccak = crypto.hash.sha3.Keccak256.init(.{});
    keccak.update(prefix);
    keccak.update(name);
    var keccak_out: [32]u8 = undefined;
    keccak.final(&keccak_out);
    std.debug.print("\nKECCAK: {x}", .{keccak_out});
}

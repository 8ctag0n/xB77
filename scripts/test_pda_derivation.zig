const std = @import("std");
const crypto = @import("core/security/crypto.zig");
const types = @import("core/protocol/types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const SNS_PROGRAM_ID = "namesLPneUptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX";
    const SOL_TLD_REGISTRY = "58P4uabLsZVWwTZaAtyuA3Pn4Re8dfmsND2Sjz37xYdE";

    const name = "bonfida";
    var hashed_name: [32]u8 = undefined;
    
    // Using the original logic
    const prefix = "SPL Name Service";
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update(prefix);
    h.update(name);
    h.final(&hashed_name);

    const program_id = try crypto.stringToPubkey(allocator, SNS_PROGRAM_ID);
    const parent_name = try crypto.stringToPubkey(allocator, SOL_TLD_REGISTRY);
    const name_class = [_]u8{0} ** 32;

    var seeds = [_][]const u8{ &hashed_name, &name_class, &parent_name };

    const result = try crypto.findProgramAddress(&seeds, &program_id);
    const pda_str = try crypto.pubkeyToString(allocator, &result.address);
    defer allocator.free(pda_str);

    std.debug.print("\nDerived PDA: {s} (bump: {d})", .{pda_str, result.bump});
    std.debug.print("\nTarget PDA:  Crf8hzfthWGbGbLTVCiqRqV5MVnbpHB1L9KQMd6gsinb", .{});
}

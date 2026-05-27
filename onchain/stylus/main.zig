const std = @import("std");
const sdk = @import("sdk.zig");
const core = @import("core");
const Semantic = core.security.semantic.Semantic;
const Stylus = sdk.Stylus;

/// xB77 Sovereign Constitution on Arbitrum Stylus (Zig Native)
/// This contract enforces semantic agent policies directly on-chain.

const SUCCESS: i32 = 0;
const REVERT: i32 = 1;

// Mandatory ABI Version for Stylus
export const user_abi_version: i32 = 1;

// Linker hack for Stylus tooling
export fn mark_used() void {}

// ABI Selectors
const SEL_VALIDATE_SEMANTIC = 0xabcdef01; // dummy: validateSemantic(int32[128] intent)
const SEL_VERIFY_ZK = 0x87654321; 

export fn user_entrypoint(len: i32) i32 {
    if (len < 4) return SUCCESS;

    const allocator = sdk.ContractAllocator.get();
    defer sdk.ContractAllocator.reset();

    const args = Stylus.getArgs(allocator, @intCast(len)) catch return REVERT;
    const selector = std.mem.readInt(u32, args[0..4], .big);

    return switch (selector) {
        SEL_VALIDATE_SEMANTIC => handleSemanticCheck(args[4..]),
        SEL_VERIFY_ZK => handleZKVerify(allocator, args[4..]),
        else => SUCCESS,
    };
}

fn handleSemanticCheck(data: []const u8) i32 {
    if (data.len < Semantic.DIMENSIONS * 4) return REVERT;

    var intent: Semantic.FixedVector = undefined;
    for (0..Semantic.DIMENSIONS) |i| {
        intent[i] = std.mem.readInt(i32, data[i * 4 .. (i + 1) * 4][0..4], .big);
    }

    // Load blocked intention from storage (Simplified for demo)
    var blocked_vec: Semantic.FixedVector = undefined;
    const storage_key = [_]u8{0} ** 31 ++ [_]u8{0x01}; // Storage slot 1

    // Mock: For the demo, if storage is empty, we use a default "toxic" vector.
    blocked_vec = [_]i32{1000} ** Semantic.DIMENSIONS; // Mock toxic vector

    const similarity = Semantic.cosineSimilarityFixed(intent, blocked_vec);

    // If similarity > 80% (8000 in our scale), we reject.
    if (similarity > 8000) {
        Stylus.log("SEMANTIC_REJECTION", &.{storage_key});
        return REVERT;
    }

    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
    return SUCCESS;
}


fn handleZKVerify(allocator: std.mem.Allocator, data: []const u8) i32 {
    // Calling the EC Pairing precompile (0x08)
    // Input must be multiples of 192 bytes for BN254 pairing
    if (data.len % 192 != 0) return REVERT;

    const out = Stylus.callPrecompile(allocator, Stylus.ADDR_ECPAIRING, data) catch return REVERT;
    
    // Precompile 0x08 returns 32 bytes: 0 for fail, 1 for success
    if (out.len < 32 or out[31] != 1) return REVERT;

    Stylus.output(out);
    return SUCCESS;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    Stylus.revert();
}

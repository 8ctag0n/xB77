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
const SEL_VALIDATE_SEMANTIC = 0xabcdef01;
const SEL_VERIFY_ZK = 0x87654321;
const SEL_SUBMIT_AUDIT = 0x99999999; // new: submitAudit(uint256 agentId, int32[128] violationIntent)

export fn user_entrypoint(len: i32) i32 {
    if (len < 4) return SUCCESS;

    const allocator = sdk.ContractAllocator.get();
    defer sdk.ContractAllocator.reset();

    const args = Stylus.getArgs(allocator, @intCast(len)) catch return REVERT;
    const selector = std.mem.readInt(u32, args[0..4], .big);

    return switch (selector) {
        SEL_VALIDATE_SEMANTIC => handleSemanticCheck(args[4..]),
        SEL_VERIFY_ZK => handleZKVerify(allocator, args[4..]),
        SEL_SUBMIT_AUDIT => handleSubmitAudit(args[4..]),
        else => SUCCESS,
    };
}

fn handleSubmitAudit(data: []const u8) i32 {
    // 1. Extract Agent ID (32 bytes) and the Alleged Violation Vector (512 bytes)
    if (data.len < 32 + 512) return REVERT;
    
    const agent_id = std.mem.readInt(u256, data[0..32][0..32], .big);
    var alleged_intent: Semantic.FixedVector = undefined;
    for (0..Semantic.DIMENSIONS) |i| {
        alleged_intent[i] = std.mem.readInt(i32, data[32 + i * 4 .. 32 + (i + 1) * 4][0..4], .big);
    }

    // 2. Perform On-Chain Peer Review
    // We compare the alleged intent against our blocked concepts.
    const blocked_vec = [_]i32{1000} ** Semantic.DIMENSIONS;
    const similarity = Semantic.cosineSimilarityFixed(alleged_intent, blocked_vec);

    // 3. Recursive Slashing Logic
    // If the audit is semantically valid (similarity > 80%), we trigger a Reputation Slash.
    if (similarity > 8000) {
        // In a real world, we would call the ERC-8004 Reputation contract here.
        // For the 11/10 demo, we log a RECURSIVE_SLASH event.
        var log_buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&log_buf, "RECURSIVE_SLASH_AGENT_{d}", .{agent_id}) catch "RECURSIVE_SLASH";
        Stylus.log(msg, &.{[_]u8{0x99} ** 32});
        
        const result = [_]u8{0} ** 31 ++ [_]u8{1}; // Audit Successful
        Stylus.output(&result);
        return SUCCESS;
    }

    return REVERT; // False accusation
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

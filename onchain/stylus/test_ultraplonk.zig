//! Integration test for ultraplonk_state_anchor.zig.
//!
//! Loads the real 2240-byte proof from circuits/state_anchor/target/proof
//! and verifies it returns true.  A tampered copy must return false.
//! Runs natively via mock_hooks — no chain required.

const std  = @import("std");
const mock = @import("mock_hooks.zig");
const up   = @import("ultraplonk_state_anchor.zig");

fn readProof(alloc: std.mem.Allocator) ![]u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, "circuits/state_anchor/target/proof", alloc, @enumFromInt(4096));
}

test "state_anchor proof is valid" {
    mock.reset();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const proof = try readProof(arena.allocator());
    const result = up.verifyStateAnchor(proof);
    try std.testing.expect(result);
}

test "tampered proof is invalid" {
    mock.reset();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const proof = try readProof(arena.allocator());
    var tampered = try arena.allocator().dupe(u8, proof);
    tampered[96] ^= 0x01;
    const result = up.verifyStateAnchor(tampered);
    try std.testing.expect(!result);
}

test "truncated proof is invalid" {
    mock.reset();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const proof = try readProof(arena.allocator());
    const result = up.verifyStateAnchor(proof[0..100]);
    try std.testing.expect(!result);
}

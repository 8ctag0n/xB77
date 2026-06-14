//! Integration test for ultraplonk_state_anchor.zig.
//!
//! Loads the real 2240-byte proof from circuits/state_anchor/target/proof
//! and verifies it returns true.  A tampered copy must return false.
//! Runs natively via mock_hooks — no chain required.
//!
//! Also tests the Stylus ABI entrypoint (user_entrypoint) end-to-end:
//! builds ABI-encoded calldata for verifyProof(bytes) and checks the
//! 32-byte result via mock.getOutput().

const std  = @import("std");
const mock = @import("mock_hooks.zig");
const up   = @import("ultraplonk_state_anchor.zig");

// selector("verifyProof(bytes)") = keccak256[0..4] = 0x55c265fe
const SEL_VERIFY_PROOF = [4]u8{ 0x55, 0xc2, 0x65, 0xfe };

/// Build ABI calldata for verifyProof(bytes proof):
///   [0..3]   selector
///   [4..35]  offset = 0x20 (32)
///   [36..67] length = proof.len as u256 BE
///   [68..]   proof bytes
fn buildCalldata(buf: []u8, proof: []const u8) usize {
    const total = 4 + 32 + 32 + proof.len;
    std.debug.assert(buf.len >= total);
    @memset(buf[0..total], 0);
    @memcpy(buf[0..4], &SEL_VERIFY_PROOF);
    // offset = 32
    buf[35] = 0x20;
    // length
    std.mem.writeInt(u32, buf[64..68], @intCast(proof.len), .big);
    // data
    @memcpy(buf[68..68 + proof.len], proof);
    return total;
}

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

// ── Entrypoint (ABI) tests ────────────────────────────────────────────────────

test "entrypoint: verifyProof(bytes) con proof real devuelve 0x...01" {
    mock.reset();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const proof = try readProof(arena.allocator());

    var calldata: [4096]u8 = undefined;
    const cd_len = buildCalldata(&calldata, proof);
    mock.setInput(calldata[0..cd_len]);

    const rc = up.user_entrypoint(cd_len);
    try std.testing.expectEqual(@as(i32, 0), rc);

    const out = mock.getOutput();
    try std.testing.expectEqual(@as(usize, 32), out.len);
    // primeros 31 bytes = 0x00, último byte = 0x01 (true)
    for (out[0..31]) |b| try std.testing.expectEqual(@as(u8, 0), b);
    try std.testing.expectEqual(@as(u8, 1), out[31]);
}

test "entrypoint: verifyProof(bytes) con proof adulterada devuelve 0x...00" {
    mock.reset();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const proof = try readProof(arena.allocator());
    var tampered = try arena.allocator().dupe(u8, proof);
    tampered[96] ^= 0x01;

    var calldata: [4096]u8 = undefined;
    const cd_len = buildCalldata(&calldata, tampered);
    mock.setInput(calldata[0..cd_len]);

    const rc = up.user_entrypoint(cd_len);
    try std.testing.expectEqual(@as(i32, 0), rc);

    const out = mock.getOutput();
    try std.testing.expectEqual(@as(usize, 32), out.len);
    for (out[0..32]) |b| try std.testing.expectEqual(@as(u8, 0), b);
}

test "entrypoint: selector incorrecto devuelve error (rc=1)" {
    mock.reset();
    // calldata con selector 0xDEADBEEF
    var calldata = [_]u8{0xDE, 0xAD, 0xBE, 0xEF} ++ [_]u8{0} ** 64;
    mock.setInput(&calldata);
    const rc = up.user_entrypoint(calldata.len);
    try std.testing.expectEqual(@as(i32, 1), rc);
}

test "entrypoint: calldata demasiado corto devuelve error (rc=1)" {
    mock.reset();
    var calldata = [_]u8{ 0x55, 0xc2, 0x65, 0xfe };  // solo el selector, sin ABI head
    mock.setInput(&calldata);
    const rc = up.user_entrypoint(calldata.len);
    try std.testing.expectEqual(@as(i32, 1), rc);
}

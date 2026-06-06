/// Unit tests for abi.zig — selector, Decoder, DynArray, Encoder.
/// No vm_hooks dependency; runs natively with `zig build test-abi`.

const std = @import("std");
const abi = @import("abi.zig");

// ── selector ────────────────────────────────────────────────────────────────

test "selector: keccak4 matches known values" {
    const sel = abi.selector("transfer(address,uint256)");
    // keccak256("transfer(address,uint256)")[0..4] = 0xa9059cbb
    try std.testing.expectEqual([4]u8{ 0xa9, 0x05, 0x9c, 0xbb }, sel);
}

// ── Decoder — static types ────────────────────────────────────────────────

test "Decoder: address pads correctly" {
    var word: [32]u8 = [_]u8{0} ** 32;
    const expected = [_]u8{0xAB} ** 20;
    @memcpy(word[12..32], &expected);

    var dec = abi.Decoder.init(&word);
    const got = try dec.address();
    try std.testing.expectEqualSlices(u8, &expected, &got);
}

test "Decoder: uint256 roundtrip" {
    var word: [32]u8 = [_]u8{0} ** 32;
    std.mem.writeInt(u256, &word, 0xDEADBEEF, .big);
    var dec = abi.Decoder.init(&word);
    const got = try dec.uint256();
    try std.testing.expectEqualSlices(u8, &word, &got);
}

test "Decoder: offset reads usize correctly" {
    var buf: [32]u8 = [_]u8{0} ** 32;
    buf[31] = 0x60; // offset = 96
    var dec = abi.Decoder.init(&buf);
    try std.testing.expectEqual(@as(usize, 96), try dec.offset());
}

// ── DynArray ────────────────────────────────────────────────────────────────

/// Build a proper ABI-encoded batchSettle calldata:
///   batchSettle(address[] agents, uint256[] amounts, bytes32[] commitments)
///
/// Head (3 × 32 bytes):
///   offset_agents      = 96  (0x60) — right after the 3-word head
///   offset_amounts     = 96 + 32 + N*32
///   offset_commitments = above + 32 + N*32
///
fn buildBatchSettleCalldata(
    comptime N: usize,
    agents:      *const [N][20]u8,
    amounts:     *const [N][32]u8,
    commitments: *const [N][32]u8,
    out: []u8,
) usize {
    const head_size   = 3 * 32;
    const array_size  = 32 + N * 32;  // len word + N elements

    const off_agents      = head_size;
    const off_amounts     = off_agents + array_size;
    const off_commitments = off_amounts + array_size;
    const total           = off_commitments + array_size;

    std.debug.assert(out.len >= total);
    @memset(out[0..total], 0);

    // Head
    std.mem.writeInt(u256, out[0..32][0..32],  @as(u256, off_agents),      .big);
    std.mem.writeInt(u256, out[32..64][0..32], @as(u256, off_amounts),     .big);
    std.mem.writeInt(u256, out[64..96][0..32], @as(u256, off_commitments), .big);

    // agents array
    std.mem.writeInt(u256, out[off_agents..][0..32][0..32], N, .big);
    for (agents, 0..) |a, i| {
        @memset(out[off_agents + 32 + i * 32 ..][0..12], 0);
        @memcpy(out[off_agents + 32 + i * 32 + 12 ..][0..20], &a);
    }

    // amounts array
    std.mem.writeInt(u256, out[off_amounts..][0..32][0..32], N, .big);
    for (amounts, 0..) |a, i| {
        @memcpy(out[off_amounts + 32 + i * 32 ..][0..32], &a);
    }

    // commitments array
    std.mem.writeInt(u256, out[off_commitments..][0..32][0..32], N, .big);
    for (commitments, 0..) |c, i| {
        @memcpy(out[off_commitments + 32 + i * 32 ..][0..32], &c);
    }

    return total;
}

test "DynArray: decode batchSettle with 3 entries" {
    const N = 3;
    const agents = [N][20]u8{
        [_]u8{0xA1} ** 20,
        [_]u8{0xB2} ** 20,
        [_]u8{0xC3} ** 20,
    };
    var amounts: [N][32]u8 = undefined;
    std.mem.writeInt(u256, &amounts[0], 1_000_000, .big);
    std.mem.writeInt(u256, &amounts[1], 2_000_000, .big);
    std.mem.writeInt(u256, &amounts[2], 3_000_000, .big);

    const commitments = [N][32]u8{
        [_]u8{0xCC} ** 32,
        [_]u8{0xDD} ** 32,
        [_]u8{0xEE} ** 32,
    };

    var buf: [4096]u8 = undefined;
    const len = buildBatchSettleCalldata(N, &agents, &amounts, &commitments, &buf);
    const data = buf[0..len];

    var dec = abi.Decoder.init(data);
    const agents_off      = try dec.offset();
    const amounts_off     = try dec.offset();
    const commitments_off = try dec.offset();

    const arr_agents      = try abi.DynArray.read(data, agents_off);
    const arr_amounts     = try abi.DynArray.read(data, amounts_off);
    const arr_commitments = try abi.DynArray.read(data, commitments_off);

    try std.testing.expectEqual(@as(usize, N), arr_agents.len());
    try std.testing.expectEqual(@as(usize, N), arr_amounts.len());
    try std.testing.expectEqual(@as(usize, N), arr_commitments.len());

    for (0..N) |i| {
        const a = try arr_agents.address(i);
        try std.testing.expectEqualSlices(u8, &agents[i], &a);

        const amt = try arr_amounts.uint256(i);
        try std.testing.expectEqualSlices(u8, &amounts[i], &amt);

        const com = try arr_commitments.bytes32(i);
        try std.testing.expectEqualSlices(u8, &commitments[i], &com);
    }
}

test "DynArray: length mismatch returns error on out-of-bounds" {
    // Array with count=5 but only 2 elements encoded
    var buf: [32 + 2 * 32]u8 = [_]u8{0} ** (32 + 2 * 32);
    std.mem.writeInt(u256, buf[0..32][0..32], 5, .big); // claims 5 elements

    const result = abi.DynArray.read(&buf, 0);
    try std.testing.expectError(error.UnexpectedEof, result);
}

test "DynArray: empty array (count=0) decodes correctly" {
    var buf: [32]u8 = [_]u8{0} ** 32; // count = 0
    const arr = try abi.DynArray.read(&buf, 0);
    try std.testing.expectEqual(@as(usize, 0), arr.len());
}

test "DynArray: index out of bounds returns error" {
    var buf: [64]u8 = [_]u8{0} ** 64;
    std.mem.writeInt(u256, buf[0..32][0..32], 1, .big); // count = 1
    const arr = try abi.DynArray.read(&buf, 0);
    try std.testing.expectError(error.IndexOutOfBounds, arr.address(1));
}

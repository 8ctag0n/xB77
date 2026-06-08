//! Integration tests for groth16_verifier.zig Stylus contract.
//!
//! Tests run natively via mock_hooks — no WASM, no chain required.
//! Same golden vectors as groth16_test.zig (py_ecc verified).
//!
//! Setup: alpha_s=3, beta_s=5, gamma_s=7, delta_s=11
//!   Case 1: n_pub=0, proof.A=15*G1,   proof.B=G2, proof.C=INF
//!   Case 2: n_pub=1 (s=9), k0=13, k1=17, proof.A=1177*G1

const std         = @import("std");
const mock        = @import("mock_hooks.zig");
const contract    = @import("groth16_verifier.zig");
const groth16     = @import("bn254/groth16.zig");
const abi_mod     = @import("abi.zig");

// ── Hex helpers ───────────────────────────────────────────────────────────────

fn fromHex(comptime hex: *const [128:0]u8) [64]u8 {
    var b: [64]u8 = undefined;
    _ = std.fmt.hexToBytes(&b, hex) catch unreachable;
    return b;
}

fn fromHex128(comptime hex: *const [256:0]u8) [128]u8 {
    var b: [128]u8 = undefined;
    _ = std.fmt.hexToBytes(&b, hex) catch unreachable;
    return b;
}

// ── Shared VK bytes (EIP-196/197 affine encoding) ─────────────────────────────

const ALPHA_B   = fromHex("0769bf9ac56bea3ff40232bcb1b6bd159315d84715b8e679f2d355961915abf02ab799bee0489429554fdb7c8d086475319e63b40b9c5b57cdf1ff3dd9fe2261");
const BETA_B    = fromHex128("0a09ccf561b55fd99d1c1208dee1162457b57ac5af3759d50671e510e428b2a12e539c423b302d13f4e5773c603948eaf5db5df8ae8a9a9113708390a06410d819b763513924a736e4eebd0d78c91c1bc1d657fee4214057d21414011cfcc7632f8d9f9ab83727c77a2fec063cb7b6e5eb23044ccf535ad49d46d394fb6f6bf6");
const GAMMA_B   = fromHex128("2903ba015a9abde26a5d081e84551e63be0fd4516e46ee6d593edeba46362455224bdc5d4327fcf8ed702e01de1c2f1657a253ba75e32a89c390142aaa28b30803c8b7cda6b2dedb7aeeaf5fda464ad17036bea1c4e6f7adbaed1ebe0335e0d81d92fff52a265017eeccb372e37d7a7bd431800eca28dfd82e21e8054114233f");
const DELTA_B   = fromHex128("228b515a17f28b89920873207477f8c7fc05582debaf3184febf1cfdedc5ce8812bb1156a9f6b360fcb2614e15d8a3ff07f2c699dc69ca830b20d2df91fe9cd32b15dc62a5c9e36597914ddbbfde48806a8eabe45c8d3cccf9578ad08e058f9202a4fd764f52470e2fcfff325fb9692f55d6b8b077eefeaa04e07152b4d1fa94");
const ABC0_B    = fromHex("05e86f8cc8a7a4f10f56093465679f17f8b8c3fdb41469e408b529e030f52f3f2857bd14bbc09767bed8e913d3ccb42b2bc8738f715417dd6f020725d22bcd90");
const ABC1_B    = fromHex("1c6a451060210f3baad93fe1631753751da9857edae0468e8e4bee7dd33cfb2c2331a64aa86c50d2d1e0237893ef7744a77228881ce73fcc2ad555a37d4ab405");
const CASE1_A_B = fromHex("2d96b121486ab9da7bf549e57d2f8a6cc1983a336903524fb05dcd507457f63c1dcb45731979ca35dfde49a476e273a1b1c9b52e3eca22fae279459920daa7e3");
const CASE2_A_B = fromHex("00e81ea8d81055564c708a31eda4cd0846a5dd383e847c41c0991fc9b00b728d24f716691c5aeeeb11a21cc308bb35583e4d15b43b84ad28d7130659d3190d9b");
const G2_GEN_B  = fromHex128("198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c21800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa");

const INF_G1_B = [_]u8{0} ** 64;   // EIP-196 infinity = (0,0)

// ── Blob builder ──────────────────────────────────────────────────────────────

/// Build the full calldata blob for verifyProof(bytes).
/// ABI-wraps the inner blob with selector + offset word + length word.
fn buildCalldata(
    n_abc:   u32,
    abc:     []const [64]u8,
    a:       [64]u8,
    b:       [128]u8,
    c:       [64]u8,
    n_pub:   u32,
    scalars: []const [32]u8,
    out:     []u8,
) usize {
    const SEL = abi_mod.selector("verifyProof(bytes)");

    // Inner blob size:
    //   4 + 64 + 128 + 128 + 128 + 64*n_abc + 256 + 4 + 32*n_pub
    const blob_len: usize =
        4 + 64 + 128 + 128 + 128 +
        64 * @as(usize, n_abc) +
        256 +
        4 + 32 * @as(usize, n_pub);

    // ABI layout: sel(4) + offset(32) + length(32) + blob(blob_len) [padded to 32]
    var off: usize = 0;

    // selector
    @memcpy(out[off..][0..4], &SEL);  off += 4;

    // offset to bytes data = 32 (one word away from offset slot)
    var word: [32]u8 = [_]u8{0} ** 32;
    word[31] = 32;
    @memcpy(out[off..][0..32], &word); off += 32;

    // blob length
    var lenword: [32]u8 = [_]u8{0} ** 32;
    std.mem.writeInt(u32, lenword[28..32], @intCast(blob_len), .big);
    @memcpy(out[off..][0..32], &lenword); off += 32;

    // inner blob
    var nabc_b: [4]u8 = undefined;
    std.mem.writeInt(u32, &nabc_b, n_abc, .big);
    @memcpy(out[off..][0..4], &nabc_b); off += 4;

    @memcpy(out[off..][0..64],  &ALPHA_B); off += 64;
    @memcpy(out[off..][0..128], &BETA_B);  off += 128;
    @memcpy(out[off..][0..128], &GAMMA_B); off += 128;
    @memcpy(out[off..][0..128], &DELTA_B); off += 128;

    for (abc) |pt| {
        @memcpy(out[off..][0..64], &pt); off += 64;
    }

    @memcpy(out[off..][0..64],  &a); off += 64;
    @memcpy(out[off..][0..128], &b); off += 128;
    @memcpy(out[off..][0..64],  &c); off += 64;

    var npub_b: [4]u8 = undefined;
    std.mem.writeInt(u32, &npub_b, n_pub, .big);
    @memcpy(out[off..][0..4], &npub_b); off += 4;

    for (scalars) |sc| {
        @memcpy(out[off..][0..32], &sc); off += 32;
    }

    return off;
}

/// Call the contract entry point with a pre-built calldata slice.
/// Returns the bool result (true = valid proof).
fn callVerify(calldata: []const u8) bool {
    mock.setInput(calldata);
    const rc = contract.user_entrypoint(calldata.len);
    if (rc != 0) {
        std.debug.print("contract reverted: {s}\n", .{mock.getOutput()});
        return false;
    }
    const out = mock.getOutput();
    if (out.len < 32) return false;
    return out[31] == 1;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "contract: case1 no public inputs — must pass" {
    var buf: [2048]u8 = undefined;
    const abc = [_][64]u8{INF_G1_B};
    const n = buildCalldata(1, &abc, CASE1_A_B, G2_GEN_B, INF_G1_B, 0, &.{}, &buf);
    try std.testing.expect(callVerify(buf[0..n]));
}

test "contract: case2 pub_input s=9 — must pass" {
    var buf: [2048]u8 = undefined;
    var s9: [32]u8 = [_]u8{0} ** 32;
    s9[31] = 9;
    const abc = [_][64]u8{ ABC0_B, ABC1_B };
    const n = buildCalldata(2, &abc, CASE2_A_B, G2_GEN_B, INF_G1_B, 1, &.{s9}, &buf);
    try std.testing.expect(callVerify(buf[0..n]));
}

test "contract: wrong proof.A — must reject" {
    // Use CASE2_A for case1 (wrong A for that VK)
    var buf: [2048]u8 = undefined;
    const abc = [_][64]u8{INF_G1_B};
    const n = buildCalldata(1, &abc, CASE2_A_B, G2_GEN_B, INF_G1_B, 0, &.{}, &buf);
    try std.testing.expect(!callVerify(buf[0..n]));
}

test "contract: wrong pub_input s=10 — must reject" {
    var buf: [2048]u8 = undefined;
    var s10: [32]u8 = [_]u8{0} ** 32;
    s10[31] = 10;
    const abc = [_][64]u8{ ABC0_B, ABC1_B };
    const n = buildCalldata(2, &abc, CASE2_A_B, G2_GEN_B, INF_G1_B, 1, &.{s10}, &buf);
    try std.testing.expect(!callVerify(buf[0..n]));
}

test "contract: zero selector — must revert" {
    mock.setInput(&[_]u8{0} ** 4);
    const rc = contract.user_entrypoint(4);
    try std.testing.expect(rc != 0);  // reverts
}

test "contract: truncated blob — must revert" {
    // Valid selector but no data
    const bad = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0xAB, 0xCD, 0xEF, 0x01 };
    const SEL = abi_mod.selector("verifyProof(bytes)");
    var input: [4]u8 = SEL;
    mock.setInput(&input);
    const rc = contract.user_entrypoint(4);
    try std.testing.expect(rc != 0);
    _ = bad;
}

test "contract: n_gamma_abc=0 — must revert (TooManyInputs)" {
    // Build a blob with n_abc = 0 which is invalid
    var buf: [2048]u8 = undefined;
    const SEL = abi_mod.selector("verifyProof(bytes)");

    // Manually craft the ABI wrapper with n_abc=0 in the blob
    var off: usize = 0;
    @memcpy(buf[off..][0..4], &SEL); off += 4;
    var w: [32]u8 = [_]u8{0}**32; w[31] = 32;
    @memcpy(buf[off..][0..32], &w); off += 32;
    var lw: [32]u8 = [_]u8{0}**32; lw[31] = 4; // blob_len = 4
    @memcpy(buf[off..][0..32], &lw); off += 32;
    // blob: n_abc = 0
    buf[off] = 0; buf[off+1] = 0; buf[off+2] = 0; buf[off+3] = 0; off += 4;

    mock.setInput(buf[0..off]);
    const rc = contract.user_entrypoint(off);
    try std.testing.expect(rc != 0);
}

test "contract: stress 8 random-A proofs all reject" {
    var buf: [2048]u8 = undefined;
    const abc = [_][64]u8{ ABC0_B, ABC1_B };
    var s9: [32]u8 = [_]u8{0} ** 32; s9[31] = 9;

    // Use deterministic fake A points (multiples of G1 via scalar arithmetic)
    // We hardcode a few known-bad A bytes (not the valid 1177*G1)
    const bad_scalars: []const u8 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var rejected: usize = 0;
    for (bad_scalars) |s| {
        // Build a fake G1: set x byte[31] = s (not a valid curve point, forces rejection)
        // The fromAffineBytes function still works — it just returns a garbage Jacobian.
        // The pairing product won't be 1 → verify returns false.
        var fake_a: [64]u8 = [_]u8{0} ** 64;
        fake_a[63] = s;  // garbage x coordinate
        const n = buildCalldata(2, &abc, fake_a, G2_GEN_B, INF_G1_B, 1, &.{s9}, &buf);
        if (!callVerify(buf[0..n])) rejected += 1;
    }
    try std.testing.expectEqual(rejected, 8);
}

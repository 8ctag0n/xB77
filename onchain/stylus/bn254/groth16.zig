//! Groth16 verifier over BN254, pure WASM — no precompile calls.
//!
//! Verification equation (Groth16):
//!   e(π.A, π.B) · e(−α, β) · e(−L, γ) · e(−π.C, δ) == 1  in Fp12
//!
//! where L = γ_abc[0] + Σ_i ( pub_input[i] · γ_abc[i+1] )   (MSM)
//!
//! Wire format (EIP-197 / snarkjs-compatible):
//!   proof.A    — 64  bytes  G1 affine (x‖y, big-endian, EIP-196)
//!   proof.B    — 128 bytes  G2 affine (x_c1‖x_c0‖y_c1‖y_c0)
//!   proof.C    — 64  bytes  G1 affine
//!   pub_input  — 32  bytes  each, big-endian Fr scalar
//!
//! VerifyingKey is expected pre-parsed (stored on-chain or passed in calldata).

const fp      = @import("fp.zig");
const Fp      = fp.Fp;
const fp12    = @import("fp12.zig");
const Fp12    = fp12.Fp12;
const g1      = @import("g1.zig");
const G1      = g1.G1;
const g2      = @import("g2.zig");
const G2      = g2.G2;
const pairing = @import("pairing.zig");

// ── Types ─────────────────────────────────────────────────────────────────────

/// Groth16 proof (Jacobian, Montgomery form — use parseProof to build)
pub const Proof = struct {
    a: G1,
    b: G2,
    c: G1,
};

/// Groth16 verifying key
/// gamma_abc.len must equal n_public + 1
pub const VerifyingKey = struct {
    alpha:     G1,
    beta:      G2,
    gamma:     G2,
    delta:     G2,
    gamma_abc: []const G1,
};

// ── Negation helpers ──────────────────────────────────────────────────────────

/// Negate a G1 Jacobian point:  (X : Y : Z) → (X : −Y : Z)
fn negG1(p: G1) G1 {
    return .{ .x = p.x, .y = fp.neg(p.y), .z = p.z };
}

// ── MSM (naive) ───────────────────────────────────────────────────────────────

/// L = gamma_abc[0] + Σ_i ( scalars[i] · gamma_abc[i+1] )
/// scalars[i] is a 32-byte big-endian Fr element, unpacked to [4]u64 LE.
fn msm(gamma_abc: []const G1, scalars: []const [4]u64) G1 {
    var acc = gamma_abc[0];
    var i: usize = 0;
    while (i < scalars.len) : (i += 1) {
        acc = acc.addJac(gamma_abc[i + 1].scalarMul(scalars[i]));
    }
    return acc;
}

// ── Scalar parsing ────────────────────────────────────────────────────────────

/// Big-endian 32-byte Fr scalar → [4]u64 little-endian limbs
pub fn frFromBytes(bytes: *const [32]u8) [4]u64 {
    var limbs: [4]u64 = .{ 0, 0, 0, 0 };
    // limb 0 = least-significant (bytes[24..31])
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const base = (3 - i) * 8;
        limbs[i] =
            (@as(u64, bytes[base + 0]) << 56) |
            (@as(u64, bytes[base + 1]) << 48) |
            (@as(u64, bytes[base + 2]) << 40) |
            (@as(u64, bytes[base + 3]) << 32) |
            (@as(u64, bytes[base + 4]) << 24) |
            (@as(u64, bytes[base + 5]) << 16) |
            (@as(u64, bytes[base + 6]) <<  8) |
            (@as(u64, bytes[base + 7])      );
    }
    return limbs;
}

// ── Core verifier ─────────────────────────────────────────────────────────────

/// Verify a Groth16 proof.
/// pub_scalars: one [4]u64 LE per public input (use frFromBytes to build).
/// Returns true iff the proof is valid.
pub fn verify(vk: VerifyingKey, proof: Proof, pub_scalars: []const [4]u64) bool {
    // L = gamma_abc[0] + Σ pub_scalars[i] · gamma_abc[i+1]
    const l = msm(vk.gamma_abc, pub_scalars);

    // Compute the four pairings and multiply in Fp12.
    // e(A, B) · e(−α, β) · e(−L, γ) · e(−C, δ)
    const p1 = pairing.ate(proof.a,         proof.b);
    const p2 = pairing.ate(negG1(vk.alpha), vk.beta);
    const p3 = pairing.ate(negG1(l),        vk.gamma);
    const p4 = pairing.ate(negG1(proof.c),  vk.delta);

    const product = Fp12.mul(Fp12.mul(p1, p2), Fp12.mul(p3, p4));
    return Fp12.isOne(product);
}

// ── Calldata helpers ──────────────────────────────────────────────────────────

/// Parse a 256-byte proof slice: A(64) ‖ B(128) ‖ C(64)
pub fn parseProof(bytes: *const [256]u8) Proof {
    return .{
        .a = G1.fromAffineBytes(bytes[0..64]),
        .b = G2.fromAffineBytes(bytes[64..192]),
        .c = G1.fromAffineBytes(bytes[192..256]),
    };
}

/// Parse the verifying key from a flat byte slice.
/// Layout: alpha(64) ‖ beta(128) ‖ gamma(128) ‖ delta(128) ‖ gamma_abc_len(4, BE) ‖ gamma_abc(64*n)
/// Returns false if slice is too short.
pub fn parseVk(bytes: []const u8, out: *VerifyingKey, gamma_abc_buf: []G1) bool {
    const FIXED = 64 + 128 + 128 + 128 + 4; // 452 bytes header
    if (bytes.len < FIXED) return false;

    out.alpha = G1.fromAffineBytes(bytes[0..64]);
    out.beta  = G2.fromAffineBytes(bytes[64..192]);
    out.gamma = G2.fromAffineBytes(bytes[192..320]);
    out.delta = G2.fromAffineBytes(bytes[320..448]);

    const n: u32 =
        (@as(u32, bytes[448]) << 24) |
        (@as(u32, bytes[449]) << 16) |
        (@as(u32, bytes[450]) <<  8) |
        (@as(u32, bytes[451])      );

    if (bytes.len < FIXED + 64 * n) return false;
    if (gamma_abc_buf.len < n) return false;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const off = FIXED + i * 64;
        gamma_abc_buf[i] = G1.fromAffineBytes(bytes[off..][0..64]);
    }
    out.gamma_abc = gamma_abc_buf[0..n];
    return true;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

const std = @import("std");

test "frFromBytes round-trip scalar 1" {
    var buf: [32]u8 = [_]u8{0} ** 32;
    buf[31] = 1;
    const limbs = frFromBytes(&buf);
    try std.testing.expectEqual(limbs[0], 1);
    try std.testing.expectEqual(limbs[1], 0);
    try std.testing.expectEqual(limbs[2], 0);
    try std.testing.expectEqual(limbs[3], 0);
}

test "frFromBytes max limb" {
    // bytes = 0x00…00 FF FF FF FF FF FF FF FF (last 8 bytes = 0xFF)
    var buf: [32]u8 = [_]u8{0} ** 32;
    buf[24] = 0xff; buf[25] = 0xff; buf[26] = 0xff; buf[27] = 0xff;
    buf[28] = 0xff; buf[29] = 0xff; buf[30] = 0xff; buf[31] = 0xff;
    const limbs = frFromBytes(&buf);
    try std.testing.expectEqual(limbs[0], 0xffffffffffffffff);
    try std.testing.expectEqual(limbs[1], 0);
}

test "negG1 infinity stays infinity" {
    const inf = G1.INFINITY;
    const neg_inf = negG1(inf);
    // Z=0 so still infinity; Y negated but irrelevant
    try std.testing.expect(neg_inf.isInfinity());
}

test "negG1 generator y-negated" {
    const g = G1.GENERATOR;
    const ng = negG1(g);
    // x unchanged
    try std.testing.expectEqualSlices(u64, &g.x, &ng.x);
    // y negated (−2 mod p in Montgomery)
    const expect_neg_y = fp.neg(g.y);
    try std.testing.expectEqualSlices(u64, &expect_neg_y, &ng.y);
}

test "verify trivial: generator pairing identity" {
    // e(G1, G2) · e(−G1, G2) == 1
    // Fake it as a VK with alpha=G1, beta=G2, gamma=G2, delta=G2
    // and a proof where A=G1, B=G2, C=INFINITY, L=INFINITY
    // Not a valid Groth16 instance but exercises the multiply path.
    var gamma_abc = [_]G1{G1.INFINITY};
    const vk = VerifyingKey{
        .alpha     = G1.GENERATOR,
        .beta      = G2.GENERATOR,
        .gamma     = G2.GENERATOR,
        .delta     = G2.GENERATOR,
        .gamma_abc = &gamma_abc,
    };
    const proof = Proof{
        .a = G1.GENERATOR,
        .b = G2.GENERATOR,
        .c = G1.INFINITY,
    };
    // pub_inputs = [] (empty, gamma_abc has length 1 = n_public+1 where n_public=0)
    // e(G1,G2)·e(−G1,G2)·e(0,G2)·e(0,G2) = e(G1,G2)·e(G1,G2)^{−1} = 1
    // But our negG1(alpha)=−G1, so p2 = e(−G1,G2) = e(G1,G2)^{−1}
    // p1=e(G1,G2), p2=e(−G1,G2), p3=e(0,G2)=1, p4=e(0,G2)=1  → product=1
    const result = verify(vk, proof, &[_][4]u64{});
    try std.testing.expect(result);
}

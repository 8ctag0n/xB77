//! BN254 optimal Ate pairing: ate(Q: G2, P: G1) → Fp12, pure WASM
//!
//! Algorithm:
//!   1. Miller loop over NAF of 6t+2 (65-bit window, D-twist, affine G2)
//!   2. Frobenius corrections Q1=ψ(Q), Q2=−ψ²(Q)
//!   3. Final exponentiation: easy part then hard part (Fuentes-Castañeda et al.)
//!
//! References:
//!   gnark-crypto/ecc/bn254/pairing.go
//!   go-ethereum/crypto/bn256/google/optimalAte.go
//!   EIP-197

const std  = @import("std");
const fp   = @import("fp.zig");
const Fp   = fp.Fp;
const fp2  = @import("fp2.zig");
const Fp2  = fp2.Fp2;
const fp6  = @import("fp6.zig");
const Fp6  = fp6.Fp6;
const fp12 = @import("fp12.zig");
const Fp12 = fp12.Fp12;
const g1   = @import("g1.zig");
const g2   = @import("g2.zig");

// ── NAF of 6t+2 = 29793968203157093288, 66 NAF digits, MSB first ─────────────
// naf_msb[0]=1 is implicit — T starts as Q.  Loop processes naf_msb[1..65].
// 6t+2 = 2^65 + sum_{k=1}^{65} LOOP[k]*2^{65-k}  (verified by Python)
const LOOP = [66]i8{
     0, 0,-1, 0, 1, 0, 0, 0,-1, 0,-1, 0, 0, 0,-1, 0, 1, 0,-1, 0,
     0,-1, 0, 0, 0, 0, 0, 1, 0, 0,-1, 0, 1, 0, 0,-1, 0, 0, 0, 0,
    -1, 0, 1, 0, 0, 0,-1, 0,-1, 0, 0, 1, 0, 0, 0,-1, 0, 0,-1, 0,
     1, 0, 1, 0, 0, 0,
};

// ── BN254 seed for final exponentiation ──────────────────────────────────────
// t = 4965661367192848881  (positive BN seed)
const BN_SEED: u64 = 0x44E992B44A6909F1;

// ── G2 Frobenius twist constants ──────────────────────────────────────────────
// PSI2  = ξ^{(p−1)/3}  = GAMMA_1_2  (from fp6.zig)
// PSI3  = ξ^{(p−1)/2}  = DELTA_3    (from fp12.zig)
// PSI22 = ξ^{(p²−1)/3} = GAMMA_2_1  (real, = DELTA_4)
// PSI32 = ξ^{(p²−1)/2} = DELTA_6    (real)
const PSI2: Fp2 = .{
    .c0 = .{ 0xb5773b104563ab30, 0x347f91c8a9aa6454, 0x7a007127242e0991, 0x1956bcd8118214ec },
    .c1 = .{ 0x6e849f1ea0aa4757, 0xaa1c7b6d89f89141, 0xb6e713cdfae0ca3a, 0x26694fbb4e82ebc3 },
};
const PSI3: Fp2 = Fp12.DELTA_3;
const PSI22: Fp2 = .{
    .c0 = .{ 0x3350c88e13e80b9c, 0x7dce557cdb5e56b9, 0x6001b4b8b615564a, 0x2682e617020217e0 },
    .c1 = .{ 0, 0, 0, 0 },
};
const PSI32: Fp2 = Fp12.DELTA_6;

// ── Affine G2 point (used internally during Miller loop) ─────────────────────
const G2Aff = struct {
    x: Fp2,
    y: Fp2,
};

// ── Affine G1 point ───────────────────────────────────────────────────────────
const G1Aff = struct {
    x: Fp,
    y: Fp,
};

// ── G2 Frobenius maps (affine) ────────────────────────────────────────────────

/// ψ(Q): φ_p on the twist — x' = conj(x)·PSI2, y' = conj(y)·PSI3
fn psi(q: G2Aff) G2Aff {
    return .{
        .x = Fp2.mul(Fp2.conj(q.x), PSI2),
        .y = Fp2.mul(Fp2.conj(q.y), PSI3),
    };
}

/// ψ²(Q): φ_{p²} — x' = x·PSI22, y' = y·PSI32  (no conjugate, PSI22/PSI32 real)
fn psi2(q: G2Aff) G2Aff {
    return .{
        .x = Fp2.mul(q.x, PSI22),
        .y = Fp2.mul(q.y, PSI32),
    };
}

/// Negate affine G2 point: (x, y) → (x, −y)
fn g2Neg(q: G2Aff) G2Aff {
    return .{ .x = q.x, .y = Fp2.neg(q.y) };
}

// ── Affine line functions (D-twist, BN254) ────────────────────────────────────
//
// The sparse Fp12 line element for BN254 D-twist:
//   c0 = Fp6{ Fp2{yP, 0}, 0, 0 }        — the G1 y coord embedded
//   c1 = Fp6{ −λ·xP (as Fp2), λ·xT−yT, 0 }
//
// Using full Fp12 mul for correctness (sparse optimization deferred to v2).

/// Double T affine, return line evaluated at P.
/// T is updated in-place to 2T.
fn lineDouble(t: *G2Aff, p: G1Aff) Fp12 {
    // λ = 3·xT² / (2·yT)
    const xT_sq  = Fp2.sqr(t.x);
    const three_xT_sq = Fp2.add(Fp2.add(xT_sq, xT_sq), xT_sq);
    const two_yT = Fp2.add(t.y, t.y);
    const lambda = Fp2.mul(three_xT_sq, Fp2.inv(two_yT));

    // New T: xNew = λ² − 2·xT, yNew = λ·(xT − xNew) − yT
    const lambda_sq = Fp2.sqr(lambda);
    const xNew = Fp2.sub(lambda_sq, Fp2.add(t.x, t.x));
    const yNew = Fp2.sub(Fp2.mul(lambda, Fp2.sub(t.x, xNew)), t.y);
    t.* = .{ .x = xNew, .y = yNew };

    // Sparse Fp12 line: c0.c0 = yP, c1.c0 = −λ·xP, c1.c1 = λ·xT_old − yT_old
    // Note: xT_old captured before update via lambda formula; λ·xT−yT = λ·xOld−yOld
    const lam_xT_minus_yT = Fp2.sub(Fp2.mul(lambda, xNew), yNew); // equivalent via identity
    // Actually: λ·xT_old − yT_old — we use the original xT before the update.
    // Recover as: (λ² − xNew)/2·λ ... simpler: precompute before updating T.
    // Re-derive: lam_xOld_yOld = λ*xNew + yNew  [since yNew = λ(xOld-xNew)-yOld → λ*xOld = yNew + λ*xNew + yOld]
    // Easier: capture before overwrite:
    _ = lam_xT_minus_yT; // not used; see below
    // (We already destructured T above, so xOld/yOld are gone. Recompute:)
    // λ·xOld − yOld = yNew + 2·yOld?  No. Use: λ*(xOld-xNew) = yNew + yOld, so λ*xOld = yNew+yOld+λ*xNew
    // c1.c1 = λ*xOld − yOld = yNew + yOld + λ*xNew − yOld = yNew + λ*xNew
    const c1c1 = Fp2.add(yNew, Fp2.mul(lambda, xNew));

    return .{
        .c0 = .{
            .c0 = .{ .c0 = p.y, .c1 = fp.ZERO },
            .c1 = Fp2.ZERO,
            .c2 = Fp2.ZERO,
        },
        .c1 = .{
            .c0 = Fp2.mulByFp(Fp2.neg(lambda), p.x),
            .c1 = c1c1,
            .c2 = Fp2.ZERO,
        },
    };
}

/// Add Q to T affine, return line evaluated at P.
/// T is updated in-place to T+Q.
fn lineAdd(t: *G2Aff, q: G2Aff, p: G1Aff) Fp12 {
    // λ = (yQ − yT) / (xQ − xT)
    const lambda = Fp2.mul(Fp2.sub(q.y, t.y), Fp2.inv(Fp2.sub(q.x, t.x)));

    const xOld = t.x;
    const xNew = Fp2.sub(Fp2.sub(Fp2.sqr(lambda), xOld), q.x);
    const yNew = Fp2.sub(Fp2.mul(lambda, Fp2.sub(xOld, xNew)), t.y);
    t.* = .{ .x = xNew, .y = yNew };

    // c1.c1 = λ·xOld − yOld = yNew + λ·xNew  (same identity as in lineDouble)
    const c1c1 = Fp2.add(yNew, Fp2.mul(lambda, xNew));

    return .{
        .c0 = .{
            .c0 = .{ .c0 = p.y, .c1 = fp.ZERO },
            .c1 = Fp2.ZERO,
            .c2 = Fp2.ZERO,
        },
        .c1 = .{
            .c0 = Fp2.mulByFp(Fp2.neg(lambda), p.x),
            .c1 = c1c1,
            .c2 = Fp2.ZERO,
        },
    };
}

// ── Miller loop ───────────────────────────────────────────────────────────────

fn millerLoop(q_jac: g2.G2, p_jac: g1.G1) Fp12 {
    // Convert to affine
    const p_aff = toAffineG1(p_jac);
    const q_aff = toAffineG2(q_jac);

    var tt = q_aff;        // accumulator T in G2 affine
    var f  = Fp12.ONE;

    // NAF loop — start at i=1 (i=0 is implicit T=Q already set)
    var idx: usize = 1;
    while (idx < 66) : (idx += 1) {
        f = Fp12.sqr(f);
        const ld = lineDouble(&tt, p_aff);
        f = Fp12.mul(f, ld);

        if (LOOP[idx] == 1) {
            const la = lineAdd(&tt, q_aff, p_aff);
            f = Fp12.mul(f, la);
        } else if (LOOP[idx] == -1) {
            const la = lineAdd(&tt, g2Neg(q_aff), p_aff);
            f = Fp12.mul(f, la);
        }
    }

    // Frobenius corrections
    const q1   = psi(q_aff);
    const q2   = psi2(g2Neg(q_aff));
    const la1  = lineAdd(&tt, q1, p_aff);
    f = Fp12.mul(f, la1);
    const la2  = lineAdd(&tt, q2, p_aff);
    f = Fp12.mul(f, la2);

    return f;
}

// ── Final exponentiation ──────────────────────────────────────────────────────

/// Exponentiation by the BN seed t (square-and-multiply, ~63 iterations)
fn expBySeed(ff: Fp12) Fp12 {
    var result = Fp12.ONE;
    var cur    = ff;
    var exp    = BN_SEED;
    while (exp > 0) : (exp >>= 1) {
        if (exp & 1 == 1) result = Fp12.mul(result, cur);
        cur = Fp12.sqr(cur);
    }
    return result;
}

/// Easy part: f → f^{(p^6−1)(p^2+1)}
///   step1: f ← conj(f) · f^{−1}     (= f^{p^6−1} in cyclotomic subgroup)
///   step2: f ← frob2(f) · f          (= f^{p^2+1})
fn finalExpEasy(ff: Fp12) Fp12 {
    const step1 = Fp12.mul(Fp12.conj(ff), Fp12.inv(ff));
    return Fp12.mul(Fp12.frob2(step1), step1);
}

/// Hard part: f^{(p^4−p^2+1)/r}
/// Algorithm 6 from Duquesne & Ghammam https://eprint.iacr.org/2015/192.pdf
/// via gnark-crypto ecc/bn254/pairing.go
fn finalExpHard(ff: Fp12) Fp12 {
    var t0 = Fp12.conj(expBySeed(ff));       // f^{-t}
    t0 = Fp12.sqr(t0);                        // f^{-2t}
    var t1 = Fp12.mul(t0, Fp12.sqr(t0));     // f^{-6t}
    const t2 = Fp12.conj(expBySeed(t1));     // f^{6t²}
    t1 = Fp12.mul(t2, Fp12.conj(t1));        // f^{6t²+6t}  (conj uses old t1)
    var t3 = Fp12.sqr(t2);                   // f^{12t²}
    var t4 = expBySeed(t3);                  // f^{12t³}
    t4 = Fp12.mul(t1, t4);                   // f^{12t³+6t²+6t}
    t3 = Fp12.mul(t0, t4);                   // f^{12t³+6t²+4t}
    t0 = Fp12.mul(ff, Fp12.mul(t2, t4));     // f^{12t³+12t²+6t+1}
    t0 = Fp12.mul(Fp12.frob1(t3), t0);
    t0 = Fp12.mul(Fp12.frob2(t4), t0);
    const t2b = Fp12.frob3(Fp12.mul(Fp12.conj(ff), t3));
    return Fp12.mul(t2b, t0);
}

fn finalExp(ff: Fp12) Fp12 {
    return finalExpHard(finalExpEasy(ff));
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Compute the optimal Ate pairing e(P, Q) ∈ Fp12.
/// Returns Fp12.ONE if either argument is the point at infinity.
pub fn ate(p_jac: g1.G1, q_jac: g2.G2) Fp12 {
    if (p_jac.isInfinity() or q_jac.isInfinity()) return Fp12.ONE;
    const f = millerLoop(q_jac, p_jac);
    return finalExp(f);
}

// ── Helpers: Jacobian → affine ────────────────────────────────────────────────

fn toAffineG1(pt: g1.G1) G1Aff {
    const z_inv  = fp.inv(pt.z);
    const z_inv2 = fp.mul(z_inv, z_inv);
    const z_inv3 = fp.mul(z_inv2, z_inv);
    return .{
        .x = fp.mul(pt.x, z_inv2),
        .y = fp.mul(pt.y, z_inv3),
    };
}

fn toAffineG2(pt: g2.G2) G2Aff {
    const z_inv  = Fp2.inv(pt.z);
    const z_inv2 = Fp2.mul(z_inv, z_inv);
    const z_inv3 = Fp2.mul(z_inv2, z_inv);
    return .{
        .x = Fp2.mul(pt.x, z_inv2),
        .y = Fp2.mul(pt.y, z_inv3),
    };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "pairing: e(G1, G2) * e(-G1, G2) == 1  (bilinearity)" {
    const p  = g1.G1.GENERATOR;
    const q  = g2.G2.GENERATOR;
    const np = g1.G1{ .x = p.x, .y = fp.neg(p.y), .z = p.z };  // −G1

    const e1 = ate(p, q);
    const e2 = ate(np, q);
    const product = Fp12.mul(e1, e2);

    try std.testing.expect(Fp12.isOne(product));
}

test "pairing: frob1^6 == conj (verifies DELTA_1 is correct)" {
    // φ_{p^6} on Fp12 must equal the conjugation map (c0,c1) → (c0,−c1).
    const fp_ = @import("fp.zig");
    const a: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp_.fromU64(3), .c1 = fp_.fromU64(5) },
            .c1 = .{ .c0 = fp_.fromU64(7), .c1 = fp_.fromU64(11) },
            .c2 = fp2.Fp2.ZERO,
        },
        .c1 = .{
            .c0 = .{ .c0 = fp_.fromU64(2), .c1 = fp_.fromU64(13) },
            .c1 = fp2.Fp2.ZERO,
            .c2 = .{ .c0 = fp_.fromU64(17), .c1 = fp_.fromU64(19) },
        },
    };
    const frob6 = Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(a))))));
    const conj_a = Fp12.conj(a);
    try std.testing.expect(Fp12.eql(frob6, conj_a));
}

test "pairing: easy part lands in cyclotomic subgroup: f*frob6(f) == 1" {
    // Cyclotomic condition: g^{p^6+1} = g * frob1^6(g) = 1.
    const p = g1.G1.GENERATOR;
    const q = g2.G2.GENERATOR;
    const f_miller = millerLoop(q, p);
    const f_easy   = finalExpEasy(f_miller);
    const frob6    = Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(Fp12.frob1(f_easy))))));
    const product  = Fp12.mul(f_easy, frob6);
    try std.testing.expect(Fp12.isOne(product));
}

test "pairing: e(G1, G2) != 1  (non-trivial)" {
    const p = g1.G1.GENERATOR;
    const q = g2.G2.GENERATOR;
    const e = ate(p, q);
    try std.testing.expect(!Fp12.isOne(e));
}

test "pairing: e(2*G1, G2) == e(G1, G2)^2  (bilinearity in G1)" {
    const p  = g1.G1.GENERATOR;
    const q  = g2.G2.GENERATOR;
    const p2 = p.dbl();

    const lhs = ate(p2, q);
    const rhs = Fp12.sqr(ate(p, q));

    try std.testing.expect(Fp12.eql(lhs, rhs));
}

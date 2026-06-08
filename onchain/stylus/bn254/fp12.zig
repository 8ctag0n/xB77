//! BN254 Fp12 — degree-12 extension Fp6[w]/(w² − v), pure WASM
//!
//! Elements: c0 + c1·w  (ci ∈ Fp6)
//! Frobenius constants verified against gnark-crypto bn254/internal/fptower/e12.go

const std = @import("std");
const fp6 = @import("fp6.zig");
const Fp6 = fp6.Fp6;
const fp2 = @import("fp2.zig");
const Fp2 = fp2.Fp2;

pub const Fp12 = struct {
    c0: Fp6,
    c1: Fp6,

    pub const ZERO: Fp12 = .{ .c0 = Fp6.ZERO, .c1 = Fp6.ZERO };
    pub const ONE:  Fp12 = .{ .c0 = Fp6.ONE,  .c1 = Fp6.ZERO };

    // ── Frobenius coefficients DELTA_k = ξ^{(p^k−1)/6} in Fp2 ───────────────
    // Used as: Fp12.frob_k(c0+c1·w) = (Fp6.frob_k(c0), Fp6.frob_k(c1)*DELTA_k·w)
    // The Fp6 coeff c1 is scaled by DELTA_k (embedded as Fp6 scalar via mulByFp2).
    // ξ^{(p-1)/6} — Frobenius twist factor for w: w^p = w·ξ^{(p-1)/6}
    // = Fp6.GAMMA_1_1; computed from ξ^e with e = (p-1)/6
    pub const DELTA_1: Fp2 = .{
        .c0 = .{ 0xaf9ba69633144907, 0xca6b1d7387afb78a, 0x11bded5ef08a2087, 0x02f34d751a1f3a7c },
        .c1 = .{ 0xa222ae234c492d72, 0xd00f02a4565de15b, 0xdc2ff3a253dfc926, 0x10a75716b3899551 },
    };
    pub const DELTA_2: Fp2 = .{
        .c0 = .{ 0xca8d800500fa1bf2, 0xe4da1548c2a72a79, 0x566c08637b6af58f, 0x12fffffd8ac1bca3 },
        .c1 = .{ 0, 0, 0, 0 },
    };
    // ξ^{(p-1)/2} = GAMMA_1_1 * GAMMA_1_2 — used as PSI3 in pairing.zig
    pub const DELTA_3: Fp2 = .{
        .c0 = .{ 0xe4bbdd0c2936b629, 0xbb30f162e133bacb, 0x31a9d1b6f9645366, 0x253570bea500f8dd },
        .c1 = .{ 0xa1d77ce45ffe77c7, 0x07affd117826d1db, 0x6d16bd27bb7edc6b, 0x2c87200285defecc },
    };
    // ξ^{(p²-1)/3} = norm(GAMMA_1_2) (real)
    pub const DELTA_4: Fp2 = .{
        .c0 = .{ 0x3350c88e13e80b9c, 0x7dce557cdb5e56b9, 0x6001b4b8b615564a, 0x2682e617020217e0 },
        .c1 = .{ 0, 0, 0, 0 },
    };
    pub const DELTA_5: Fp2 = .{
        .c0 = .{ 0x86b76f821b329076, 0x3d62f9068aeea3ea, 0xb6d1f94f4aff4dfc, 0x28b26400c38cb55e },
        .c1 = .{ 0x0fbc9cd47752ebc7, 0xab88e3b37c9e41e3, 0xd52ce32b85ef4ab7, 0x0dc0aaa16cee9c8f },
    };
    pub const DELTA_6: Fp2 = .{
        .c0 = .{ 0x68c3488912edefaa, 0x8d087f6872aabf4f, 0x51e1a24709081231, 0x2259d6b14729c0fa },
        .c1 = .{ 0, 0, 0, 0 },
    };

    // ── Arithmetic ────────────────────────────────────────────────────────────

    pub fn add(a: Fp12, b: Fp12) Fp12 {
        return .{ .c0 = Fp6.add(a.c0, b.c0), .c1 = Fp6.add(a.c1, b.c1) };
    }

    pub fn sub(a: Fp12, b: Fp12) Fp12 {
        return .{ .c0 = Fp6.sub(a.c0, b.c0), .c1 = Fp6.sub(a.c1, b.c1) };
    }

    pub fn neg(a: Fp12) Fp12 {
        return .{ .c0 = Fp6.neg(a.c0), .c1 = Fp6.neg(a.c1) };
    }

    /// Karatsuba: (a0+a1·w)(b0+b1·w) using w² = v
    /// t0 = a0·b0,  t1 = a1·b1
    /// c0 = t0 + Fp6.mulByV(t1)
    /// c1 = (a0+a1)(b0+b1) − t0 − t1
    pub fn mul(a: Fp12, b: Fp12) Fp12 {
        const t0 = Fp6.mul(a.c0, b.c0);
        const t1 = Fp6.mul(a.c1, b.c1);
        return .{
            .c0 = Fp6.add(t0, Fp6.mulByV(t1)),
            .c1 = Fp6.sub(Fp6.mul(Fp6.add(a.c0, a.c1), Fp6.add(b.c0, b.c1)), Fp6.add(t0, t1)),
        };
    }

    /// Squaring: a² = (a0+a1·w)²
    /// t0 = a0²,  t1 = a1²
    /// c0 = t0 + Fp6.mulByV(t1)
    /// c1 = (a0+a1)² − t0 − t1  (= 2·a0·a1)
    pub fn sqr(a: Fp12) Fp12 {
        const t0 = Fp6.sqr(a.c0);
        const t1 = Fp6.sqr(a.c1);
        return .{
            .c0 = Fp6.add(t0, Fp6.mulByV(t1)),
            .c1 = Fp6.sub(Fp6.sqr(Fp6.add(a.c0, a.c1)), Fp6.add(t0, t1)),
        };
    }

    /// Inversion: (c0+c1·w)^{−1} using norm in Fp12/Fp6
    /// factor = c0² − v·c1²
    pub fn inv(a: Fp12) Fp12 {
        const factor = Fp6.sub(Fp6.sqr(a.c0), Fp6.mulByV(Fp6.sqr(a.c1)));
        const factor_inv = Fp6.inv(factor);
        return .{
            .c0 = Fp6.mul(a.c0, factor_inv),
            .c1 = Fp6.neg(Fp6.mul(a.c1, factor_inv)),
        };
    }

    /// Conjugate = Frobenius^6: (c0, c1) → (c0, −c1)
    /// Only valid in the cyclotomic subgroup (after easy part of final exp).
    pub fn conj(a: Fp12) Fp12 {
        return .{ .c0 = a.c0, .c1 = Fp6.neg(a.c1) };
    }

    // ── Frobenius endomorphisms ───────────────────────────────────────────────

    /// φ_p: frob1(c0+c1·w) = (Fp6.frob1(c0), Fp6.frob1(c1)·DELTA_1·w)
    pub fn frob1(a: Fp12) Fp12 {
        const f0 = Fp6.frob1(a.c0);
        const f1 = Fp6.mulByFp2(Fp6.frob1(a.c1), DELTA_1);
        return .{ .c0 = f0, .c1 = f1 };
    }

    /// φ_{p²} = frob1 ∘ frob1
    pub fn frob2(a: Fp12) Fp12 {
        return frob1(frob1(a));
    }

    /// φ_{p³} = frob1 ∘ frob1 ∘ frob1
    pub fn frob3(a: Fp12) Fp12 {
        return frob1(frob1(frob1(a)));
    }

    // ── Predicates ────────────────────────────────────────────────────────────

    pub fn isOne(a: Fp12) bool {
        return Fp6.eql(a.c0, Fp6.ONE) and Fp6.isZero(a.c1);
    }

    pub fn eql(a: Fp12, b: Fp12) bool {
        return Fp6.eql(a.c0, b.c0) and Fp6.eql(a.c1, b.c1);
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "Fp12 ONE·ONE = ONE" {
    try std.testing.expect(Fp12.eql(Fp12.mul(Fp12.ONE, Fp12.ONE), Fp12.ONE));
}

test "Fp12 sqr == mul(a,a)" {
    const fp = @import("fp.zig");
    const a: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp.fromU64(3),  .c1 = fp.fromU64(5)  },
            .c1 = .{ .c0 = fp.fromU64(7),  .c1 = fp.fromU64(11) },
            .c2 = Fp2.ZERO,
        },
        .c1 = .{
            .c0 = .{ .c0 = fp.fromU64(2),  .c1 = fp.fromU64(13) },
            .c1 = Fp2.ZERO,
            .c2 = .{ .c0 = fp.fromU64(17), .c1 = fp.fromU64(19) },
        },
    };
    try std.testing.expect(Fp12.eql(Fp12.sqr(a), Fp12.mul(a, a)));
}

test "Fp12 mul commutativity" {
    const fp = @import("fp.zig");
    const a: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp.fromU64(3),  .c1 = fp.fromU64(5)  },
            .c1 = Fp2.ZERO,
            .c2 = .{ .c0 = fp.fromU64(7),  .c1 = fp.fromU64(11) },
        },
        .c1 = .{
            .c0 = Fp2.ZERO,
            .c1 = .{ .c0 = fp.fromU64(2),  .c1 = fp.fromU64(13) },
            .c2 = Fp2.ZERO,
        },
    };
    const b: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp.fromU64(23), .c1 = fp.fromU64(29) },
            .c1 = .{ .c0 = fp.fromU64(31), .c1 = fp.ZERO },
            .c2 = Fp2.ZERO,
        },
        .c1 = .{
            .c0 = .{ .c0 = fp.fromU64(37), .c1 = fp.fromU64(41) },
            .c1 = Fp2.ZERO,
            .c2 = .{ .c0 = fp.fromU64(43), .c1 = fp.ZERO },
        },
    };
    try std.testing.expect(Fp12.eql(Fp12.mul(a, b), Fp12.mul(b, a)));
}

test "Fp12 inv roundtrip" {
    const fp = @import("fp.zig");
    const a: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp.fromU64(3),  .c1 = fp.fromU64(5)  },
            .c1 = .{ .c0 = fp.fromU64(7),  .c1 = fp.fromU64(11) },
            .c2 = Fp2.ZERO,
        },
        .c1 = .{
            .c0 = .{ .c0 = fp.fromU64(2),  .c1 = fp.fromU64(13) },
            .c1 = Fp2.ZERO,
            .c2 = .{ .c0 = fp.fromU64(17), .c1 = fp.fromU64(19) },
        },
    };
    try std.testing.expect(Fp12.isOne(Fp12.mul(a, Fp12.inv(a))));
}

test "Fp12 conj: a·conj(a) is real (c1 = 0)" {
    const fp = @import("fp.zig");
    const a: Fp12 = .{
        .c0 = .{
            .c0 = .{ .c0 = fp.fromU64(5),  .c1 = fp.fromU64(7)  },
            .c1 = Fp2.ZERO,
            .c2 = .{ .c0 = fp.fromU64(11), .c1 = fp.ZERO },
        },
        .c1 = .{
            .c0 = .{ .c0 = fp.fromU64(3),  .c1 = fp.fromU64(2)  },
            .c1 = Fp2.ZERO,
            .c2 = Fp2.ZERO,
        },
    };
    const r = Fp12.mul(a, Fp12.conj(a));
    try std.testing.expect(Fp6.isZero(r.c1));
}

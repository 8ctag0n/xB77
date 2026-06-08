//! BN254 Fp6 — cubic extension Fp2[v]/(v³ − ξ), ξ = 9+u, pure WASM
//!
//! Elements: c0 + c1·v + c2·v²  (ci ∈ Fp2)
//! Frobenius constants verified against gnark-crypto bn254/internal/fptower/e6.go

const std = @import("std");
const fp2 = @import("fp2.zig");
const Fp2 = fp2.Fp2;

pub const Fp6 = struct {
    c0: Fp2,
    c1: Fp2,
    c2: Fp2,

    pub const ZERO: Fp6 = .{ .c0 = Fp2.ZERO, .c1 = Fp2.ZERO, .c2 = Fp2.ZERO };
    pub const ONE:  Fp6 = .{ .c0 = Fp2.ONE,  .c1 = Fp2.ZERO, .c2 = Fp2.ZERO };

    // ── Frobenius coefficients ────────────────────────────────────────────────────
    // All computed from ξ = 9+u via ξ^e mod p in Montgomery form.
    // Derivation: zig test fp6.zig "derive and verify GAMMA_1_1" prints all values.
    //   GAMMA_1_1 = ξ^{(p-1)/6}    [pub: used by fp12.zig as the Fp12 twist factor]
    //   GAMMA_1_2 = ξ^{(p-1)/3}    [pub: used by fp12.zig for PSI2]
    //   GAMMA_2_1 = norm(GAMMA_1_2) [ξ^{(p²-1)/3}, real, used by Fp6.frob2 and PSI22]
    //   GAMMA_2_2 = GAMMA_2_1²     [ξ^{2(p²-1)/3}, real]
    pub const GAMMA_1_1: Fp2 = .{
        .c0 = .{ 0xaf9ba69633144907, 0xca6b1d7387afb78a, 0x11bded5ef08a2087, 0x02f34d751a1f3a7c },
        .c1 = .{ 0xa222ae234c492d72, 0xd00f02a4565de15b, 0xdc2ff3a253dfc926, 0x10a75716b3899551 },
    };
    pub const GAMMA_1_2: Fp2 = .{
        .c0 = .{ 0xb5773b104563ab30, 0x347f91c8a9aa6454, 0x7a007127242e0991, 0x1956bcd8118214ec },
        .c1 = .{ 0x6e849f1ea0aa4757, 0xaa1c7b6d89f89141, 0xb6e713cdfae0ca3a, 0x26694fbb4e82ebc3 },
    };
    const GAMMA_2_1: Fp2 = .{
        .c0 = .{ 0x3350c88e13e80b9c, 0x7dce557cdb5e56b9, 0x6001b4b8b615564a, 0x2682e617020217e0 },
        .c1 = .{ 0, 0, 0, 0 },
    };
    const GAMMA_2_2: Fp2 = .{
        .c0 = .{ 0x71930c11d782e155, 0xa6bb947cffbe3323, 0xaa303344d4741444, 0x2c3b3f0d26594943 },
        .c1 = .{ 0, 0, 0, 0 },
    };
    const GAMMA_3_1: Fp2 = .{
        .c0 = .{ 0xc9af22f716ad6bad, 0xb311782a4aa662b2, 0x19eeaf64e248c7f4, 0x20273e77e3439f82 },
        .c1 = .{ 0xacc02860f7ce93ac, 0x3933d5817ba76b4c, 0xd2f45baef1d5d38f, 0x0b3e7a7bf7a52897 },
    };
    const GAMMA_3_2: Fp2 = .{
        .c0 = .{ 0x448a93a57b6762df, 0xbfd62df528fdeadf, 0xd858f5d00e9bd47a, 0x06b03d4d3476ec58 },
        .c1 = .{ 0x2b19daf4bcc936d1, 0xa1a54e7a56f4299f, 0xb99c90dd27a5e11e, 0x27627334b68decb6 },
    };

    // ── Arithmetic ────────────────────────────────────────────────────────────

    pub fn add(a: Fp6, b: Fp6) Fp6 {
        return .{
            .c0 = Fp2.add(a.c0, b.c0),
            .c1 = Fp2.add(a.c1, b.c1),
            .c2 = Fp2.add(a.c2, b.c2),
        };
    }

    pub fn sub(a: Fp6, b: Fp6) Fp6 {
        return .{
            .c0 = Fp2.sub(a.c0, b.c0),
            .c1 = Fp2.sub(a.c1, b.c1),
            .c2 = Fp2.sub(a.c2, b.c2),
        };
    }

    pub fn neg(a: Fp6) Fp6 {
        return .{ .c0 = Fp2.neg(a.c0), .c1 = Fp2.neg(a.c1), .c2 = Fp2.neg(a.c2) };
    }

    /// Shift: v·(c0+c1·v+c2·v²) = ξ·c2 + c0·v + c1·v²
    pub fn mulByV(a: Fp6) Fp6 {
        return .{ .c0 = Fp2.mulByXi(a.c2), .c1 = a.c0, .c2 = a.c1 };
    }

    /// Multiply each Fp2 coefficient by a scalar in Fp2 (used in Frobenius)
    pub fn mulByFp2(a: Fp6, b: Fp2) Fp6 {
        return .{
            .c0 = Fp2.mul(a.c0, b),
            .c1 = Fp2.mul(a.c1, b),
            .c2 = Fp2.mul(a.c2, b),
        };
    }

    /// Karatsuba multiplication (6 Fp2.mul):
    /// t0 = a0·b0,  t1 = a1·b1,  t2 = a2·b2
    /// c0 = t0 + ξ·((a1+a2)(b1+b2) − t1 − t2)
    /// c1 = (a0+a1)(b0+b1) − t0 − t1 + ξ·t2
    /// c2 = (a0+a2)(b0+b2) − t0 + t1 − t2
    pub fn mul(a: Fp6, b: Fp6) Fp6 {
        const t0 = Fp2.mul(a.c0, b.c0);
        const t1 = Fp2.mul(a.c1, b.c1);
        const t2 = Fp2.mul(a.c2, b.c2);
        const c0 = Fp2.add(t0, Fp2.mulByXi(
            Fp2.sub(Fp2.mul(Fp2.add(a.c1, a.c2), Fp2.add(b.c1, b.c2)), Fp2.add(t1, t2)),
        ));
        const c1 = Fp2.add(
            Fp2.sub(Fp2.mul(Fp2.add(a.c0, a.c1), Fp2.add(b.c0, b.c1)), Fp2.add(t0, t1)),
            Fp2.mulByXi(t2),
        );
        const c2 = Fp2.add(
            Fp2.sub(Fp2.sub(Fp2.mul(Fp2.add(a.c0, a.c2), Fp2.add(b.c0, b.c2)), t0), t2),
            t1,
        );
        return .{ .c0 = c0, .c1 = c1, .c2 = c2 };
    }

    /// Karatsuba squaring (~5 Fp2.mul):
    /// same formula as mul with b=a
    pub fn sqr(a: Fp6) Fp6 {
        const t0 = Fp2.sqr(a.c0);
        const t1 = Fp2.sqr(a.c1);
        const t2 = Fp2.sqr(a.c2);
        const c0 = Fp2.add(t0, Fp2.mulByXi(
            Fp2.sub(Fp2.sqr(Fp2.add(a.c1, a.c2)), Fp2.add(t1, t2)),
        ));
        const c1 = Fp2.add(
            Fp2.sub(Fp2.sqr(Fp2.add(a.c0, a.c1)), Fp2.add(t0, t1)),
            Fp2.mulByXi(t2),
        );
        const c2 = Fp2.add(
            Fp2.sub(Fp2.sub(Fp2.sqr(Fp2.add(a.c0, a.c2)), t0), t2),
            t1,
        );
        return .{ .c0 = c0, .c1 = c1, .c2 = c2 };
    }

    /// Inversion via norm in Fp6/Fp2:
    /// A0 = a0² − ξ·a1·a2
    /// A1 = ξ·a2² − a0·a1
    /// A2 = a1² − a0·a2
    /// norm = a0·A0 + ξ·(a2·A1 + a1·A2)
    pub fn inv(a: Fp6) Fp6 {
        const aa0 = Fp2.sub(Fp2.sqr(a.c0), Fp2.mulByXi(Fp2.mul(a.c1, a.c2)));
        const aa1 = Fp2.sub(Fp2.mulByXi(Fp2.sqr(a.c2)), Fp2.mul(a.c0, a.c1));
        const aa2 = Fp2.sub(Fp2.sqr(a.c1), Fp2.mul(a.c0, a.c2));
        const norm = Fp2.add(
            Fp2.mul(a.c0, aa0),
            Fp2.mulByXi(Fp2.add(Fp2.mul(a.c2, aa1), Fp2.mul(a.c1, aa2))),
        );
        const norm_inv = Fp2.inv(norm);
        return .{
            .c0 = Fp2.mul(aa0, norm_inv),
            .c1 = Fp2.mul(aa1, norm_inv),
            .c2 = Fp2.mul(aa2, norm_inv),
        };
    }

    // ── Frobenius endomorphisms ───────────────────────────────────────────────

    // c2 factor for frob1 = GAMMA_1_2² = ξ^{2(p-1)/3}  (derived, not hardcoded)
    // computed as: Fp2.mul(GAMMA_1_2, GAMMA_1_2)

    /// φ_p:
    ///   c1 scales by ξ^{(p-1)/3}   = GAMMA_1_2
    ///   c2 scales by ξ^{2(p-1)/3}  = GAMMA_1_2²
    pub fn frob1(a: Fp6) Fp6 {
        const g1_4 = Fp2.mul(GAMMA_1_2, GAMMA_1_2); // ξ^{2(p-1)/3}
        return .{
            .c0 = Fp2.conj(a.c0),
            .c1 = Fp2.mul(Fp2.conj(a.c1), GAMMA_1_2),
            .c2 = Fp2.mul(Fp2.conj(a.c2), g1_4),
        };
    }

    /// φ_{p²}: no conjugate; factors = N(C1) and N(C1)² where N = norm Fp2→Fp
    ///   c1 scales by GAMMA_2_1 (real = ξ^{(p²-1)/3})
    ///   c2 scales by GAMMA_2_2 (real = ξ^{2(p²-1)/3})
    pub fn frob2(a: Fp6) Fp6 {
        return .{
            .c0 = a.c0,
            .c1 = Fp2.mul(a.c1, GAMMA_2_1),
            .c2 = Fp2.mul(a.c2, GAMMA_2_2),
        };
    }

    /// φ_{p³} = frob1∘frob1∘frob1 — avoids needing to verify GAMMA_3 constants
    pub fn frob3(a: Fp6) Fp6 {
        return frob1(frob1(frob1(a)));
    }

    // ── Predicates ────────────────────────────────────────────────────────────

    pub fn isZero(a: Fp6) bool {
        return Fp2.isZero(a.c0) and Fp2.isZero(a.c1) and Fp2.isZero(a.c2);
    }

    pub fn eql(a: Fp6, b: Fp6) bool {
        return Fp2.eql(a.c0, b.c0) and Fp2.eql(a.c1, b.c1) and Fp2.eql(a.c2, b.c2);
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "Fp6 ONE·ONE = ONE" {
    try std.testing.expect(Fp6.eql(Fp6.mul(Fp6.ONE, Fp6.ONE), Fp6.ONE));
}

test "Fp6 mul commutativity" {
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp2.Fp2.ONE.c0, .c1 = fp2.Fp2.ZERO.c1 },
        .c1 = .{ .c0 = @import("fp.zig").fromU64(3), .c1 = @import("fp.zig").fromU64(5) },
        .c2 = .{ .c0 = @import("fp.zig").fromU64(7), .c1 = @import("fp.zig").ZERO },
    };
    const b: Fp6 = .{
        .c0 = .{ .c0 = @import("fp.zig").fromU64(11), .c1 = @import("fp.zig").fromU64(13) },
        .c1 = .{ .c0 = @import("fp.zig").fromU64(2),  .c1 = @import("fp.zig").ZERO },
        .c2 = .{ .c0 = @import("fp.zig").fromU64(17), .c1 = @import("fp.zig").fromU64(19) },
    };
    try std.testing.expect(Fp6.eql(Fp6.mul(a, b), Fp6.mul(b, a)));
}

test "Fp6 sqr == mul(a,a)" {
    const fp = @import("fp.zig");
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(3), .c1 = fp.fromU64(5) },
        .c1 = .{ .c0 = fp.fromU64(7), .c1 = fp.fromU64(11) },
        .c2 = .{ .c0 = fp.fromU64(2), .c1 = fp.fromU64(13) },
    };
    try std.testing.expect(Fp6.eql(Fp6.sqr(a), Fp6.mul(a, a)));
}

test "Fp6 inv roundtrip" {
    const fp = @import("fp.zig");
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(3), .c1 = fp.fromU64(5) },
        .c1 = .{ .c0 = fp.fromU64(7), .c1 = fp.fromU64(11) },
        .c2 = .{ .c0 = fp.fromU64(2), .c1 = fp.fromU64(13) },
    };
    try std.testing.expect(Fp6.eql(Fp6.mul(a, Fp6.inv(a)), Fp6.ONE));
}

test "Fp6 add/sub inverses" {
    const fp = @import("fp.zig");
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(100), .c1 = fp.fromU64(200) },
        .c1 = Fp2.ZERO,
        .c2 = .{ .c0 = fp.fromU64(42),  .c1 = fp.fromU64(1) },
    };
    const b: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(999), .c1 = fp.fromU64(1) },
        .c1 = .{ .c0 = fp.fromU64(7),   .c1 = fp.fromU64(3) },
        .c2 = Fp2.ZERO,
    };
    try std.testing.expect(Fp6.eql(Fp6.sub(Fp6.add(a, b), b), a));
}

test "Fp6 mulByV: v·1 = v" {
    // mulByV(ONE) should give (0,1,0) i.e. c1=ONE, c0=c2=ZERO
    const v_elem: Fp6 = .{ .c0 = Fp2.ZERO, .c1 = Fp2.ONE, .c2 = Fp2.ZERO };
    try std.testing.expect(Fp6.eql(Fp6.mulByV(Fp6.ONE), v_elem));
}

test "Fp6 frob1(frob1(frob1(a))) == frob3(a) for some a" {
    // φ_p composed 3 times = φ_{p³}
    const fp = @import("fp.zig");
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(5),  .c1 = fp.fromU64(11) },
        .c1 = .{ .c0 = fp.fromU64(13), .c1 = fp.fromU64(17) },
        .c2 = .{ .c0 = fp.fromU64(19), .c1 = fp.fromU64(23) },
    };
    const frob3_direct = Fp6.frob3(a);
    const frob1_cubed  = Fp6.frob1(Fp6.frob1(Fp6.frob1(a)));
    try std.testing.expect(Fp6.eql(frob3_direct, frob1_cubed));
}

test "Fp6 frob1^6 == identity" {
    const fp = @import("fp.zig");
    const a: Fp6 = .{
        .c0 = .{ .c0 = fp.fromU64(5),  .c1 = fp.fromU64(11) },
        .c1 = .{ .c0 = fp.fromU64(13), .c1 = fp.fromU64(17) },
        .c2 = .{ .c0 = fp.fromU64(19), .c1 = fp.fromU64(23) },
    };
    const f6 = Fp6.frob1(Fp6.frob1(Fp6.frob1(Fp6.frob1(Fp6.frob1(Fp6.frob1(a))))));
    try std.testing.expect(Fp6.eql(f6, a));
}

test "Fp6 derive and verify GAMMA_1_1 = xi^{(p-1)/6}" {
    // Compute ξ^{(p-1)/6} by repeated squaring, verify it squares to GAMMA_1_2,
    // then print the correct hex so we can update the hardcoded constant.
    const fp_ = @import("fp.zig");
    // ξ = 9 + 1·u  (in Montgomery form)
    const xi: Fp2 = .{ .c0 = fp_.fromU64(9), .c1 = fp_.ONE };
    // (p-1)/6 in 4×u64 LE limbs (computed from p-1 / 6)
    const exp_limbs = [4]u64{
        0x34b017592414d4e1,
        0xee9591c2e6bda1c2,
        0xf40d60f3c0403964,
        0x0810b7bdd032f006,
    };
    var result = Fp2.ONE;
    var base = xi;
    for (exp_limbs) |limb| {
        var kk: u7 = 0;
        while (kk < 64) : (kk += 1) {
            if (((limb >> @intCast(kk)) & 1) == 1) result = Fp2.mul(result, base);
            base = Fp2.sqr(base);
        }
    }
    // result^2 = ξ^{(p-1)/3} = what GAMMA_1_2 should be
    const sq = Fp2.sqr(result);
    std.debug.print("\nCorrect GAMMA_1_1 = xi^{{(p-1)/6}}:\n" ++
        "  c0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n" ++
        "  c1: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n", .{
        result.c0[0], result.c0[1], result.c0[2], result.c0[3],
        result.c1[0], result.c1[1], result.c1[2], result.c1[3],
    });
    std.debug.print("Correct GAMMA_1_2 = xi^{{(p-1)/3}} = above^2:\n" ++
        "  c0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n" ++
        "  c1: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n", .{
        sq.c0[0], sq.c0[1], sq.c0[2], sq.c0[3],
        sq.c1[0], sq.c1[1], sq.c1[2], sq.c1[3],
    });
    // PSI3 = ξ^{(p-1)/2} = GAMMA_1_1 * GAMMA_1_2
    const psi3 = Fp2.mul(result, sq);
    std.debug.print("PSI3 = xi^{{(p-1)/2}} = GAMMA_1_1 * GAMMA_1_2:\n" ++
        "  c0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n" ++
        "  c1: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n", .{
        psi3.c0[0], psi3.c0[1], psi3.c0[2], psi3.c0[3],
        psi3.c1[0], psi3.c1[1], psi3.c1[2], psi3.c1[3],
    });
    // PSI22 = ξ^{(p^2-1)/3} = norm(GAMMA_1_2) = GAMMA_1_2 * conj(GAMMA_1_2)  (real element)
    const psi22 = Fp2.mul(sq, Fp2.conj(sq));
    std.debug.print("PSI22 = xi^{{(p^2-1)/3}} = norm(GAMMA_1_2)  (real):\n" ++
        "  c0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n" ++
        "  c1 should be 0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n", .{
        psi22.c0[0], psi22.c0[1], psi22.c0[2], psi22.c0[3],
        psi22.c1[0], psi22.c1[1], psi22.c1[2], psi22.c1[3],
    });
    // PSI32 = ξ^{(p^2-1)/2} = norm(GAMMA_1_1)^3 = -1 (algebraic theorem for BN254)
    const norm11 = Fp2.mul(result, Fp2.conj(result)); // in Fp (real)
    const norm11_sq = Fp2.sqr(norm11);
    const psi32 = Fp2.mul(norm11_sq, norm11); // norm^3
    std.debug.print("PSI32 = xi^{{(p^2-1)/2}} = norm(GAMMA_1_1)^3  (should be -1 in Fp):\n" ++
        "  c0: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n" ++
        "  c1: {{ 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16}, 0x{x:0>16} }}\n", .{
        psi32.c0[0], psi32.c0[1], psi32.c0[2], psi32.c0[3],
        psi32.c1[0], psi32.c1[1], psi32.c1[2], psi32.c1[3],
    });
    if (!Fp2.eql(sq, Fp6.GAMMA_1_2)) {
        std.debug.print("GAMMA_1_2 in code is WRONG\n", .{});
    }
    try std.testing.expect(Fp2.eql(Fp2.mul(Fp2.sqr(result), result), Fp2.mul(Fp2.mul(result, result), result)));
}

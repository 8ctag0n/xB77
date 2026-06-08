//! BN254 Fp2 — quadratic extension Fp[u]/(u²+1), pure WASM
//!
//! Elements: c0 + c1·u  (c0, c1 ∈ Fp, u² = −1)
//! All coordinates stored in Montgomery form via fp.zig.

const std = @import("std");
const fp = @import("fp.zig");
const Fp = fp.Fp;

/// Fp2 element: c0 (real) + c1 (imaginary) · u
pub const Fp2 = struct {
    c0: Fp,
    c1: Fp,

    pub const ZERO: Fp2 = .{ .c0 = fp.ZERO, .c1 = fp.ZERO };
    pub const ONE:  Fp2 = .{ .c0 = fp.ONE,  .c1 = fp.ZERO };

    // ── Arithmetic ────────────────────────────────────────────────────────────

    pub fn add(a: Fp2, b: Fp2) Fp2 {
        return .{ .c0 = fp.add(a.c0, b.c0), .c1 = fp.add(a.c1, b.c1) };
    }

    pub fn sub(a: Fp2, b: Fp2) Fp2 {
        return .{ .c0 = fp.sub(a.c0, b.c0), .c1 = fp.sub(a.c1, b.c1) };
    }

    pub fn neg(a: Fp2) Fp2 {
        return .{ .c0 = fp.neg(a.c0), .c1 = fp.neg(a.c1) };
    }

    /// Karatsuba: (a0+a1·u)(b0+b1·u) = (a0b0−a1b1) + ((a0+a1)(b0+b1)−a0b0−a1b1)·u
    pub fn mul(a: Fp2, b: Fp2) Fp2 {
        const t0 = fp.mul(a.c0, b.c0);
        const t1 = fp.mul(a.c1, b.c1);
        return .{
            .c0 = fp.sub(t0, t1),
            .c1 = fp.sub(fp.mul(fp.add(a.c0, a.c1), fp.add(b.c0, b.c1)), fp.add(t0, t1)),
        };
    }

    /// Complex squaring: (a0+a1·u)² = (a0+a1)(a0−a1) + 2·a0·a1·u
    pub fn sqr(a: Fp2) Fp2 {
        const t0 = fp.mul(a.c0, a.c1);
        return .{
            .c0 = fp.mul(fp.add(a.c0, a.c1), fp.sub(a.c0, a.c1)),
            .c1 = fp.add(t0, t0),
        };
    }

    /// Inversion: (c0+c1·u)^{−1} = (c0−c1·u)/(c0²+c1²)
    pub fn inv(a: Fp2) Fp2 {
        const norm_inv = fp.inv(fp.add(fp.sqr(a.c0), fp.sqr(a.c1)));
        return .{
            .c0 = fp.mul(a.c0, norm_inv),
            .c1 = fp.mul(fp.neg(a.c1), norm_inv),
        };
    }

    /// Frobenius / conjugate: c0 + c1·u → c0 − c1·u
    pub fn conj(a: Fp2) Fp2 {
        return .{ .c0 = a.c0, .c1 = fp.neg(a.c1) };
    }

    /// Multiply by the tower non-residue ξ = 9+u:
    ///   (c0+c1·u)(9+u) = (9·c0−c1) + (c0+9·c1)·u
    pub fn mulByXi(a: Fp2) Fp2 {
        // 9x = 8x + x; done with adds to avoid fromU64 at runtime
        const c0_9 = fp.add(fp.add(fp.add(a.c0, a.c0), fp.add(a.c0, a.c0)),
                            fp.add(fp.add(a.c0, a.c0), fp.add(a.c0, a.c0)));
        // c0_9 = 8*c0; + a.c0 = 9*c0
        const nine_c0 = fp.add(c0_9, a.c0);
        const c1_9 = fp.add(fp.add(fp.add(a.c1, a.c1), fp.add(a.c1, a.c1)),
                            fp.add(fp.add(a.c1, a.c1), fp.add(a.c1, a.c1)));
        const nine_c1 = fp.add(c1_9, a.c1);
        return .{
            .c0 = fp.sub(nine_c0, a.c1),
            .c1 = fp.add(a.c0,    nine_c1),
        };
    }

    /// Multiply by a base-field scalar: (c0+c1·u) * s = c0·s + c1·s·u
    pub fn mulByFp(a: Fp2, b: fp.Fp) Fp2 {
        return .{ .c0 = fp.mul(a.c0, b), .c1 = fp.mul(a.c1, b) };
    }

    pub fn isZero(a: Fp2) bool {
        return fp.isZero(a.c0) and fp.isZero(a.c1);
    }

    pub fn eql(a: Fp2, b: Fp2) bool {
        return fp.eql(a.c0, b.c0) and fp.eql(a.c1, b.c1);
    }

    // ── I/O ───────────────────────────────────────────────────────────────────

    /// EIP-197 Fp2 encoding: 64 bytes = c1(32) | c0(32)  (imaginary first)
    pub fn fromBytes(bytes: *const [64]u8) Fp2 {
        return .{
            .c1 = fp.fromBytes(bytes[0..32]),
            .c0 = fp.fromBytes(bytes[32..64]),
        };
    }

    pub fn toBytes(a: Fp2, out: *[64]u8) void {
        fp.toBytes(a.c1, out[0..32]);
        fp.toBytes(a.c0, out[32..64]);
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "Fp2 ONE·ONE = ONE" {
    try std.testing.expect(Fp2.eql(Fp2.mul(Fp2.ONE, Fp2.ONE), Fp2.ONE));
}

test "Fp2 mul commutativity" {
    const a: Fp2 = .{ .c0 = fp.fromU64(3), .c1 = fp.fromU64(7) };
    const b: Fp2 = .{ .c0 = fp.fromU64(11), .c1 = fp.fromU64(13) };
    try std.testing.expect(Fp2.eql(Fp2.mul(a, b), Fp2.mul(b, a)));
}

test "Fp2 sqr == mul(a,a)" {
    const a: Fp2 = .{ .c0 = fp.fromU64(5), .c1 = fp.fromU64(17) };
    try std.testing.expect(Fp2.eql(Fp2.sqr(a), Fp2.mul(a, a)));
}

test "Fp2 inv roundtrip" {
    const a: Fp2 = .{ .c0 = fp.fromU64(3), .c1 = fp.fromU64(7) };
    try std.testing.expect(Fp2.eql(Fp2.mul(a, Fp2.inv(a)), Fp2.ONE));
}

test "Fp2 add/sub inverses" {
    const a: Fp2 = .{ .c0 = fp.fromU64(100), .c1 = fp.fromU64(200) };
    const b: Fp2 = .{ .c0 = fp.fromU64(999), .c1 = fp.fromU64(1) };
    try std.testing.expect(Fp2.eql(Fp2.sub(Fp2.add(a, b), b), a));
}

test "Fp2 u² = -1: mul of (0+1u)·(0+1u) = -1+0u" {
    const u: Fp2 = .{ .c0 = fp.ZERO, .c1 = fp.ONE };
    const result = Fp2.mul(u, u);
    // u² = -1 mod p → c0 = p-1 in Montgomery = neg(ONE), c1 = 0
    const neg_one: Fp2 = .{ .c0 = fp.neg(fp.ONE), .c1 = fp.ZERO };
    try std.testing.expect(Fp2.eql(result, neg_one));
}

test "Fp2 conj: (a+bu)·conj(a+bu) = a²+b² (norm, real)" {
    const a: Fp2 = .{ .c0 = fp.fromU64(3), .c1 = fp.fromU64(7) };
    const prod = Fp2.mul(a, Fp2.conj(a));
    // product should have c1 = 0
    try std.testing.expect(fp.isZero(prod.c1));
    // c0 = a0²+a1² = 9+49 = 58
    const want = fp.fromU64(58);
    try std.testing.expect(fp.eql(prod.c0, want));
}

test "Fp2 fromBytes/toBytes roundtrip" {
    var raw: [64]u8 = .{0} ** 64;
    raw[31] = 7;  // c1 = 7
    raw[63] = 3;  // c0 = 3
    const a = Fp2.fromBytes(&raw);
    var got: [64]u8 = undefined;
    Fp2.toBytes(a, &got);
    try std.testing.expectEqualSlices(u8, &raw, &got);
}

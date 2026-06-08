//! BN254 G2 point arithmetic — Jacobian coordinates over Fp2, pure WASM
//!
//! Twisted curve: y² = x³ + 3/ξ  over Fp2  (a = 0)
//! ξ = 9+u is the non-residue used in the tower extension.
//!
//! The a=0 condition means dbl-2007-bl and the standard Jacobian addJac
//! formulas apply unchanged over Fp2 — b does not appear in those formulas.
//!
//! EIP-197 wire format (128 bytes):
//!   x_c1(32) | x_c0(32) | y_c1(32) | y_c0(32)   (imaginary before real)

const std = @import("std");
const fp  = @import("fp.zig");
const fp2 = @import("fp2.zig");
const Fp2 = fp2.Fp2;

/// BN254 G2 in Jacobian coordinates — all fields are Fp2 in Montgomery form
pub const G2 = struct {
    x: Fp2,
    y: Fp2,
    z: Fp2,

    pub const INFINITY: G2 = .{ .x = Fp2.ONE, .y = Fp2.ONE, .z = Fp2.ZERO };

    /// Standard G2 generator (affine, EIP-197 / go-ethereum encoding)
    pub const GENERATOR: G2 = .{
        .x = .{
            // c0 = 0x1800deef121f1e76...  c1 = 0x198e9393920d483a...
            .c0 = .{ 0x8e83b5d102bc2026, 0xdceb1935497b0172, 0xfbb8264797811adf, 0x19573841af96503b },
            .c1 = .{ 0xafb4737da84c6140, 0x6043dd5a5802d8c4, 0x09e950fc52a02f86, 0x14fef0833aea7b6b },
        },
        .y = .{
            // c0 = 0x12c85ea5db8c6deb...  c1 = 0x090689d0585ff075...
            .c0 = .{ 0x619dfa9d886be9f6, 0xfe7fd297f59e9b78, 0xff9e1a62231b7dfe, 0x28fd7eebae9e4206 },
            .c1 = .{ 0x64095b56c71856ee, 0xdc57f922327d3cbb, 0x55f935be33351076, 0x0da4a0e693fd6482 },
        },
        .z = Fp2.ONE,
    };

    pub fn isInfinity(self: G2) bool {
        return Fp2.isZero(self.z);
    }

    // ── I/O ───────────────────────────────────────────────────────────────────

    /// Parse EIP-197 G2 affine 128 bytes: x_c1|x_c0|y_c1|y_c0 → Jacobian Z=1
    pub fn fromAffineBytes(bytes: *const [128]u8) G2 {
        return .{
            .x = Fp2.fromBytes(bytes[0..64]),
            .y = Fp2.fromBytes(bytes[64..128]),
            .z = Fp2.ONE,
        };
    }

    /// Serialize to EIP-197 128 bytes. Infinity → 128 zero bytes.
    pub fn toAffineBytes(self: G2, out: *[128]u8) void {
        if (self.isInfinity()) {
            @memset(out, 0);
            return;
        }
        const z_inv  = Fp2.inv(self.z);
        const z_inv2 = Fp2.mul(z_inv, z_inv);
        const z_inv3 = Fp2.mul(z_inv2, z_inv);
        Fp2.toBytes(Fp2.mul(self.x, z_inv2), out[0..64]);
        Fp2.toBytes(Fp2.mul(self.y, z_inv3), out[64..128]);
    }

    // ── Arithmetic ────────────────────────────────────────────────────────────

    /// Jacobian doubling — dbl-2007-bl (a = 0), same formula as G1 but over Fp2
    pub fn dbl(self: G2) G2 {
        if (self.isInfinity()) return INFINITY;

        const X = self.x;
        const Y = self.y;
        const Z = self.z;

        const aa  = Fp2.sqr(X);                           // A = X²
        const bb  = Fp2.sqr(Y);                           // B = Y²
        const cc  = Fp2.sqr(bb);                          // C = B²
        const xpb = Fp2.add(X, bb);
        const d2  = Fp2.sub(Fp2.sub(Fp2.sqr(xpb), aa), cc);
        const dd  = Fp2.add(d2, d2);                      // D = 2((X+B)²−A−C)
        const ee  = Fp2.add(Fp2.add(aa, aa), aa);         // E = 3A
        const ff  = Fp2.sqr(ee);                          // F = E²

        const x3 = Fp2.sub(ff, Fp2.add(dd, dd));
        const c8 = Fp2.add(Fp2.add(Fp2.add(cc, cc), Fp2.add(cc, cc)),
                           Fp2.add(Fp2.add(cc, cc), Fp2.add(cc, cc)));
        const y3 = Fp2.sub(Fp2.mul(ee, Fp2.sub(dd, x3)), c8);
        const z3 = Fp2.mul(Fp2.add(Y, Y), Z);

        return .{ .x = x3, .y = y3, .z = z3 };
    }

    /// Jacobian + Jacobian addition
    pub fn addJac(self: G2, other: G2) G2 {
        if (self.isInfinity())  return other;
        if (other.isInfinity()) return self;

        const X1 = self.x;  const Y1 = self.y;  const Z1 = self.z;
        const X2 = other.x; const Y2 = other.y; const Z2 = other.z;

        const z1z1 = Fp2.sqr(Z1);
        const z2z2 = Fp2.sqr(Z2);
        const uu1  = Fp2.mul(X1, z2z2);
        const uu2  = Fp2.mul(X2, z1z1);
        const ss1  = Fp2.mul(Fp2.mul(Y1, Z2), z2z2);
        const ss2  = Fp2.mul(Fp2.mul(Y2, Z1), z1z1);

        const h    = Fp2.sub(uu2, uu1);
        const s2s1 = Fp2.sub(ss2, ss1);
        const r    = Fp2.add(s2s1, s2s1);

        if (Fp2.isZero(h)) {
            if (Fp2.isZero(r)) return self.dbl();
            return INFINITY;
        }

        const ii   = Fp2.sqr(Fp2.add(h, h));
        const jj   = Fp2.mul(h, ii);
        const vv   = Fp2.mul(uu1, ii);

        const x3  = Fp2.sub(Fp2.sub(Fp2.sqr(r), jj), Fp2.add(vv, vv));
        const s1j = Fp2.mul(ss1, jj);
        const y3  = Fp2.sub(Fp2.mul(r, Fp2.sub(vv, x3)), Fp2.add(s1j, s1j));
        const z12 = Fp2.add(Z1, Z2);
        const z3  = Fp2.mul(Fp2.sub(Fp2.sub(Fp2.sqr(z12), z1z1), z2z2), h);

        return .{ .x = x3, .y = y3, .z = z3 };
    }

    /// Scalar multiplication: s · self  (double-and-add, MSB first)
    /// scalar: 4×u64 little-endian
    pub fn scalarMul(self: G2, scalar: [4]u64) G2 {
        var result = INFINITY;
        var li: usize = 4;
        while (li > 0) {
            li -= 1;
            var bi: u6 = 63;
            while (true) {
                result = result.dbl();
                if ((scalar[li] >> bi) & 1 == 1) result = result.addJac(self);
                if (bi == 0) break;
                bi -= 1;
            }
        }
        return result;
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "G2 scalar 0 → infinity" {
    const r = G2.GENERATOR.scalarMul(.{ 0, 0, 0, 0 });
    try std.testing.expect(r.isInfinity());
}

test "G2 scalar 1 → generator roundtrip" {
    const r = G2.GENERATOR.scalarMul(.{ 1, 0, 0, 0 });
    var got: [128]u8 = undefined;
    r.toAffineBytes(&got);

    // Expected: EIP-197 generator bytes (x_c1|x_c0|y_c1|y_c0)
    const expected = [128]u8{
        // x_c1
        0x19, 0x8e, 0x93, 0x93, 0x92, 0x0d, 0x48, 0x3a,
        0x72, 0x60, 0xbf, 0xb7, 0x31, 0xfb, 0x5d, 0x25,
        0xf1, 0xaa, 0x49, 0x33, 0x35, 0xa9, 0xe7, 0x12,
        0x97, 0xe4, 0x85, 0xb7, 0xae, 0xf3, 0x12, 0xc2,
        // x_c0
        0x18, 0x00, 0xde, 0xef, 0x12, 0x1f, 0x1e, 0x76,
        0x42, 0x6a, 0x00, 0x66, 0x5e, 0x5c, 0x44, 0x79,
        0x67, 0x43, 0x22, 0xd4, 0xf7, 0x5e, 0xda, 0xdd,
        0x46, 0xde, 0xbd, 0x5c, 0xd9, 0x92, 0xf6, 0xed,
        // y_c1
        0x09, 0x06, 0x89, 0xd0, 0x58, 0x5f, 0xf0, 0x75,
        0xec, 0x9e, 0x99, 0xad, 0x69, 0x0c, 0x33, 0x95,
        0xbc, 0x4b, 0x31, 0x33, 0x70, 0xb3, 0x8e, 0xf3,
        0x55, 0xac, 0xda, 0xdc, 0xd1, 0x22, 0x97, 0x5b,
        // y_c0
        0x12, 0xc8, 0x5e, 0xa5, 0xdb, 0x8c, 0x6d, 0xeb,
        0x4a, 0xab, 0x71, 0x80, 0x8d, 0xcb, 0x40, 0x8f,
        0xe3, 0xd1, 0xe7, 0x69, 0x0c, 0x43, 0xd3, 0x7b,
        0x4c, 0xe6, 0xcc, 0x01, 0x66, 0xfa, 0x7d, 0xaa,
    };
    try std.testing.expectEqualSlices(u8, &expected, &got);
}

test "G2 add == dbl" {
    const g = G2.GENERATOR;
    var ba: [128]u8 = undefined;
    var bd: [128]u8 = undefined;
    g.addJac(g).toAffineBytes(&ba);
    g.dbl().toAffineBytes(&bd);
    try std.testing.expectEqualSlices(u8, &ba, &bd);
}

test "G2 scalar 2 == dbl" {
    const g = G2.GENERATOR;
    var bs: [128]u8 = undefined;
    var bd: [128]u8 = undefined;
    g.scalarMul(.{ 2, 0, 0, 0 }).toAffineBytes(&bs);
    g.dbl().toAffineBytes(&bd);
    try std.testing.expectEqualSlices(u8, &bs, &bd);
}

test "G2 scalar 2 matches Python-computed vector" {
    const r = G2.GENERATOR.scalarMul(.{ 2, 0, 0, 0 });
    var got: [128]u8 = undefined;
    r.toAffineBytes(&got);

    const expected = [128]u8{
        0x20, 0x3e, 0x20, 0x5d, 0xb4, 0xf1, 0x9b, 0x37, 0xb6, 0x01, 0x21, 0xb8, 0x3a, 0x73, 0x33, 0x70,
        0x6d, 0xb8, 0x64, 0x31, 0xc6, 0xd8, 0x35, 0x84, 0x99, 0x57, 0xed, 0x8c, 0x39, 0x28, 0xad, 0x79,
        0x27, 0xdc, 0x72, 0x34, 0xfd, 0x11, 0xd3, 0xe8, 0xc3, 0x6c, 0x59, 0x27, 0x7c, 0x3e, 0x6f, 0x14,
        0x9d, 0x5c, 0xd3, 0xcf, 0xa9, 0xa6, 0x2a, 0xee, 0x49, 0xf8, 0x13, 0x09, 0x62, 0xb4, 0xb3, 0xb9,
        0x19, 0x5e, 0x8a, 0xa5, 0xb7, 0x82, 0x74, 0x63, 0x72, 0x2b, 0x8c, 0x15, 0x39, 0x31, 0x57, 0x9d,
        0x35, 0x05, 0x56, 0x6b, 0x4e, 0xdf, 0x48, 0xd4, 0x98, 0xe1, 0x85, 0xf0, 0x50, 0x9d, 0xe1, 0x52,
        0x04, 0xbb, 0x53, 0xb8, 0x97, 0x7e, 0x5f, 0x92, 0xa0, 0xbc, 0x37, 0x27, 0x42, 0xc4, 0x83, 0x09,
        0x44, 0xa5, 0x9b, 0x4f, 0xe6, 0xb1, 0xc0, 0x46, 0x6e, 0x2a, 0x6d, 0xad, 0x12, 0x2b, 0x5d, 0x2e,
    };
    try std.testing.expectEqualSlices(u8, &expected, &got);
}

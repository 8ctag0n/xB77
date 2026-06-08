//! BN254 prime field Fp — Montgomery form, pure WASM arithmetic
//!
//! p = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47
//!
//! Storage: 4×u64 little-endian limbs in Montgomery form (a_mont = a·R mod p, R=2^256).
//! I/O: fromBytes/toBytes handle the Montgomery↔standard conversion transparently.
//!
//! Constants verified against gnark-crypto bn254/fp.

const std = @import("std");

/// 256-bit field prime (4×u64, little-endian)
pub const P = [4]u64{
    0x3c208c16d87cfd47,
    0x97816a916871ca8d,
    0xb85045b68181585d,
    0x30644e72e131a029,
};

/// −p⁻¹ mod 2^64  (P[0] · P_INV_NEG ≡ −1 mod 2^64)
const P_INV_NEG: u64 = 0x87d20782e4866389;

/// R² mod p — converts raw integers into Montgomery form via mul(·, R_SQR)
const R_SQR = [4]u64{
    0xf32cfc5b538afa89,
    0xb5e71911d44501fb,
    0x47ab1eff0a417ff6,
    0x06d89f71cab8351f,
};

/// Fp element type — 4×u64 little-endian Montgomery form
pub const Fp = [4]u64;

/// 0
pub const ZERO: Fp = .{ 0, 0, 0, 0 };

/// 1 in Montgomery form (= R mod p)
pub const ONE: Fp = .{
    0xd35d438dc58f0d9d,
    0x0a78eb28f5c70b3d,
    0x666ea36f7879462c,
    0x0e0a77c19a07df2f,
};

/// 2 in Montgomery form (= 2·R mod p)
pub const TWO: Fp = .{
    0xa6ba871b8b1e1b3a,
    0x14f1d651eb8e167b,
    0xccdd46def0f28c58,
    0x1c14ef83340fbe5e,
};

/// 3 in Montgomery form — curve constant b for BN254
pub const THREE: Fp = .{
    0x7a17caa950ad28d7,
    0x1f6ac17ae15521b9,
    0x334bea4e696bd284,
    0x2a1f6744ce179d8e,
};

// ── Core arithmetic ───────────────────────────────────────────────────────────

/// Montgomery multiplication: (a·b·R⁻¹) mod p  — CIOS algorithm, 4 limbs
pub fn mul(a: Fp, b: Fp) Fp {
    var t: [5]u64 = .{ 0, 0, 0, 0, 0 };

    for (0..4) |i| {
        // Step 1: t = t + a × b[i]
        var c: u128 = 0;
        for (0..4) |j| {
            const v: u128 = @as(u128, a[j]) * b[i] + t[j] + c;
            t[j] = @truncate(v);
            c = v >> 64;
        }
        t[4] +%= @as(u64, @truncate(c));

        // Step 2: Montgomery reduce — m = t[0]·(−p⁻¹) mod 2^64, shift out t[0]
        const m: u64 = @truncate(@as(u128, t[0]) * P_INV_NEG);
        var c2: u128 = 0;
        for (0..4) |j| {
            const v: u128 = @as(u128, m) * P[j] + t[j] + c2;
            if (j > 0) t[j - 1] = @truncate(v); // t[0] discarded (≡ 0 mod 2^64)
            c2 = v >> 64;
        }
        const vl: u128 = @as(u128, t[4]) + c2;
        t[3] = @truncate(vl);
        t[4] = @truncate(vl >> 64);
    }

    var r: Fp = t[0..4].*;
    if (t[4] != 0 or !lt4(r, P)) r = sub4(r, P);
    return r;
}

/// Squaring (a·a·R⁻¹ mod p)
pub fn sqr(a: Fp) Fp {
    return mul(a, a);
}

/// Addition mod p
pub fn add(a: Fp, b: Fp) Fp {
    var r: Fp = undefined;
    var c: u128 = 0;
    for (0..4) |i| {
        const v: u128 = @as(u128, a[i]) + b[i] + c;
        r[i] = @truncate(v);
        c = v >> 64;
    }
    if (c != 0 or !lt4(r, P)) r = sub4(r, P);
    return r;
}

/// Subtraction mod p  (a − b mod p, always positive)
pub fn sub(a: Fp, b: Fp) Fp {
    if (lt4(a, b)) {
        // a < b: compute p − b + a  (both operands in [0,p), result in (0,p))
        const pb = sub4(P, b);
        return add(pb, a);
    }
    return sub4(a, b);
}

/// Negation: −a mod p
pub fn neg(a: Fp) Fp {
    if (isZero(a)) return ZERO;
    return sub4(P, a);
}

/// Field inversion: a^{p−2} mod p  (Fermat's little theorem)
pub fn inv(a: Fp) Fp {
    // p − 2 in 4×u64 little-endian (only the lowest limb differs from p)
    const EXP: [4]u64 = .{
        0x3c208c16d87cfd45, // p[0] − 2
        0x97816a916871ca8d,
        0xb85045b68181585d,
        0x30644e72e131a029,
    };
    return pow(a, EXP);
}

// ── Conversion ────────────────────────────────────────────────────────────────

/// Small integer → Fp (Montgomery form)
pub fn fromU64(n: u64) Fp {
    return mul(.{ n, 0, 0, 0 }, R_SQR);
}

/// Big-endian 32 bytes → Fp (Montgomery form)
pub fn fromBytes(bytes: *const [32]u8) Fp {
    var limbs: Fp = undefined;
    for (0..4) |i| {
        limbs[i] = std.mem.readInt(u64, bytes[24 - i * 8 ..][0..8], .big);
    }
    return mul(limbs, R_SQR);
}

/// Fp → big-endian 32 bytes
pub fn toBytes(a: Fp, out: *[32]u8) void {
    // Strip Montgomery factor by multiplying by 1 (as a raw limb array)
    const ONE_RAW: Fp = .{ 1, 0, 0, 0 };
    const normal = mul(a, ONE_RAW);
    for (0..4) |i| {
        std.mem.writeInt(u64, out[24 - i * 8 ..][0..8], normal[i], .big);
    }
}

// ── Predicates ────────────────────────────────────────────────────────────────

pub fn isZero(a: Fp) bool {
    return a[0] == 0 and a[1] == 0 and a[2] == 0 and a[3] == 0;
}

pub fn eql(a: Fp, b: Fp) bool {
    return a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3];
}

// ── Internals ─────────────────────────────────────────────────────────────────

/// a < b, 4-limb little-endian comparison
fn lt4(a: [4]u64, b: [4]u64) bool {
    var i: usize = 3;
    while (true) : (i -= 1) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
        if (i == 0) return false;
    }
}

/// Unchecked subtraction — caller ensures a >= b
fn sub4(a: [4]u64, b: [4]u64) [4]u64 {
    var r: [4]u64 = undefined;
    var borrow: u64 = 0;
    for (0..4) |i| {
        const ai = @as(u128, a[i]);
        const bi = @as(u128, b[i]) + borrow;
        if (ai < bi) {
            r[i] = @truncate(ai + (1 << 64) - bi);
            borrow = 1;
        } else {
            r[i] = @truncate(ai - bi);
            borrow = 0;
        }
    }
    return r;
}

/// Square-and-multiply exponentiation (right-to-left binary method)
pub fn pow(base: Fp, exp: [4]u64) Fp {
    var result = ONE;
    var cur = base;
    for (0..4) |li| {
        var limb = exp[li];
        for (0..64) |_| {
            if (limb & 1 == 1) result = mul(result, cur);
            cur = sqr(cur);
            limb >>= 1;
        }
    }
    return result;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "Fp constants: ONE·ONE = ONE" {
    try std.testing.expect(eql(mul(ONE, ONE), ONE));
}

test "Fp add/sub inverses" {
    const a = fromU64(17);
    const b = fromU64(999);
    const r = sub(add(a, b), b);
    try std.testing.expect(eql(r, a));
}

test "Fp mul commutativity" {
    const a = fromU64(12345);
    const b = fromU64(67890);
    try std.testing.expect(eql(mul(a, b), mul(b, a)));
}

test "Fp inv roundtrip" {
    const a = fromU64(7);
    try std.testing.expect(eql(mul(a, inv(a)), ONE));
}

test "Fp sub underflow wraps" {
    // 0 - 1 mod p = p - 1
    const r = sub(ZERO, ONE);
    const p_minus_1 = sub4(P, ONE);
    try std.testing.expect(eql(r, p_minus_1));
}

test "Fp fromBytes/toBytes roundtrip" {
    var src: [32]u8 = .{0} ** 32;
    src[31] = 42;
    const a = fromBytes(&src);
    var got: [32]u8 = undefined;
    toBytes(a, &got);
    try std.testing.expectEqualSlices(u8, &src, &got);
}

test "Fp fromU64(2) == TWO" {
    try std.testing.expect(eql(fromU64(2), TWO));
}

test "Fp fromU64(3) == THREE" {
    try std.testing.expect(eql(fromU64(3), THREE));
}

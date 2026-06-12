//! BN254 scalar field Fr — Montgomery form, pure WASM arithmetic
//!
//! r = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
//!
//! Storage: 4×u64 little-endian limbs in Montgomery form (a_mont = a·R mod r, R=2^256).
//! I/O: fromBytes32/toBytes32 handle Montgomery↔standard conversion.
//!
//! Used by the UltraPlonk verifier for all field arithmetic operations.

const std = @import("std");

/// BN254 Fr prime (4×u64 little-endian)
pub const R = [4]u64{
    0x43e1f593f0000001,
    0x2833e84879b97091,
    0xb85045b68181585d,
    0x30644e72e131a029,
};

/// −r⁻¹ mod 2^64 (CIOS reduction constant)
const R_INV_NEG: u64 = 0xc2e1f593efffffff;

/// R² mod r — converts raw u256 into Montgomery form via mul(·, R_SQR)
const R_SQR = [4]u64{
    0x1bb8e645ae216da7,
    0x53fe3ab1e35c59e3,
    0x8c49833d53bb8085,
    0x0216d0b17f4e44a5,
};

/// Fr element type — 4×u64 little-endian Montgomery form
pub const Fr = [4]u64;

pub const ZERO: Fr = .{ 0, 0, 0, 0 };

/// 1 in Montgomery form (R mod r)
pub const ONE: Fr = .{
    0xac96341c4ffffffb,
    0x36fc76959f60cd29,
    0x666ea36f7879462e,
    0x0e0a77c19a07df2f,
};

// ── Core arithmetic ───────────────────────────────────────────────────────────

/// CIOS Montgomery multiplication: returns (a·b·R⁻¹) mod r
pub fn mul(a: Fr, b: Fr) Fr {
    var t: [5]u64 = .{ 0, 0, 0, 0, 0 };
    for (0..4) |i| {
        var c: u128 = 0;
        for (0..4) |j| {
            const v: u128 = @as(u128, a[j]) * b[i] + t[j] + c;
            t[j] = @truncate(v);
            c = v >> 64;
        }
        t[4] +%= @as(u64, @truncate(c));

        const m: u64 = @truncate(@as(u128, t[0]) * R_INV_NEG);
        var c2: u128 = 0;
        for (0..4) |j| {
            const v: u128 = @as(u128, m) * R[j] + t[j] + c2;
            if (j > 0) t[j - 1] = @truncate(v);
            c2 = v >> 64;
        }
        const v5: u128 = @as(u128, t[4]) + c2;
        t[3] = @truncate(v5);
        t[4] = @truncate(v5 >> 64);
    }
    var res: Fr = .{ t[0], t[1], t[2], t[3] };
    // conditional subtract if res ≥ r
    if (geR(res)) res = subNoReduce(res, R);
    return res;
}

/// Modular addition mod r
pub fn add(a: Fr, b: Fr) Fr {
    var carry: u64 = 0;
    var res: Fr = undefined;
    for (0..4) |i| {
        const sum: u128 = @as(u128, a[i]) + b[i] + carry;
        res[i] = @truncate(sum);
        carry = @truncate(sum >> 64);
    }
    if (carry != 0 or geR(res)) res = subNoReduce(res, R);
    return res;
}

/// Modular subtraction mod r: a - b mod r
pub fn sub(a: Fr, b: Fr) Fr {
    var borrow: u64 = 0;
    var res: Fr = undefined;
    for (0..4) |i| {
        const d: u128 = @as(u128, a[i]) -% b[i] -% borrow;
        res[i] = @truncate(d);
        borrow = @truncate(d >> 127); // 1 if underflow
    }
    if (borrow != 0) res = addNoCarryReduce(res, R);
    return res;
}

/// Negate: returns r - a (mod r), or 0 if a == 0
pub fn neg(a: Fr) Fr {
    if (isZero(a)) return ZERO;
    return subNoReduce(R, a);
}

/// Squaring: a² in Montgomery form
pub fn sq(a: Fr) Fr {
    return mul(a, a);
}

/// Convert a raw 32-byte big-endian value into Montgomery form
pub fn fromBytes32(bytes: *const [32]u8) Fr {
    // Load as 4×u64 big-endian → little-endian limbs
    var raw: Fr = undefined;
    for (0..4) |i| {
        raw[3 - i] = std.mem.readInt(u64, bytes[i * 8 ..][0..8], .big);
    }
    // Multiply by R_SQR to convert to Montgomery form
    return mul(raw, R_SQR);
}

/// Convert from Montgomery form to raw 32-byte big-endian
pub fn toBytes32(a: Fr, out: *[32]u8) void {
    // Multiply by 1 (identity in non-Montgomery = divide by R)
    const raw = mul(a, ONE_RAW);
    for (0..4) |i| {
        std.mem.writeInt(u64, out[i * 8 ..][0..8], raw[3 - i], .big);
    }
}

/// Modular exponentiation: a^exp in Montgomery form
/// exp is a raw u256 in 4×u64 little-endian (not Montgomery)
pub fn pow(a: Fr, exp: [4]u64) Fr {
    var result = ONE;
    var base = a;
    for (0..4) |i| {
        var e = exp[i];
        for (0..64) |_| {
            if (e & 1 == 1) result = mul(result, base);
            base = sq(base);
            e >>= 1;
        }
    }
    return result;
}

/// Modular inverse via Fermat: a^(r-2) mod r
pub fn inv(a: Fr) Fr {
    // r - 2 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593efffffff
    const r_minus_2 = [4]u64{
        0x43e1f593efffffff,
        0x2833e84879b97091,
        0xb85045b68181585d,
        0x30644e72e131a029,
    };
    return pow(a, r_minus_2);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// 1 as raw limbs (not Montgomery) — used internally for toBytes32
const ONE_RAW: Fr = .{ 1, 0, 0, 0 };

fn geR(a: Fr) bool {
    var i: usize = 4;
    while (i > 0) {
        i -= 1;
        if (a[i] < R[i]) return false;
        if (a[i] > R[i]) return true;
    }
    return true; // equal
}

fn isZero(a: Fr) bool {
    return a[0] == 0 and a[1] == 0 and a[2] == 0 and a[3] == 0;
}

fn subNoReduce(a: Fr, b: Fr) Fr {
    var borrow: u64 = 0;
    var res: Fr = undefined;
    for (0..4) |i| {
        const d: u128 = @as(u128, a[i]) -% b[i] -% borrow;
        res[i] = @truncate(d);
        borrow = @truncate(d >> 127);
    }
    return res;
}

fn addNoCarryReduce(a: Fr, b: Fr) Fr {
    var carry: u64 = 0;
    var res: Fr = undefined;
    for (0..4) |i| {
        const s: u128 = @as(u128, a[i]) + b[i] + carry;
        res[i] = @truncate(s);
        carry = @truncate(s >> 64);
    }
    return res;
}

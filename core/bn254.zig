const std = @import("std");

/// BN254 Scalar Field Implementation for Poseidon Hash (Deluxe Montgomery Edition)
/// Modulus r = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
pub const Fr = struct {
    value: u256, // Valor en dominio Montgomery: (v * R) mod P

    pub const P = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    
    // Constantes Montgomery para R = 2^256
    // R2 = (2^256)^2 mod P
    const R2 = 0x216d0b17f4e44a58c49833d53bb808553fe3ab1e35c59e31bb8e645ae216da7;
    // P_INV = -P^-1 mod 2^256
    const P_INV = 0x73f82f1d0d8341b2e39a9828990623916586864b4c6911b3c2e1f593efffffff;

    pub const ZERO = Fr{ .value = 0 };
    pub const ONE = fromInt(1);

    pub fn fromInt(v: u256) Fr {
        // Para entrar al dominio Montgomery: (v * R^2) / R = v * R mod P
        return mulRaw(v % P, R2);
    }

    pub fn toInt(self: Fr) u256 {
        // Para salir: (v * R) / R = v mod P
        return redc(@as(u512, self.value));
    }

    pub fn add(self: Fr, other: Fr) Fr {
        var res = @as(u257, self.value) + other.value;
        if (res >= P) res -= P;
        return .{ .value = @intCast(res) };
    }

    pub fn sub(self: Fr, other: Fr) Fr {
        if (self.value >= other.value) {
            return .{ .value = self.value - other.value };
        } else {
            return .{ .value = P - (other.value - self.value) };
        }
    }

    pub fn mul(self: Fr, other: Fr) Fr {
        return mulRaw(self.value, other.value);
    }

    fn mulRaw(a: u256, b: u256) Fr {
        return .{ .value = redc(@as(u512, a) * b) };
    }

    /// REDC Algorithm: Montgomery Reduction
    fn redc(t: u512) u256 {
        const m = @as(u256, @truncate(t)) *% P_INV;
        const t_plus_mp = t + (@as(u512, m) * P);
        const res = @as(u256, @truncate(t_plus_mp >> 256));
        return if (res >= P) res - P else res;
    }

    pub fn sbox(self: Fr) Fr {
        const x2 = self.mul(self);
        const x4 = x2.mul(x2);
        return x4.mul(self);
    }

    pub fn eql(self: Fr, other: Fr) bool {
        return self.value == other.value;
    }
};

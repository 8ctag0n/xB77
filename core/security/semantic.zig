const std = @import("std");

/// Semantic Intelligence Engine for Arbitrum Stylus
/// Implements vector similarity (Cosine) and embedding policy checks.
pub const Semantic = struct {
    pub const DIMENSIONS = 128; // Reduced dimensions for demo performance
    
    /// Fixed-point version for Stylus (WASM ink optimization)
    /// Vectors are stored as i32 scaled by 10,000.
    pub const FixedVector = [DIMENSIONS]i32;
    pub const SCALE: i32 = 10_000;

    pub fn dotFixed(a: FixedVector, b: FixedVector) i64 {
        var sum: i64 = 0;
        for (0..DIMENSIONS) |i| {
            sum += @as(i64, a[i]) * b[i];
        }
        return sum;
    }

    /// Integer Square Root for Fixed Point
    pub fn sqrt(y: u64) u64 {
        if (y == 0) return 0;
        var z = (y + 1) / 2;
        var x = y;
        while (z < x) {
            x = z;
            z = (y / x + x) / 2;
        }
        return x;
    }

    pub fn normFixed(a: FixedVector) i32 {
        var sum: u64 = 0;
        for (0..DIMENSIONS) |i| {
            const val: i64 = a[i];
            sum += @intCast(val * val);
        }
        return @intCast(sqrt(sum));
    }

    pub fn cosineSimilarityFixed(a: FixedVector, b: FixedVector) i32 {
        const d = dotFixed(a, b);
        const n_a = normFixed(a);
        const n_b = normFixed(b);
        if (n_a == 0 or n_b == 0) return 0;
        
        // Result = (d * SCALE) / (n_a * n_b)
        const numerator = d * SCALE;
        const denominator = @as(i64, n_a) * n_b;
        return @intCast(@divTrunc(numerator, denominator));
    }
};

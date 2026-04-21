const std = @import("std");
const yellowstone = @import("yellowstone.zig");

pub const RiskEngine = struct {
    /// Calcula el score de riesgo (0.0 = Seguro, 1.0 = Peligro Extremo)
    pub fn assess(tx: yellowstone.TransactionData) f32 {
        var score: f32 = 0.0;
        
        // 1. Detección de Ballenas (Ej: > 50 SOL)
        if (tx.amount > 50_000_000_000) {
            score += 0.4;
        }

        // 2. Origen Desconocido
        if (!tx.is_xb77) {
            score += 0.2;
        }

        return @min(score, 1.0);
    }

    pub fn isActionable(score: f32) bool {
        return score < 0.6;
    }
};

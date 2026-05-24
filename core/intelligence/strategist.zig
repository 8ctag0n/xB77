const std = @import("std");
const core = @import("../core.zig");
const types = core.types;

/// Strategist: El cerebro táctico que orquestra el capital en Solana.
/// Especializado en LSTs (Liquid Staking Tokens) y Yield Farming.
pub const Strategist = struct {
    allocator: std.mem.Allocator,
    store: *@import("../protocol/store.zig").Store,

    pub fn init(allocator: std.mem.Allocator, store: *@import("../protocol/store.zig").Store) Strategist {
        return .{
            .allocator = allocator,
            .store = store,
        };
    }

    /// Calcula la mejor ruta de yield para el capital ocioso.
    pub fn calculateOptimalYield(self: *Strategist) !YieldPlan {
        _ = self;
        // Simulación de análisis de Kamino/Jito/Orca
        // En una implementación real, esto consultaría oráculos on-chain.
        return YieldPlan{
            .protocol = "Kamino Finance",
            .strategy = "JupSOL/USDC CLMM",
            .expected_apy = 14.5,
            .risk_score = 0.82,
            .reasoning = "High trading volume in JupSOL pools detected. Increasing fees outweigh impermanent loss risk.",
        };
    }
};

pub const YieldPlan = struct {
    protocol: []const u8,
    strategy: []const u8,
    expected_apy: f32,
    risk_score: f32,
    reasoning: []const u8,
};

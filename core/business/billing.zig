const std = @import("std");
const types = @import("../protocol/types.zig");

pub const CreditStatus = struct {
    agent_id: types.Pubkey,
    balance: u64,           // En "Sovereign Credits" (SC)
    total_spent: u64,
    last_update: i64,
};

pub const BillingManager = struct {
    allocator: std.mem.Allocator,
    
    // Costos base en Sovereign Credits (SC)
    // Estos valores se ajustan según el costo real de los proveedores + nuestro margen
    pub const DEPLOY_FEE_SC = 2000;    
    
    // Unidades de costo dinámico
    pub const COMPUTE_UNIT_SC = 1;     // x ms de Cloudflare Worker
    pub const AI_TOKEN_SC = 5;         // Por 1k tokens de inferencia
    pub const DATA_RPC_SC = 10;        // Por cada llamada a Quicknode/Helius

    // Margen de Facilitación (11% sobre el costo de infra)
    pub const INFRA_MARKUP_BPS = 1100;

    // Ratio de conversión: 1 SOL = 1,000,000 SC
    pub const SC_PER_SOL = 1_000_000;

    pub fn init(allocator: std.mem.Allocator) BillingManager {
        return .{ .allocator = allocator };
    }

    /// Calcula el costo total de una operación basado en el uso de recursos
    pub fn calculateOperationCost(compute_ms: u64, ai_tokens: u64, rpc_calls: u64) u64 {
        const base_cost = (compute_ms * COMPUTE_UNIT_SC) + 
                          ((ai_tokens * AI_TOKEN_SC) / 1000) + 
                          (rpc_calls * DATA_RPC_SC);
        
        const markup = (base_cost * INFRA_MARKUP_BPS) / 10000;
        return base_cost + markup;
    }

    /// Calcula cuántos créditos se obtienen por un depósito de SOL
    pub fn solToCredits(lamports: u64) u64 {
        return (lamports * SC_PER_SOL) / 1_000_000_000;
    }

    /// Valida si el agente tiene saldo suficiente
    pub fn hasBalance(status: CreditStatus, required: u64) bool {
        return status.balance >= required;
    }

    /// Procesa un depósito y retorna el nuevo status
    pub fn processDeposit(status: *CreditStatus, lamports: u64) void {
        const credits = solToCredits(lamports);
        status.balance += credits;
        status.last_update = std.time.milliTimestamp();
    }
};

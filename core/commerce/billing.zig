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

    pub const SOVEREIGN_TAX_BPS = 2011;    // 2.011%
    pub const PROTOCOL_SHARE_BPS = 1005;   // 1.0055% (miti)
    pub const OPERATOR_SHARE_BPS = 1006;   // 1.0055% (miti)

    // Ratio de conversión: 1 SOL = 1,000,000 SC
    pub const SC_PER_SOL = 1_000_000;

    pub fn init(allocator: std.mem.Allocator) BillingManager {
        return .{ .allocator = allocator };
    }

    /// Calcula el tax soberano para una transacción
    pub fn calculateTax(amount: u64) u64 {
        // 2011 / 100000 = 0.02011
        return (amount * SOVEREIGN_TAX_BPS) / 100000;
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

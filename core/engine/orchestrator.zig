const std = @import("std");
const types = @import("../protocol/types.zig");
const billing = @import("../business/billing.zig");
const telemetry = @import("../engine/telemetry.zig");
const http = @import("../net/http.zig");

/// Sovereign Orchestrator (xB77 Back-office)
/// Maneja el ciclo de vida de los agentes y la facturación de recursos.
pub const Orchestrator = struct {
    allocator: std.mem.Allocator,
    manager: billing.BillingManager,
    http_client: http.HttpClient,
    gateway_url: []const u8 = "https://gateway.xb77.com",
    
    // Mapa de balances locales (Cache del Gateway)
    balances: std.AutoHashMapUnmanaged(types.Pubkey, u64),

    pub fn init(allocator: std.mem.Allocator) Orchestrator {
        return .{
            .allocator = allocator,
            .manager = billing.BillingManager.init(allocator),
            .http_client = http.HttpClient.init(allocator),
            .balances = .{},
        };
    }

    pub fn deinit(self: *Orchestrator) void {
        self.balances.deinit(self.allocator);
    }

    /// Sincroniza el balance local con el Gateway.
    pub fn syncBalance(self: *Orchestrator, agent_id: types.Pubkey) !u64 {
        const crypto = @import("../crypto/crypto.zig");
        const agent_id_hex = try crypto.bytesToHex(self.allocator, &agent_id);
        defer self.allocator.free(agent_id_hex);

        const url = try std.fmt.allocPrint(self.allocator, "{s}/balance/{s}", .{self.gateway_url, agent_id_hex});
        defer self.allocator.free(url);

        var resp = try self.http_client.get(url);
        defer resp.deinit();

        if (resp.status == 200) {
            const balance = try std.fmt.parseInt(u64, resp.body, 10);
            try self.balances.put(self.allocator, agent_id, balance);
            return balance;
        }
        return error.GatewaySyncFailed;
    }

    /// Registra el consumo de recursos de un agente y deduce el costo.
    /// Reporta el uso al Gateway para persistencia.
    pub fn processUsage(self: *Orchestrator, agent_id: types.Pubkey, report: telemetry.TelemetryReport) !u64 {
        const cost = report.calculateCost();
        
        var balance = self.balances.get(agent_id) orelse try self.syncBalance(agent_id);
        
        if (balance < cost) {
            return error.InsufficientCredits;
        }

        balance -= cost;
        try self.balances.put(self.allocator, agent_id, balance);

        // --- Report to Gateway (Async / Fire & Forget in real life, sync here for demo) ---
        // In a real SaaS, we would batch these reports.
        
        return balance;
    }

    /// Recibe un depósito (vía Blink/Solana) y actualiza los créditos.
    pub fn creditDeposit(self: *Orchestrator, agent_id: types.Pubkey, lamports: u64) !void {
        const credits = billing.BillingManager.solToCredits(lamports);
        const current = self.balances.get(agent_id) orelse 0;
        try self.balances.put(self.allocator, agent_id, current + credits);
        
        std.debug.print("\n[ORCH  ]  Credit Updated for {x:0>2}{x:0>2}{x:0>2}{x:0>2}...: {d} SC", .{
            agent_id[0], agent_id[1], agent_id[2], agent_id[3], current + credits
        });
    }

    /// Verifica si un agente tiene permitido operar.
    pub fn canOperate(self: *Orchestrator, agent_id: types.Pubkey) bool {
        const balance = self.balances.get(agent_id) orelse (self.syncBalance(agent_id) catch 0);
        return balance >= 50; 
    }
};

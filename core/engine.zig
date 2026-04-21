const std = @import("std");
const core = @import("core.zig");
const builtin = @import("builtin");

const bridge = if (builtin.target.os.tag != .wasi) @import("znode_bridge.zig") else struct {
    pub fn startBridge(_: anytype) !void {}
};

const yellowstone = @import("yellowstone.zig");
const risk = @import("risk.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    ctx: *core.context.AgentContext,
    is_running: bool,

    pub fn init(allocator: std.mem.Allocator, ctx: *core.context.AgentContext) Engine {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .is_running = false,
        };
    }

    /// Inicia el loop de vida del agente.
    pub fn start(self: *Engine) !void {
        self.is_running = true;
        
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);
        const eth_addr = try self.ctx.vaults.ops.address(.base, self.allocator);
        defer self.allocator.free(eth_addr);

        std.debug.print("\n[Engine] xB77 Sovereign Agent - Iniciando v0.1.0\n", .{});
        std.debug.print("         ----------------------------------------\n", .{});
        std.debug.print("         ID Solana: {s}\n", .{sol_addr});
        std.debug.print("         ID EVM:    {s}\n", .{eth_addr});
        if (self.ctx.cdp_client != null) {
            std.debug.print("         Bridge:    Coinbase AgentKit (Active)\n", .{});
        }
        std.debug.print("         ----------------------------------------\n", .{});

        // Carga condicional del bridge de sockets
        if (comptime builtin.target.os.tag != .wasi) {
            try bridge.startBridge(self);
        } else {
            std.debug.print("[Engine] Entorno Edge (WASM) detectado. Modo reactivo limitado.\n", .{});
        }

        while (self.is_running) {
            try self.tick();
            // Latido cada 10 segundos para la demo
            std.Thread.sleep(10 * std.time.ns_per_s);
        }
    }

    fn tick(self: *Engine) !void {
        _ = self;
        // El tick es para tareas de mantenimiento (ej: cada 10s)
    }

    /// Método reactivo llamado por el Z-Node Bridge en tiempo real
    pub fn onNetworkEvent(self: *Engine, event: yellowstone.NetworkEvent) void {
        switch (event.type) {
            .slot => {
                // Heartbeat silencioso del parser
            },
            .transaction => {
                const tx = event.tx orelse return;
                
                std.debug.print("\n[DETECT] ⚡ {s} Event -> {s}...", .{@tagName(event.chain), tx.signature[0..8]});
                
                var sender_hex: [64]u8 = undefined;
                _ = std.fmt.bufPrint(&sender_hex, "{x}", .{tx.sender}) catch return;

                // 1. Verificación de Cumplimiento (Compliance)
                if (!self.ctx.compliance.check(tx)) {
                    std.debug.print("\n[JUDGE ] ❌ FAILED Compliance: Policy mismatch.", .{});
                    return;
                }

                // 2. Evaluación de Riesgo (Risk)
                const risk_score = risk.RiskEngine.assess(tx);
                const risk_label = if (risk_score < 0.3) "LOW" else if (risk_score < 0.6) "MID" else "HIGH";

                // 3. Verificación Constitucional Primaria
                if (!self.ctx.constitution.isActionAllowed(&sender_hex)) {
                    std.debug.print("\n[JUDGE ] ❌ FAILED Constitution: Actor Blacklisted.", .{});
                    return;
                }

                std.debug.print("\n[JUDGE ] ✅ PASSED: Compliance OK | Risk: {s} ({d:.2})", .{risk_label, risk_score});
                std.debug.print("\n[PULSE ] 🧠 Veredicto: Transacción Soberana Aceptada.", .{});
                std.debug.print("\n         ----------------------------------------", .{});
            }
        }
    }

    pub fn stop(self: *Engine) void {
        self.is_running = false;
    }
};

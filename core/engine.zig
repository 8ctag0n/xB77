const std = @import("std");
const core = @import("core.zig");
const builtin = @import("builtin");

const bridge = if (builtin.target.os.tag != .wasi) @import("znode_bridge.zig") else struct {
    pub fn startBridge(_: anytype) !void {}
};

const yellowstone = @import("yellowstone.zig");

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
        std.debug.print("\n[Engine] Agente xB77 operando 24/7...\n", .{});

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
        std.debug.print("[Engine] Heartbeat: Mantenimiento...\n", .{});
    }

    /// Método reactivo llamado por el Z-Node Bridge en tiempo real
    pub fn onNetworkEvent(self: *Engine, event: yellowstone.NetworkEvent) void {
        _ = self;
        switch (event.type) {
            .slot => {
                // std.debug.print("[Engine] 🟢 Network Pulse: Slot {d}\n", .{event.slot});
            },
            .transaction => {
                const tx = event.tx.?;
                std.debug.print("\n[Engine] ⚡️ REFLEX: Pago detectado en tiempo real!\n", .{});
                std.debug.print("         De: {x}\n", .{tx.sender});
                std.debug.print("         Monto: {d} lamports (1.0 SOL)\n", .{tx.amount});
                
                // Aquí el agente dispararía la lógica de respuesta (ej: enviar un producto, actualizar estado)
            }
        }
    }

    pub fn stop(self: *Engine) void {
        self.is_running = false;
    }
};

const std = @import("std");

/// La Constitución es la ley local del agente. 
/// Es evaluada en el "Hot Path" (latencia cero) antes de cualquier acción.
/// El "Cerebro" (LLM) la actualiza en tiempo real vía MCP.
pub const Constitution = struct {
    allocator: std.mem.Allocator,
    max_slippage_bps: u16,
    emergency_stop: bool,
    blocked_contracts: std.StringHashMap(void),
    
    // Mutex para permitir lecturas rápidas y escrituras seguras desde el hilo MCP
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) Constitution {
        return .{
            .allocator = allocator,
            .max_slippage_bps = 100, // 1% default
            .emergency_stop = false,
            .blocked_contracts = std.StringHashMap(void).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Constitution) void {
        self.blocked_contracts.deinit();
    }

    /// Método llamado por el LLM para actualizar las reglas
    pub fn update(self: *Constitution, emergency: bool, slippage: u16) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        self.emergency_stop = emergency;
        self.max_slippage_bps = slippage;
        std.debug.print("\n[⚖️ CONSTITUCIÓN] Reglas actualizadas por el Cerebro. Emergency: {}, Slippage: {d} bps\n", .{emergency, slippage});
    }

    pub fn blockContract(self: *Constitution, contract_address: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const addr_copy = try self.allocator.dupe(u8, contract_address);
        try self.blocked_contracts.put(addr_copy, {});
        std.debug.print("\n[⚖️ CONSTITUCIÓN] Contrato bloqueado por el Cerebro: {s}\n", .{contract_address});
    }

    pub fn isBlocked(self: *Constitution, contract_address: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.blocked_contracts.contains(contract_address);
    }
};

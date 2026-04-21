const std = @import("std");

/// La Constitución es la ley local del agente. 
/// Es evaluada en el "Hot Path" antes de cualquier acción.
pub const Constitution = struct {
    allocator: std.mem.Allocator,
    max_slippage_bps: u16,
    emergency_stop: bool,
    blocked_contracts: std.StringHashMap(void),
    
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
        var iter = self.blocked_contracts.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.blocked_contracts.deinit();
    }

    pub fn update(self: *Constitution, emergency: bool, slippage: u16) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        self.emergency_stop = emergency;
        self.max_slippage_bps = slippage;
        std.debug.print("[Constitution] Update: Emergency={}, Slippage={d}bps\n", .{emergency, slippage});
    }

    pub fn blockContract(self: *Constitution, contract_address: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.blocked_contracts.contains(contract_address)) return;

        const addr_copy = try self.allocator.dupe(u8, contract_address);
        try self.blocked_contracts.put(addr_copy, {});
        std.debug.print("[Constitution] Contract blocked: {s}\n", .{contract_address});
    }

    pub fn isActionAllowed(self: *Constitution, target_address: ?[]const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.emergency_stop) return false;

        if (target_address) |addr| {
            if (self.blocked_contracts.contains(addr)) return false;
        }

        return true;
    }
};

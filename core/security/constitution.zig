const std = @import("std");

/// La Constitución es la ley local del agente. 
/// Es evaluada en el "Hot Path" antes de cualquier acción.
pub const Constitution = struct {
    allocator: std.mem.Allocator,
    max_slippage_bps: u16,
    emergency_stop: bool,
    blocked_contracts: std.StringHashMap(void),
    rules: std.ArrayListUnmanaged([]const u8),
    
    // --- xB77 Frontier Dynamic Policies ---
    required_sns_namespace: ?[]const u8 = null, // Opt-in: e.g. "*.agent.sol"
    force_hft_rail: bool = false,               // Opt-in: force MagicBlock PER
    guardian_threshold_lamports: u64 = 5_000_000_000, // Default: 5 SOL
    
    mutex: std.Io.Mutex,

    pub fn init(allocator: std.mem.Allocator) Constitution {
        return .{
            .allocator = allocator,
            .max_slippage_bps = 100, // 1% default
            .emergency_stop = false,
            .blocked_contracts = std.StringHashMap(void).init(allocator),
            .rules = std.ArrayListUnmanaged([]const u8).empty,
            .mutex = .init,
        };
    }

    pub fn deinit(self: *Constitution) void {
        var it = self.blocked_contracts.keyIterator();
        while (it.next()) |k| {
            self.allocator.free(k.*);
        }
        self.blocked_contracts.deinit();
        for (self.rules.items) |r| self.allocator.free(r);
        self.rules.deinit(self.allocator);
        if (self.required_sns_namespace) |ns| self.allocator.free(ns);
    }

    pub fn blockContract(self: *Constitution, address: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        const copy = try self.allocator.dupe(u8, address);
        try self.blocked_contracts.put(copy, {});
    }

    pub fn isBlocked(self: *Constitution, address: []const u8) bool {
        const io = std.Io.Threaded.global_single_threaded.io();
        self.mutex.lock(io) catch return true; // Fail safe
        defer self.mutex.unlock(io);
        return self.blocked_contracts.contains(address);
    }

    pub fn update(self: *Constitution, emergency_stop: bool, max_slippage_bps: u16) void {
        self.emergency_stop = emergency_stop;
        self.max_slippage_bps = max_slippage_bps;
    }

    pub fn isActionAllowed(self: *Constitution, address: []const u8) bool {
        return !self.isBlocked(address) and !self.emergency_stop;
    }

    pub fn validateToll(self: *const Constitution, amount: u64, memo: []const u8) bool {
        _ = memo;
        if (self.emergency_stop) return false;
        return amount <= self.guardian_threshold_lamports;
    }

    pub fn addRule(self: *Constitution, rule: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        const copy = try self.allocator.dupe(u8, rule);
        try self.rules.append(self.allocator, copy);
    }
};

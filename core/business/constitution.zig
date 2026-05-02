const std = @import("std");

/// La Constitución es la ley local del agente. 
/// Es evaluada en el "Hot Path" antes de cualquier acción.
pub const Constitution = struct {
    allocator: std.mem.Allocator,
    max_slippage_bps: u16,
    emergency_stop: bool,
    blocked_contracts: std.StringHashMap(void),
    rules: std.ArrayListUnmanaged([]const u8),
    
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) Constitution {
        return .{
            .allocator = allocator,
            .max_slippage_bps = 100, // 1% default
            .emergency_stop = false,
            .blocked_contracts = std.StringHashMap(void).init(allocator),
            .rules = .{},
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Constitution) void {
        var iter = self.blocked_contracts.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.blocked_contracts.deinit();

        for (self.rules.items) |rule| {
            self.allocator.free(rule);
        }
        self.rules.deinit(self.allocator);
    }

    pub fn addRule(self: *Constitution, rule: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const copy = try self.allocator.dupe(u8, rule);
        try self.rules.append(self.allocator, copy);
    }

    /// RAG-Lite: Returns rules that match keywords in the query.
    pub fn getPolicyRoot(self: *Constitution) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (self.rules.items) |rule| {
            hasher.update(rule);
        }
        return hasher.finalResult();
    }
    /// RAG-Lite: Returns rules that match keywords in the query.
    pub fn queryRules(self: *Constitution, query: []const u8) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var matches = std.ArrayListUnmanaged([]const u8){};
        defer matches.deinit(self.allocator);

        const query_lower = try self.allocator.alloc(u8, query.len);
        defer self.allocator.free(query_lower);
        for (query, 0..) |c, i| query_lower[i] = std.ascii.toLower(c);

        for (self.rules.items) |rule| {
            const rule_lower = try self.allocator.alloc(u8, rule.len);
            defer self.allocator.free(rule_lower);
            for (rule, 0..) |c, i| rule_lower[i] = std.ascii.toLower(c);

            // Tokenize query and check for overlap with rule
            var it = std.mem.tokenizeAny(u8, query_lower, " :;,\r\n\t");
            var found = false;
            while (it.next()) |token| {
                if (token.len < 3) continue; // Allow 'sol', 'eth', etc.
                if (std.mem.indexOf(u8, rule_lower, token) != null) {
                    found = true;
                    break;
                }
            }

            if (found or std.mem.indexOf(u8, query_lower, rule_lower) != null) {
                try matches.append(self.allocator, try self.allocator.dupe(u8, rule));
            }
        }
        return try self.allocator.dupe([]const u8, matches.items);
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

    pub fn validateToll(self: *const Constitution, amount: u64, memo: []const u8) bool {
        _ = self;
        _ = memo;
        // Regla constitucional: No pagar más de 1000 créditos por una sola operación de infraestructura
        return amount <= 1000;
    }
};

const std = @import("std");
const core = @import("core.zig");
const store = @import("store.zig");

pub const SwarmMetrics = struct {
    health: f32,
    volume: u64,
    event_count: usize,
    agent_count: usize,
};

pub const Decision = enum {
    none,
    expand,
    shrink,
    harden_policies,
    compress_state,
};

pub const Strategist = struct {
    allocator: std.mem.Allocator,
    store: *store.Store,

    pub fn init(allocator: std.mem.Allocator, s: *store.Store) Strategist {
        return .{
            .allocator = allocator,
            .store = s,
        };
    }

    pub fn analyze(self: *Strategist, agent_count: usize) !struct { decision: Decision, metrics: SwarmMetrics } {
        const history = try self.store.getHistory(self.allocator);
        defer {
            for (history) |entry| {
                self.allocator.free(entry.description);
                self.allocator.free(entry.tx_hash);
            }
            self.allocator.free(history);
        }

        var success_count: u32 = 0;
        var fail_count: u32 = 0;
        var total_volume: u64 = 0;

        for (history) |entry| {
            switch (entry.entry_type) {
                .audit, .match, .receipt => {
                    success_count += 1;
                    total_volume += entry.amount;
                },
                .compliance_fail, .risk_blocked => fail_count += 1,
                else => {},
            }
        }

        const health = if (success_count + fail_count > 0) 
            @as(f32, @floatFromInt(success_count)) / @as(f32, @floatFromInt(success_count + fail_count))
            else 1.0;

        const metrics = SwarmMetrics{
            .health = health,
            .volume = total_volume,
            .event_count = history.len,
            .agent_count = agent_count,
        };

        var decision: Decision = .none;

        if (health < 0.7) {
            decision = .harden_policies;
        } else if (total_volume > 1_000_000_000) { // > 1 SOL
            decision = .compress_state;
        } else if (agent_count > 3) {
            decision = .shrink;
        } else if (health > 0.9 and total_volume > 100_000_000) { // > 0.1 SOL
            decision = .expand;
        }

        return .{ .decision = decision, .metrics = metrics };
    }
};

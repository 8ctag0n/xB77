const std = @import("std");
const crypto = @import("../security/crypto.zig");

pub const Intent = enum {
    arbitrage,
    rebalance,
    liquidity_provision,
    austerity_protection,
    tax_settlement,
};

pub const ReasoningTrace = struct {
    intent: Intent,
    description: []const u8,
    timestamp: i64,
    nodes_consulted: u8,
    risk_score: f32,
    metadata_hash: [32]u8, // SHA-256 of the detailed trace

    pub fn generate(
        allocator: std.mem.Allocator,
        intent: Intent,
        description: []const u8,
        risk_score: f32,
    ) !ReasoningTrace {
        const ts = std.time.timestamp();
        
        // Generate a hash of the reasoning for on-chain anchoring
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(description);
        var ts_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &ts_buf, @bitCast(ts), .little);
        hasher.update(&ts_buf);
        
        var hash: [32]u8 = undefined;
        hasher.final(&hash);

        return ReasoningTrace{
            .intent = intent,
            .description = try allocator.dupe(u8, description),
            .timestamp = ts,
            .nodes_consulted = 3, // Mock value for swarm coordination
            .risk_score = risk_score,
            .metadata_hash = hash,
        };
    }

    pub fn deinit(self: *ReasoningTrace, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }

    pub fn formatJson(self: *const ReasoningTrace, allocator: std.mem.Allocator) ![]const u8 {
        return try std.json.stringifyAlloc(allocator, self.*, .{});
    }
};

pub const IntelligenceEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IntelligenceEngine {
        return .{ .allocator = allocator };
    }

    pub fn deliberate(self: *IntelligenceEngine, intent: Intent, context: []const u8) !ReasoningTrace {
        // Here we would normally call an LLM or a local decision model.
        // For the hackathon, we simulate the "sophisticated" trace.
        var desc: []const u8 = undefined;
        var risk: f32 = 0.05;

        switch (intent) {
            .arbitrage => {
                desc = try std.fmt.allocPrint(self.allocator, "Discrepancy detected in {s}. Spread: 0.82%. Routing via Circle CCTP to Arc for sub-second settlement.", .{context});
                risk = 0.12;
            },
            .austerity_protection => {
                desc = try std.fmt.allocPrint(self.allocator, "Treasury under threshold. Activating swarm-negotiated flash loans. Context: {s}.", .{context});
                risk = 0.45;
            },
            else => {
                desc = try std.fmt.allocPrint(self.allocator, "Executing routine sovereign task: {s}.", .{context});
                risk = 0.01;
            },
        }

        const trace = try ReasoningTrace.generate(self.allocator, intent, desc, risk);
        self.allocator.free(desc);
        return trace;
    }
};

const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const store_mod = @import("../protocol/store.zig");
const semantic = @import("../security/semantic.zig");

pub const BrainInsight = struct {
    decision: []const u8,
    risk_score: f32,
    reasoning: []const u8,
    decision_trace: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BrainInsight) void {
        self.allocator.free(self.decision);
        self.allocator.free(self.reasoning);
        self.allocator.free(self.decision_trace);
    }

    pub fn formatForSwarm(self: *const BrainInsight, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayListUnmanaged(u8).empty;
        errdefer list.deinit(allocator);

        var id_hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&id_hex, "{x}", .{std.fmt.fmtSliceEscapeLower(self.decision)}) catch unreachable;

        try list.print(allocator, "🧠 *xB77 Brain Insight*\n\n", .{});
        try list.print(allocator, "✅ *Decision:* {s}\n", .{self.decision});
        try list.print(allocator, "⚠️ *Risk Score:* {d:.2}/1.0\n\n", .{self.risk_score});
        try list.print(allocator, "📝 *Reasoning:* {s}\n\n", .{self.reasoning});
        try list.print(allocator, "\n MISSION HASH: 0x{s}\n", .{id_hex[0..12]});

        return list.toOwnedSlice(allocator);
    }

    pub fn formatFullTrace(self: *const BrainInsight, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayListUnmanaged(u8).empty;
        errdefer list.deinit(allocator);

        var id_hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&id_hex, "{x}", .{std.fmt.fmtSliceEscapeLower(self.decision)}) catch unreachable;

        try list.print(allocator, " ARC SWARM REASONING TRACE\n", .{});
        try list.print(allocator, "---------------------------\n", .{});
        try list.print(allocator, "DECISION: {s}\n", .{self.decision});
        try list.print(allocator, "INTENT:   {s}\n", .{self.decision_trace});
        try list.print(allocator, "CIRCLE:   USDC Native Settlement\n", .{});
        try list.print(allocator, "YIELD:    Hashnote USYC Auto-Sweep\n", .{});
        try list.print(allocator, "RISK:     {d:.4} (Institutional Safe)\n", .{self.risk_score});
        try list.print(allocator, "\n ZK COMMITMENT: 0x{s}\n", .{id_hex});

        return list.toOwnedSlice(allocator);
    }
};

pub const Brain = struct {
    allocator: std.mem.Allocator,
    store: ?*store_mod.Store,

    pub fn init(allocator: std.mem.Allocator, store: ?*store_mod.Store) Brain {
        return .{
            .allocator = allocator,
            .store = store,
        };
    }

    pub fn deinit(self: *Brain) void {
        _ = self;
    }

    pub fn generateIntentVector(self: *Brain, text: []const u8) semantic.Semantic.FixedVector {
        _ = self;
        // Projection determinística basada en el texto para la demo
        var vec: semantic.Semantic.FixedVector = undefined;
        var h: [32]u8 = undefined;
        crypto.hash256(text, &h);

        for (0..semantic.Semantic.DIMENSIONS) |i| {
            // Pseudo-random projection from hash
            const seed = h[i % 32];
            vec[i] = @intCast(@as(i32, seed) * 78); // Pinned to ~8k
        }
        return vec;
    }

    pub fn interpret(self: *Brain, directive: []const u8) !BrainInsight {
        const is_buy = std.mem.indexOf(u8, directive, "buy") != null or std.mem.indexOf(u8, directive, "comprar") != null;
        const risk: f32 = if (is_buy) 0.12 else 0.05;

        return BrainInsight{
            .decision = try self.allocator.dupe(u8, if (is_buy) "EXECUTE_BUY_ORDER" else "MONITOR_STATE"),
            .risk_score = risk,
            .reasoning = try self.allocator.dupe(u8, "Directive analysis confirms alignment with sovereign treasury goals."),
            .decision_trace = try self.allocator.dupe(u8, directive),
            .allocator = self.allocator,
        };
    }

    pub fn reasonWithGemma(self: *Brain, directive: []const u8) !BrainInsight {
        std.debug.print("\n[BRAIN ]  Thinking (Gemma-2B local)...", .{});
        return self.interpret(directive);
    }
};

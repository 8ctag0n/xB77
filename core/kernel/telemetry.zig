const std = @import("std");
const billing = @import("../commerce/billing.zig");

pub const TelemetryReport = struct {
    compute_ms: u64,
    rpc_calls: u32,
    ai_tokens: u32,
    timestamp: i64,
    
    pub fn calculateCost(self: TelemetryReport) u64 {
        // Modelo Deluxe (2.22% protocol margin)
        // Costes base (en Sovereign Credits):
        // - 1 ms compute = 1 SC
        // - 1000 AI tokens = 5 SC
        // - 1 RPC call = 10 SC
        const base_cost = self.compute_ms * 1 + (self.ai_tokens * 5 / 1000) + (self.rpc_calls * 10);
        
        // Protocol Margin: 2.22% (222 / 10000)
        const margin = (base_cost * 222) / 10000;
        
        return base_cost + margin;
    }
};

pub const TelemetryHub = struct {
    allocator: std.mem.Allocator,
    start_time: i64 = 0,
    rpc_count: u32 = 0,
    token_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) TelemetryHub {
        return .{ .allocator = allocator };
    }

    pub fn startSession(self: *TelemetryHub) void {
        self.start_time = std.time.milliTimestamp();
        self.rpc_count = 0;
        self.token_count = 0;
    }

    pub fn recordRpc(self: *TelemetryHub) void {
        self.rpc_count += 1;
    }

    pub fn recordTokens(self: *TelemetryHub, count: u32) void {
        self.token_count += count;
    }

    pub fn endSession(self: *TelemetryHub) TelemetryReport {
        const end_time = std.time.milliTimestamp();
        return TelemetryReport{
            .compute_ms = @intCast(end_time - self.start_time),
            .rpc_calls = self.rpc_count,
            .ai_tokens = self.token_count,
            .timestamp = end_time,
        };
    }
};

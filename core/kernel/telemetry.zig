const std = @import("std");
const billing = @import("../commerce/billing.zig");

pub const TelemetryReport = struct {
    compute_ms: u64,
    rpc_calls: u32,
    ai_tokens: u32,
    timestamp: i64,
    
    pub fn calculateCost(self: TelemetryReport) u64 {
        _ = self;
        // En el modelo Deluxe All-Inclusive (2.011%), no cobramos por 
        // MS de cómputo o tokens de inferencia. El tax se captura 
        // exclusivamente en los pagos económicos (Sovereign Tax).
        return 0;
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

const std = @import("std");
const types = @import("types.zig");

pub const RiskLevel = enum {
    low,
    medium,
    high,
    critical
};

pub const AuditReport = struct {
    score: u8, // 0-100
    level: RiskLevel,
    flags: [][]const u8,
    passed: bool,
    timestamp: u64,
};

pub const RiskScorer = struct {
    allocator: std.mem.Allocator,

    // Direcciones de mixers conocidos (Ejemplos para la demo)
    pub const KNOWN_MIXERS = [_][]const u8{
        "67p69nUfQunq1YJmP6K3R4A2rKaxN6K4zYQY4pY7nABC", // Falso Tornado
    };

    pub fn init(allocator: std.mem.Allocator) RiskScorer {
        return .{ .allocator = allocator };
    }

    /// Analiza una transacción antes de que el Agente la firme
    pub fn assess(self: *RiskScorer, recipient: types.Pubkey, amount: u64) !AuditReport {
        _ = amount;
        
        // 1. Convertir Pubkey a String para comparar
        const crypto = @import("crypto.zig");
        const recipient_str = try crypto.pubkeyToString(self.allocator, &recipient);
        defer self.allocator.free(recipient_str);

        // 2. Check Mixers
        for (KNOWN_MIXERS) |mixer| {
            if (std.mem.eql(u8, recipient_str, mixer)) {
                var flags = try self.allocator.alloc([]const u8, 1);
                flags[0] = try self.allocator.dupe(u8, "RECIPIENT_IS_KNOWN_MIXER");
                
                return AuditReport{
                    .score = 100, // Riesgo máximo
                    .level = .critical,
                    .flags = flags,
                    .passed = false,
                    .timestamp = @intCast(std.time.milliTimestamp()),
                };
            }
        }

        return AuditReport{
            .score = 0,
            .level = .low,
            .flags = &[_][]const u8{},
            .passed = true,
            .timestamp = @intCast(std.time.milliTimestamp()),
        };
    }
};

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

    pub const MIXERS_SOL = [_][]const u8{
        "67p69nUfQunq1YJmP6K3R4A2rKaxN6K4zYQY4pY7nABC",
    };

    pub const MIXERS_EVM = [_][]const u8{
        "0x7777777777777777777777777777777777777777", // Mock Tornado
    };

    pub fn init(allocator: std.mem.Allocator) RiskScorer {
        return .{ .allocator = allocator };
    }

    pub const Recipient = union(enum) {
        sol: types.Pubkey,
        evm: types.EthAddress,
    };

    /// Analiza una transacción antes de que el Agente la firme
    pub fn assess(self: *RiskScorer, recipient: Recipient, amount: u64) !AuditReport {
        _ = amount;
        const crypto = @import("crypto.zig");
        
        var recipient_str: []u8 = undefined;
        var mixers: []const []const u8 = undefined;

        switch (recipient) {
            .sol => |pk| {
                recipient_str = try crypto.pubkeyToString(self.allocator, &pk);
                mixers = &MIXERS_SOL;
            },
            .evm => |addr| {
                recipient_str = try crypto.encodeEthAddress(self.allocator, addr);
                mixers = &MIXERS_EVM;
            },
        }
        defer self.allocator.free(recipient_str);

        // 2. Check Mixers
        for (mixers) |mixer| {
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

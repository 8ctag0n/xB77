const std = @import("std");

pub const Config = struct {
    rpc: struct {
        solana: []const u8,
        base: []const u8,
    },
    vaults: struct {
        path: []const u8,
    },
    cdp: struct {
        key_name: ?[]const u8 = null,
        key_secret: ?[]const u8 = null,
    },
    facilitator: ?[]const u8 = null,

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return Config{
                    .rpc = .{
                        .solana = try allocator.dupe(u8, "https://api.devnet.solana.com"),
                        .base = try allocator.dupe(u8, "https://sepolia.base.org"),
                    },
                    .vaults = .{
                        .path = try allocator.dupe(u8, "./.xb77"),
                    },
                    .cdp = .{ .key_name = null, .key_secret = null },
                };
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 10 * 1024);
        defer allocator.free(content);

        var config = Config{
            .rpc = .{
                .solana = try allocator.dupe(u8, "https://api.devnet.solana.com"),
                .base = try allocator.dupe(u8, "https://sepolia.base.org"),
            },
            .vaults = .{
                .path = try allocator.dupe(u8, "./.xb77"),
            },
            .cdp = .{ .key_name = null, .key_secret = null },
            .facilitator = null,
        };

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            var parts = std.mem.splitScalar(u8, trimmed, '=');
            const key = std.mem.trim(u8, parts.next() orelse continue, " ");
            const val_raw = std.mem.trim(u8, parts.next() orelse continue, " ");
            const val = std.mem.trim(u8, val_raw, "\"");

            if (std.mem.eql(u8, key, "rpc_solana")) {
                allocator.free(config.rpc.solana);
                config.rpc.solana = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "rpc_base")) {
                allocator.free(config.rpc.base);
                config.rpc.base = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "vault_path")) {
                allocator.free(config.vaults.path);
                config.vaults.path = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "cdp_key_name")) {
                config.cdp.key_name = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "cdp_key_secret")) {
                config.cdp.key_secret = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "facilitator")) {
                config.facilitator = try allocator.dupe(u8, val);
            }
        }

        return config;
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.rpc.solana);
        allocator.free(self.rpc.base);
        allocator.free(self.vaults.path);
        if (self.cdp.key_name) |k| allocator.free(k);
        if (self.cdp.key_secret) |k| allocator.free(k);
        if (self.facilitator) |f| allocator.free(f);
    }
};

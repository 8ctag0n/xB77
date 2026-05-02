const std = @import("std");

pub const Config = struct {
    name: ?[]const u8 = null,
    rpc: struct {
        solana: []const u8,
        base: []const u8,
    },
    vaults: struct {
        path: []const u8,
    },
    mnemonic: ?[]const u8 = null,
    mesh_port: u16 = 7777,
    portal_port: u16 = 8081,
    cdp: struct {
        key_name: ?[]const u8 = null,
        key_secret: ?[]const u8 = null,
    },
    ipfs: struct {
        endpoint: []const u8,
        api_key: []const u8,
    },
    registry_program_id: ?[]const u8 = null,
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
                    .mnemonic = null,
                    .ipfs = .{
                        .endpoint = try allocator.dupe(u8, "https://api.quicknode.com/ipfs/v1/"),
                        .api_key = try allocator.dupe(u8, ""),
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
            .name = null,
            .rpc = .{
                .solana = try allocator.dupe(u8, "https://api.devnet.solana.com"),
                .base = try allocator.dupe(u8, "https://sepolia.base.org"),
            },
            .vaults = .{
                .path = try allocator.dupe(u8, "./.xb77"),
            },
            .mnemonic = null,
            .ipfs = .{
                .endpoint = try allocator.dupe(u8, "https://api.quicknode.com/ipfs/v1/"),
                .api_key = try allocator.dupe(u8, ""),
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

            if (std.mem.eql(u8, key, "name")) {
                config.name = try allocator.dupe(u8, val);
            }
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
            if (std.mem.eql(u8, key, "mnemonic")) {
                config.mnemonic = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "mesh_port")) {
                config.mesh_port = std.fmt.parseInt(u16, val, 10) catch 7777;
            }
            if (std.mem.eql(u8, key, "portal_port")) {
                config.portal_port = std.fmt.parseInt(u16, val, 10) catch 8081;
            }
            if (std.mem.eql(u8, key, "cdp_key_name")) {
                config.cdp.key_name = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "cdp_key_secret")) {
                config.cdp.key_secret = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "ipfs_endpoint")) {
                allocator.free(config.ipfs.endpoint);
                config.ipfs.endpoint = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "ipfs_api_key")) {
                allocator.free(config.ipfs.api_key);
                config.ipfs.api_key = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "registry_program_id")) {
                config.registry_program_id = try allocator.dupe(u8, val);
            }
            if (std.mem.eql(u8, key, "facilitator")) {
                config.facilitator = try allocator.dupe(u8, val);
            }
        }

        return config;
    }

    pub fn save(self: *const Config, allocator: std.mem.Allocator, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const writer = file.writer();

        try writer.print("# xB77 Sovereign Agent Configuration\n", .{});
        if (self.name) |n| try writer.print("name = \"{s}\"\n", .{n});
        try writer.print("rpc_solana = \"{s}\"\n", .{self.rpc.solana});
        try writer.print("rpc_base = \"{s}\"\n", .{self.rpc.base});
        try writer.print("vault_path = \"{s}\"\n", .{self.vaults.path});
        if (self.mnemonic) |m| try writer.print("mnemonic = \"{s}\"\n", .{m});
        try writer.print("mesh_port = {d}\n", .{self.mesh_port});
        try writer.print("portal_port = {d}\n", .{self.portal_port});
        if (self.cdp.key_name) |k| try writer.print("cdp_key_name = \"{s}\"\n", .{k});
        if (self.cdp.key_secret) |k| try writer.print("cdp_key_secret = \"{s}\"\n", .{k});
        try writer.print("ipfs_endpoint = \"{s}\"\n", .{self.ipfs.endpoint});
        try writer.print("ipfs_api_key = \"{s}\"\n", .{self.ipfs.api_key});
        if (self.registry_program_id) |p| try writer.print("registry_program_id = \"{s}\"\n", .{p});
        if (self.facilitator) |f| try writer.print("facilitator = \"{s}\"\n", .{f});

        _ = allocator;
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        if (self.name) |n| allocator.free(n);
        allocator.free(self.rpc.solana);
        allocator.free(self.rpc.base);
        allocator.free(self.vaults.path);
        allocator.free(self.ipfs.endpoint);
        allocator.free(self.ipfs.api_key);
        if (self.mnemonic) |m| allocator.free(m);
        if (self.cdp.key_name) |k| allocator.free(k);
        if (self.cdp.key_secret) |k| allocator.free(k);
        if (self.registry_program_id) |p| allocator.free(p);
        if (self.facilitator) |f| allocator.free(f);
    }
};

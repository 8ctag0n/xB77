const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("types.zig");
const solana = @import("solana.zig");

pub const VaultRole = enum {
    ops,
    reserve,
    yield,
};

pub const SpendPolicy = struct {
    daily_limit: u64,
    per_tx_limit: u64,
    governance_threshold: ?u64 = null,
    allowed_assets: []const types.Asset = &.{},
    blacklist: std.AutoHashMap(types.Pubkey, void),
};

pub const SpendRecord = struct {
    timestamp: i64,
    amount: u64,
    asset: types.Asset,
};

pub const Vault = struct {
    allocator: std.mem.Allocator,
    role: VaultRole,
    sol_kp: types.Keypair,
    eth_kp: ?types.EthKeypair = null,
    policy: SpendPolicy,
    history: std.ArrayListUnmanaged(SpendRecord),
    storage_path: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, role: VaultRole, policy: SpendPolicy, storage_path: []const u8) !Vault {
        var v = Vault{
            .allocator = allocator,
            .role = role,
            .sol_kp = crypto.generateKeypair(),
            .eth_kp = null,
            .policy = policy,
            .history = std.ArrayListUnmanaged(SpendRecord){},
            .storage_path = try allocator.dupe(u8, storage_path),
        };
        try v.loadHistory();
        return v;
    }

    pub fn deinit(self: *Vault) void {
        self.history.deinit(self.allocator);
        self.policy.blacklist.deinit();
        self.allocator.free(self.storage_path);
    }

    fn loadHistory(self: *Vault) !void {
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch return;
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var iter = std.mem.splitScalar(u8, line, ',');
            const ts_str = iter.next() orelse continue;
            const amt_str = iter.next() orelse continue;
            const sym = iter.next() orelse "SOL";

            const ts = std.fmt.parseInt(i64, ts_str, 10) catch continue;
            const amt = std.fmt.parseInt(u64, amt_str, 10) catch continue;

            try self.history.append(self.allocator, .{
                .timestamp = ts,
                .amount = amt,
                .asset = .{ .chain = .solana, .symbol = try self.allocator.dupe(u8, sym) },
            });
        }
    }

    pub fn address(self: *const Vault, chain: types.Chain, allocator: std.mem.Allocator) ![]u8 {
        return switch (chain) {
            .solana => crypto.pubkeyToString(allocator, &self.sol_kp.public),
            .base, .arbitrum => if (self.eth_kp) |kp| 
                @import("evm.zig").addressToHex(allocator, kp.address)
            else 
                error.EthKeypairNotInitialized,
        };
    }

    pub fn canSpend(self: *Vault, amount: u64, asset: types.Asset, recipient: ?types.Pubkey) !bool {
        if (recipient) |r| {
            if (self.policy.blacklist.contains(r)) return false;
        }

        if (amount > self.policy.per_tx_limit) return false;

        const now = std.time.milliTimestamp();
        const one_day_ms = 24 * 60 * 60 * 1000;
        var spent_today: u64 = 0;

        var i: usize = 0;
        while (i < self.history.items.len) : (i += 1) {
            const record = self.history.items[i];
            if (now - record.timestamp < one_day_ms and std.mem.eql(u8, record.asset.symbol, asset.symbol)) {
                spent_today += record.amount;
            }
        }

        if (spent_today + amount > self.policy.daily_limit) return false;
        return true;
    }

    pub fn recordSpend(self: *Vault, amount: u64, asset: types.Asset) !void {
        const ts = std.time.milliTimestamp();
        try self.history.append(self.allocator, .{
            .timestamp = ts,
            .amount = amount,
            .asset = asset,
        });

        const file = try std.fs.cwd().createFile(self.storage_path, .{ .truncate = false });
        defer file.close();
        try file.seekFromEnd(0);
        
        var fmt_buf: [256]u8 = undefined;
        const line = try std.fmt.bufPrint(&fmt_buf, "{d},{d},{s}\n", .{ ts, amount, asset.symbol });
        try file.writeAll(line);
    }
};

pub const VaultSet = struct {
    ops: Vault,
    reserve: Vault,
    yield: Vault,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !VaultSet {
        const default_policy = SpendPolicy{
            .daily_limit = 1_000_000_000,
            .per_tx_limit = 500_000_000,
            .blacklist = std.AutoHashMap(types.Pubkey, void).init(allocator),
        };
        return .{
            .allocator = allocator,
            .ops = try Vault.init(allocator, .ops, default_policy, "ops_vault.csv"),
            .reserve = try Vault.init(allocator, .reserve, default_policy, "reserve_vault.csv"),
            .yield = try Vault.init(allocator, .yield, default_policy, "yield_vault.csv"),
        };
    }

    pub fn deinit(self: *VaultSet) void {
        self.ops.deinit();
        self.reserve.deinit();
        self.yield.deinit();
    }
};

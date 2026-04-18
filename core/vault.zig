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
    
    pub fn init(allocator: std.mem.Allocator, role: VaultRole, policy: SpendPolicy) Vault {
        return .{
            .allocator = allocator,
            .role = role,
            .sol_kp = crypto.generateKeypair(),
            .eth_kp = null,
            .policy = policy,
            .history = std.ArrayListUnmanaged(SpendRecord){},
        };
    }

    pub fn deinit(self: *Vault) void {
        self.history.deinit(self.allocator);
        self.policy.blacklist.deinit();
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
        try self.history.append(self.allocator, .{
            .timestamp = std.time.milliTimestamp(),
            .amount = amount,
            .asset = asset,
        });
    }
};

pub const VaultSet = struct {
    ops: Vault,
    reserve: Vault,
    yield: Vault,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VaultSet {
        const default_policy = SpendPolicy{
            .daily_limit = 1_000_000_000,
            .per_tx_limit = 500_000_000,
            .blacklist = std.AutoHashMap(types.Pubkey, void).init(allocator),
        };
        return .{
            .allocator = allocator,
            .ops = Vault.init(allocator, .ops, default_policy),
            .reserve = Vault.init(allocator, .reserve, default_policy),
            .yield = Vault.init(allocator, .yield, default_policy),
        };
    }

    pub fn deinit(self: *VaultSet) void {
        self.ops.deinit();
        self.reserve.deinit();
        self.yield.deinit();
    }
};

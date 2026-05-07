const std = @import("std");
const types = @import("../protocol/types.zig");
const awp = @import("../protocol/awp.zig");

pub const IAppRouter = struct {
    ptr: *anyopaque,
    lockFundsFn: *const fn (ptr: *anyopaque, hire_id: [32]u8, amount: u64, asset: types.Asset) anyerror![]const u8,

    pub fn lockFunds(self: IAppRouter, hire_id: [32]u8, amount: u64, asset: types.Asset) ![]const u8 {
        return self.lockFundsFn(self.ptr, hire_id, amount, asset);
    }
};

pub const RecurringPlan = struct {
    plan_id: [32]u8,
    asset: types.Asset,
    amount_per_period: u64,
    period_sec: u64,
    max_periods: u32,
    current_period: u32 = 0,
};

pub const AppManager = struct {
    allocator: std.mem.Allocator,
    router: ?IAppRouter,
    plans: std.AutoHashMapUnmanaged([32]u8, RecurringPlan),

    pub fn init(allocator: std.mem.Allocator, router: ?IAppRouter) AppManager {
        return .{
            .allocator = allocator,
            .router = router,
            .plans = .{},
        };
    }

    pub fn deinit(self: *AppManager) void {
        self.plans.deinit(self.allocator);
    }

    pub fn createPlan(self: *AppManager, asset: types.Asset, amount: u64, period_sec: u64, max_periods: u32) !RecurringPlan {
        var plan_id: [32]u8 = undefined;
        std.crypto.random.bytes(&plan_id);

        const plan = RecurringPlan{
            .plan_id = plan_id,
            .asset = asset,
            .amount_per_period = amount,
            .period_sec = period_sec,
            .max_periods = max_periods,
        };

        try self.plans.put(self.allocator, plan_id, plan);
        return plan;
    }

    pub fn createQuote(self: *AppManager, service_id: []const u8, amount: u64, expiry: u64) !awp.AppQuoteMsg {
        _ = self; _ = service_id;
        var quote_id: [32]u8 = undefined;
        std.crypto.random.bytes(&quote_id);

        return awp.AppQuoteMsg{
            .quote_id = quote_id,
            .asset = .{ .chain = .solana, .symbol = "SOL" },
            .price = amount,
            .expiry = expiry,
        };
    }

    pub fn acceptQuote(self: *AppManager, quote: awp.AppQuoteMsg) !awp.AppHireMsg {
        _ = self;
        var hire_id: [32]u8 = undefined;
        std.crypto.random.bytes(&hire_id);

        return awp.AppHireMsg{
            .hire_id = hire_id,
            .quote_id = quote.quote_id,
            .escrow_amount = quote.price,
        };
    }

    pub fn handleHire(self: *AppManager, hire: awp.AppHireMsg) !void {
        _ = self; _ = hire;
        std.debug.print("\n[APP]  Service Contract Confirmed. Standing by for escrow...", .{});
    }
};

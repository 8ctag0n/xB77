const std = @import("std");
const types = @import("../protocol/types.zig");

pub const ChainAction = union(enum) {
    transfer: struct {
        to: []const u8,
        amount: u64,
    },
    swap: struct {
        from_asset: []const u8,
        to_asset: []const u8,
        amount: u64,
        slippage_bps: u16 = 50, // 0.5% por defecto
    },
    rebalance: struct {
        targets: []const struct {
            asset: []const u8,
            percentage: u8, // 0-100
        },
    },
    stake: struct {
        amount: u64,
        validator: ?[]const u8 = null,
    },
    prediction: struct {
        market: []const u8,
        outcome: []const u8,
        amount: u64,
    },
    leverage: struct {
        asset: []const u8,
        direction: enum { long, short },
        ratio: u8,
        amount: u64,
    },
};

pub const ChainProvider = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        get_balance: *const fn (ctx: *anyopaque, addr: []const u8) anyerror!u128,
        send_tx: *const fn (ctx: *anyopaque, action: ChainAction) anyerror![]const u8,
        get_address: *const fn (ctx: *anyopaque) []const u8,
    };

    pub fn getBalance(self: ChainProvider, addr: []const u8) !u128 {
        return self.vtable.get_balance(self.ptr, addr);
    }

    pub fn sendTx(self: ChainProvider, action: ChainAction) ![]const u8 {
        return self.vtable.send_tx(self.ptr, action);
    }

    pub fn getAddress(self: ChainProvider) []const u8 {
        return self.vtable.get_address(self.ptr);
    }
};

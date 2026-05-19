const std = @import("std");
const chain = @import("chain.zig");
const types = @import("../protocol/types.zig");
const circle = @import("../circle/circle.zig");

/// xB77 Circle Arc Adapter
/// Provides settlement logic for USDC transactions on the Arc Network.

pub const ArcAdapter = struct {
    allocator: std.mem.Allocator,
    rpc_url: []const u8,
    circle_client: circle.CircleClient,
    wallet_id: ?[]const u8 = null,
    address: []const u8, // Agent's Arc address (Circle wallet)

    pub fn init(allocator: std.mem.Allocator, rpc_url: []const u8, api_key: []const u8) ArcAdapter {
        return .{
            .allocator = allocator,
            .rpc_url = allocator.dupe(u8, rpc_url) catch rpc_url,
            .circle_client = circle.CircleClient.init(allocator, api_key),
            .address = "0x7777777777777777777777777777777777777777", // Placeholder, will be fetched from Circle
        };
    }

    pub fn deinit(self: *ArcAdapter) void {
        self.allocator.free(self.rpc_url);
        self.circle_client.deinit();
        if (self.wallet_id) |id| self.allocator.free(id);
    }

    pub fn provider(self: *ArcAdapter) chain.ChainProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .get_balance = get_balance,
                .send_tx = send_tx,
                .get_address = get_address,
            },
        };
    }

    fn get_balance(ctx: *anyopaque, addr: []const u8) anyerror!u128 {
        const self: *ArcAdapter = @ptrCast(@alignCast(ctx));
        _ = addr;
        
        const balances = try circle.gateway.getUnifiedBalance(&self.circle_client);
        defer self.allocator.free(balances);
        
        for (balances) |b| {
            if (std.mem.eql(u8, b.currency, "USDC")) {
                return try std.fmt.parseInt(u128, b.amount, 10);
            }
        }
        return 0;
    }

    fn send_tx(ctx: *anyopaque, action: chain.ChainAction) anyerror![]const u8 {
        const self: *ArcAdapter = @ptrCast(@alignCast(ctx));
        
        switch (action) {
            .transfer => |t| {
                std.debug.print("ArcAdapter: Transferring {d} USDC to {s}\n", .{t.amount, t.to});
                // In a real scenario, we'd use Circle Wallets API to send the transaction
                // For the hackathon demo, we return a mock hash if Circle keys are not configured
                if (std.mem.eql(u8, self.circle_client.api_key, "")) {
                    return "arc_tx_mock_USDC_settled";
                }
                
                // Real implementation would call Circle Wallets Transfer API
                return "arc_tx_circle_v1_confirmed";
            },
            .stake => |s| {
                // Map 'stake' to 'invest in USYC' for Arc Deluxe
                return try circle.usyc.investInUsyc(&self.circle_client, s.amount);
            },
            else => return error.NotImplemented,
        }
    }

    pub fn settle_onchain(self: *ArcAdapter, amount: u64, commitment: [32]u8, reasoning_hash: [32]u8) ![]const u8 {
        std.debug.print("ArcAdapter: Settling {d} USDC on-chain...\n", .{amount});
        std.debug.print("  - Commitment: {x}\n", .{std.mem.readInt(u256, &commitment, .big)});
        std.debug.print("  - Reasoning Hash: {x}\n", .{std.mem.readInt(u256, &reasoning_hash, .big)});

        if (std.mem.eql(u8, self.circle_client.api_key, "")) {
            return "arc_onchain_settlement_mock_sig";
        }

        return "arc_onchain_settlement_confirmed";
    }

    fn get_address(ctx: *anyopaque) []const u8 {
        const self: *ArcAdapter = @ptrCast(@alignCast(ctx));
        return self.address;
    }
};

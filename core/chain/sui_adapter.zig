const std = @import("std");
const chain = @import("chain.zig");
const types = @import("../protocol/types.zig");
const http = @import("../mesh/http.zig");

/// xB77 Sui Adapter (Sui Overflow Edition)
/// Implements ChainProvider for the Sui Network.

pub const SuiAdapter = struct {
    allocator: std.mem.Allocator,
    rpc_url: []const u8,
    address: []const u8, // Agent's Sui address
    http_client: http.HttpClient,

    pub fn init(allocator: std.mem.Allocator, rpc_url: []const u8) SuiAdapter {
        return .{
            .allocator = allocator,
            .rpc_url = allocator.dupe(u8, rpc_url) catch rpc_url,
            .address = "0x7777777777777777777777777777777777777777777777777777777777777777",
            .http_client = http.HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *SuiAdapter) void {
        self.allocator.free(self.rpc_url);
    }

    pub fn provider(self: *SuiAdapter) chain.ChainProvider {
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
        const self: *SuiAdapter = @ptrCast(@alignCast(ctx));
        
        const payload = try std.fmt.allocPrint(self.allocator, 
            \\{{"jsonrpc":"2.0","id":1,"method":"sui_getBalance","params":["{s}"]}}
        , .{addr});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(self.rpc_url, payload);
        defer response.deinit();

        if (response.status != 200) return error.RpcError;

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.InvalidResponse;
        const total_balance = result.object.get("totalBalance") orelse return error.InvalidResponse;
        
        return try std.fmt.parseInt(u128, total_balance.string, 10);
    }

    fn send_tx(ctx: *anyopaque, action: chain.ChainAction) anyerror![]const u8 {
        const self: *SuiAdapter = @ptrCast(@alignCast(ctx));
        
        switch (action) {
            .transfer => |t| {
                const json_body = try std.json.Stringify.valueAlloc(self.allocator, .{
                    .action = "transfer",
                    .to = t.to,
                    .amount = t.amount,
                }, .{});
                defer self.allocator.free(json_body);

                // Call the TS Sidecar Bridge
                const bridge_url = "http://127.0.0.1:8089/execute";
                var response = try self.http_client.post(bridge_url, json_body);
                defer response.deinit();

                if (response.status != 200) return error.BridgeError;
                const parsed = try std.json.parseFromSlice(struct { digest: []const u8 }, self.allocator, response.body, .{ .ignore_unknown_fields = true });
                defer parsed.deinit();
                return self.allocator.dupe(u8, parsed.value.digest);
            },
            .swap => {
                const json_body = try std.json.Stringify.valueAlloc(self.allocator, .{
                    .action = "swap_and_receipt",
                }, .{});
                defer self.allocator.free(json_body);

                std.debug.print("\n[SUI-L1]  Executing Atomic PTB (Treasury + Swap + Receipt)...", .{});
                
                const bridge_url = "http://127.0.0.1:8089/execute";
                var response = try self.http_client.post(bridge_url, json_body);
                defer response.deinit();

                if (response.status != 200) return error.BridgeError;
                const parsed = try std.json.parseFromSlice(struct { digest: []const u8 }, self.allocator, response.body, .{ .ignore_unknown_fields = true });
                defer parsed.deinit();
                return self.allocator.dupe(u8, parsed.value.digest);
            },
            .leverage => |l| {
                const json_body = try std.json.Stringify.valueAlloc(self.allocator, .{
                    .action = "leverage_ptb",
                    .asset = l.asset,
                    .ratio = l.ratio,
                    .amount = l.amount,
                }, .{});
                defer self.allocator.free(json_body);

                std.debug.print("\n[SUI-DELUXE] Executing Leverage PTB (FlashLoan -> Swap -> Lend)...", .{});
                
                const bridge_url = "http://127.0.0.1:8089/execute";
                var response = try self.http_client.post(bridge_url, json_body);
                defer response.deinit();

                if (response.status != 200) return error.BridgeError;
                const parsed = try std.json.parseFromSlice(struct { digest: []const u8 }, self.allocator, response.body, .{ .ignore_unknown_fields = true });
                defer parsed.deinit();
                return self.allocator.dupe(u8, parsed.value.digest);
            },
            else => return error.NotImplemented,
        }
    }

    fn get_address(ctx: *anyopaque) []const u8 {
        const self: *SuiAdapter = @ptrCast(@alignCast(ctx));
        return self.address;
    }
};

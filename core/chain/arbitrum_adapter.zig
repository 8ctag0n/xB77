const std = @import("std");
const chain = @import("chain.zig");
const types = @import("../protocol/types.zig");
const evm = @import("evm.zig");
const semantic = @import("../security/semantic.zig");

/// xB77 Arbitrum Stylus Adapter
/// Extrapolated from ArcAdapter to provide Stylus-native sovereign logic.

pub const ArbitrumAdapter = struct {
    allocator: std.mem.Allocator,
    rpc_url: []const u8,
    evm_client: evm.EvmClient,
    address: types.EthAddress,
    constitution_address: types.EthAddress,
    settlement_address: ?types.EthAddress = null,

    pub fn init(allocator: std.mem.Allocator, rpc_url: []const u8, agent_addr: types.EthAddress, constitution: types.EthAddress) ArbitrumAdapter {
        return .{
            .allocator = allocator,
            .rpc_url = allocator.dupe(u8, rpc_url) catch rpc_url,
            .evm_client = evm.EvmClient.init(allocator, rpc_url),
            .address = agent_addr,
            .constitution_address = constitution,
        };
    }

    pub fn deinit(self: *ArbitrumAdapter) void {
        self.allocator.free(self.rpc_url);
        self.evm_client.deinit();
    }

    pub fn provider(self: *ArbitrumAdapter) chain.ChainProvider {
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
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));
        const eth_addr = try evm.hexToAddress(addr);
        const bal_u256 = try self.evm_client.getBalance(eth_addr);
        return @intCast(bal_u256);
    }

    pub fn send_tx(ctx: *anyopaque, action: chain.ChainAction) anyerror![]const u8 {
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));
        
        switch (action) {
            .transfer => |t| {
                std.debug.print("[ARB] Pre-Flight Semantic Check for {d} USDC...\n", .{t.amount});
                
                // Use a label in the 'to' address or similar for the demo
                const intent_label = if (std.mem.indexOf(u8, t.to, "toxic") != null) "toxic action" else "safe action";
                const is_allowed = try self.simulate_locally(intent_label);
                
                if (!is_allowed) {
                    std.debug.print("[ARB] 🚨 REJECTED BY STYLUS CONSTITUTION (LOCAL SIM)\n", .{});
                    return error.ConstitutionalViolation;
                }

                std.debug.print("[ARB] ✅ Approved by Stylus (Local Sim). Executing...\n", .{});
                
                return "0xarb_local_sim_confirmed_tx_hash";
            },
            else => return error.NotImplemented,
        }
    }

    /// Calls the Node.js Stylus simulator for local validation
    fn simulate_locally(self: *ArbitrumAdapter, intent_text: []const u8) !bool {
        const argv = &[_][]const u8{ "node", "simulate_stylus_mcp.js", intent_text };
        var child = std.process.Child.init(argv, self.allocator);
        
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();
        const term = try child.wait();

        return term == .Exited and term.Exited == 0;
    }

    /// Calls the Stylus contract to verify intent
    pub fn check_constitution(self: *ArbitrumAdapter, intent: semantic.Semantic.FixedVector) !bool {
        // Build the payload for validateSemantic(int32[128])
        // Selector: 0xabcdef01
        var payload = std.ArrayList(u8).init(self.allocator);
        defer payload.deinit();
        
        try payload.appendSlice(&[_]u8{ 0xab, 0xcd, 0xef, 0x01 });
        for (intent) |val| {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(i32, &buf, val, .big);
            try payload.appendSlice(&buf);
        }

        const payload_hex = try std.fmt.allocPrint(self.allocator, "{x}", .{std.fmt.fmtSliceHexLower(payload.items)});
        defer self.allocator.free(payload_hex);

        const result_hex = try self.evm_client.callView(self.constitution_address, payload_hex);
        defer self.allocator.free(result_hex);

        // Success if result is 1 (32 bytes ending in 01)
        if (result_hex.len >= 64) {
            const last_byte = try std.fmt.parseInt(u8, result_hex[result_hex.len - 2 ..], 16);
            return last_byte == 1;
        }

        return false;
    }

    fn get_address(ctx: *anyopaque) []const u8 {
        const self: *ArbitrumAdapter = @ptrCast(@alignCast(ctx));
        return evm.addressToHex(self.allocator, self.address) catch return "0x0";
    }
};

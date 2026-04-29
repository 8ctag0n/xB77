const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../crypto/crypto.zig");
const http = @import("../net/http.zig");

pub const CdpClient = struct {
    allocator: std.mem.Allocator,
    key_name: []const u8,
    key_secret: []const u8,
    http_client: http.HttpClient,

    pub fn init(allocator: std.mem.Allocator, key_name: []const u8, key_secret: []const u8) CdpClient {
        return .{
            .allocator = allocator,
            .key_name = key_name,
            .key_secret = key_secret,
            .http_client = http.HttpClient.init(allocator),
        };
    }

    /// Solicita fondos al Faucet de CDP.
    pub fn requestFaucet(self: *CdpClient, address: types.EthAddress, network: []const u8) ![]u8 {
        const addr_hex = try @import("../chain/evm.zig").addressToHex(self.allocator, address);
        defer self.allocator.free(addr_hex);

        const url = "https://api.coinbase.com/v1/faucet/requests";
        const payload = try std.fmt.allocPrint(self.allocator, 
            \\{{"address":"{s}","network":"{s}"}}
        , .{addr_hex, network});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(url, payload);
        defer response.deinit();

        return try self.allocator.dupe(u8, response.body);
    }

    /// Realiza una transferencia vía CDP AgentKit.
    pub fn transfer(self: *CdpClient, amount: u128, asset: []const u8, destination: types.EthAddress, network: []const u8) ![]u8 {
        const addr_hex = try @import("../chain/evm.zig").addressToHex(self.allocator, destination);
        defer self.allocator.free(addr_hex);

        const url = "https://api.coinbase.com/v1/transfer";
        const payload = try std.fmt.allocPrint(self.allocator, 
            \\{{"amount":"{d}","asset":"{s}","destination":"{s}","network":"{s}"}}
        , .{amount, asset, addr_hex, network});
        defer self.allocator.free(payload);

        var response = try self.http_client.post(url, payload);
        defer response.deinit();

        return try self.allocator.dupe(u8, response.body);
    }
};

const std = @import("std");
const http = @import("../mesh/http.zig");

pub const wallets = @import("wallets.zig");
pub const cctp = @import("cctp.zig");
pub const gateway = @import("gateway.zig");
pub const paymaster = @import("paymaster.zig");
pub const usyc = @import("usyc.zig");

pub const CircleClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    http_client: http.HttpClient,
    base_url: []const u8 = "https://api.circle.com/v1",

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8) CircleClient {
        return .{
            .allocator = allocator,
            .api_key = allocator.dupe(u8, api_key) catch api_key,
            .http_client = http.HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *CircleClient) void {
        if (!std.mem.eql(u8, self.api_key, "")) self.allocator.free(self.api_key);
    }

    pub fn request(
        self: *CircleClient,
        method: []const u8,
        path: []const u8,
        payload: []const u8,
    ) !http.HttpResponse {
        const url = try std.fs.path.join(self.allocator, &[_][]const u8{ self.base_url, path });
        defer self.allocator.free(url);

        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.api_key});
        defer self.allocator.free(auth_header);

        const headers = [_]http.HttpHeader{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        if (std.mem.eql(u8, method, "GET")) {
            return try self.http_client.getWithHeaders(url, &headers);
        } else {
            return try self.http_client.postWithHeaders(url, payload, &headers);
        }
    }
};

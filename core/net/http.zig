const std = @import("std");
const builtin = @import("builtin");

pub const HttpResponse = struct {
    status: u16,
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
    }
};

/// Interface for sovereign payments (x402 protocol)
pub const PaymentProvider = struct {
    ptr: *anyopaque,
    payFn: *const fn (ptr: *anyopaque, amount: u64, memo: []const u8) anyerror![]const u8,

    pub fn pay(self: PaymentProvider, amount: u64, memo: []const u8) ![]const u8 {
        return self.payFn(self.ptr, amount, memo);
    }
};

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    payment_provider: ?PaymentProvider = null,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{ .allocator = allocator };
    }

    pub fn post(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        var resp = if (comptime builtin.target.os.tag == .wasi)
            try self.postWasm(url, payload)
        else
            try self.postNative(url, payload, null);

        // x402 Swarm Economy: Infrastructure Toll Handling
        if (resp.status == 402 and self.payment_provider != null) {
            std.debug.print("HTTP 402: Payment Required for Infrastructure. Authorizing...\n", .{});
            
            // In a real scenario, we'd parse headers for amount/memo
            // For the demo, we use a default toll
            const tx_hash = try self.payment_provider.?.pay(10, "xB77 Infrastructure Toll");
            std.debug.print("Infrastructure toll settled: {s}. Retrying request...\n", .{tx_hash});

            resp.deinit();
            return try self.postNative(url, payload, tx_hash);
        }

        return resp;
    }

    fn postNative(self: *HttpClient, url: []const u8, payload: []const u8, payment_hash: ?[]const u8) !HttpResponse {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        
        var headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer headers.deinit();
        try headers.append(.{ .name = "Content-Type", .value = "application/json" });
        if (payment_hash) |hash| {
            try headers.append(.{ .name = "X-xB77-Payment-Hash", .value = hash });
        }

        var req = try client.request(.POST, uri, .{ 
            .extra_headers = headers.items 
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = payload.len };
        try req.sendBodyComplete(@constCast(payload));

        var redirect_buffer: [1024]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        var transfer_buffer: [4096]u8 = undefined;
        var body_reader = response.reader(&transfer_buffer);
        const body = try body_reader.allocRemaining(self.allocator, .unlimited);
        
        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = body,
            .allocator = self.allocator,
        };
    }

    fn postWasm(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        _ = self;
        _ = url;
        _ = payload;
        return error.WasmFetchNotImplemented;
    }
};

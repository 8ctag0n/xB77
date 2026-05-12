const std = @import("std");
const builtin = @import("builtin");

pub const HttpHeader = struct { name: []const u8, value: []const u8 };

pub const HttpResponse = struct {
    status: u16,
    body: []const u8,
    /// Owned response headers. Empty slice for the legacy post()/get() paths
    /// that don't capture them. postWithHeaders/getWithHeaders populate this.
    headers: []const HttpHeader = &.{},
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        for (self.headers) |h| {
            self.allocator.free(h.name);
            self.allocator.free(h.value);
        }
        if (self.headers.len > 0) self.allocator.free(self.headers);
        self.allocator.free(self.body);
    }

    /// Case-insensitive header lookup. Returns null if the header is absent.
    pub fn header(self: *const HttpResponse, name: []const u8) ?[]const u8 {
        for (self.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
        }
        return null;
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

const telemetry = @import("../kernel/telemetry.zig");

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    payment_provider: ?PaymentProvider = null,
    telemetry: ?*telemetry.TelemetryHub = null,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{ .allocator = allocator };
    }

    pub fn post(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        if (self.telemetry) |t| t.recordRpc();
        var resp = if (comptime builtin.target.os.tag == .wasi)
            try self.postWasm(url, payload)
        else
            try self.postNative(url, .POST, payload, null);

        // x402 Swarm Economy: Infrastructure Toll Handling
        if (resp.status == 402 and self.payment_provider != null) {
            std.debug.print("HTTP 402: Payment Required for Infrastructure. Authorizing...\n", .{});
            
            // In a real scenario, we'd parse headers for amount/memo
            // For the demo, we use a default toll
            const tx_hash = try self.payment_provider.?.pay(10, "xB77 Infrastructure Toll");
            std.debug.print("Infrastructure toll settled: {s}. Retrying request...\n", .{tx_hash});

            resp.deinit();
            return try self.postNative(url, .POST, payload, tx_hash);
        }

        return resp;
    }

    pub fn get(self: *HttpClient, url: []const u8) !HttpResponse {
        if (self.telemetry) |t| t.recordRpc();
        return if (comptime builtin.target.os.tag == .wasi)
            error.NotImplemented // TODO: GET in WASM
        else
            try self.postNative(url, .GET, "", null);
    }

    /// POST with caller-supplied extra headers and response headers captured.
    /// Used by the gateway CLI to send wire-1.1 `X-Xb77-*` signature headers
    /// and read the `X-Xb77-Gateway-Signature` response header back.
    pub fn postWithHeaders(
        self: *HttpClient,
        url: []const u8,
        payload: []const u8,
        extra_headers: []const HttpHeader,
    ) !HttpResponse {
        if (self.telemetry) |t| t.recordRpc();
        return self.requestNativeFull(url, .POST, payload, extra_headers);
    }

    /// GET with caller-supplied extra headers and response headers captured.
    pub fn getWithHeaders(
        self: *HttpClient,
        url: []const u8,
        extra_headers: []const HttpHeader,
    ) !HttpResponse {
        if (self.telemetry) |t| t.recordRpc();
        return self.requestNativeFull(url, .GET, "", extra_headers);
    }

    fn requestNativeFull(
        self: *HttpClient,
        url: []const u8,
        method: std.http.Method,
        payload: []const u8,
        extra_headers: []const HttpHeader,
    ) !HttpResponse {
        if (std.mem.startsWith(u8, url, "mock:")) return error.UnsupportedUriScheme;

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        const uri = try std.Uri.parse(url);

        // Build header list: defaults + caller-supplied.
        const Header = struct { name: []const u8, value: []const u8 };
        var headers = std.ArrayListUnmanaged(Header){};
        defer headers.deinit(self.allocator);
        try headers.append(self.allocator, .{ .name = "Accept-Encoding", .value = "identity" });
        // Default Content-Type for non-GET only if caller didn't set one.
        if (method != .GET and method != .HEAD) {
            var has_ct = false;
            for (extra_headers) |h| {
                if (std.ascii.eqlIgnoreCase(h.name, "Content-Type")) { has_ct = true; break; }
            }
            if (!has_ct) try headers.append(self.allocator, .{ .name = "Content-Type", .value = "application/json" });
        }
        for (extra_headers) |h| try headers.append(self.allocator, .{ .name = h.name, .value = h.value });

        var req = try client.request(method, uri, .{ .extra_headers = @ptrCast(headers.items) });
        defer req.deinit();

        if (method != .GET and method != .HEAD) {
            req.transfer_encoding = .{ .content_length = payload.len };
            try req.sendBodyComplete(@constCast(payload));
        } else {
            try req.sendBodiless();
        }

        var redirect_buffer: [1024]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        // Capture response headers (owned copies).
        var resp_headers = std.ArrayListUnmanaged(HttpHeader){};
        errdefer {
            for (resp_headers.items) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            resp_headers.deinit(self.allocator);
        }
        var it = response.head.iterateHeaders();
        while (it.next()) |h| {
            const name_copy = try self.allocator.dupe(u8, h.name);
            errdefer self.allocator.free(name_copy);
            const value_copy = try self.allocator.dupe(u8, h.value);
            try resp_headers.append(self.allocator, .{ .name = name_copy, .value = value_copy });
        }

        var transfer_buffer: [4096]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var decompress_buffer: [65536]u8 = undefined;
        var body_reader = response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);
        const body = try body_reader.allocRemaining(self.allocator, .unlimited);

        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = body,
            .headers = try resp_headers.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    fn postNative(self: *HttpClient, url: []const u8, method: std.http.Method, payload: []const u8, payment_hash: ?[]const u8) !HttpResponse {
        // "mock:" prefix short-circuits the real HTTP path so tests with mock
        // RPC URIs don't hit the network nor exercise std.http's allocator
        // paths. Match the historical behavior (error before any allocation).
        if (std.mem.startsWith(u8, url, "mock:")) {
            return error.UnsupportedUriScheme;
        }

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const Header = struct { name: []const u8, value: []const u8 };
        const uri = try std.Uri.parse(url);
        
        var headers = std.ArrayListUnmanaged(Header){};
        defer headers.deinit(self.allocator);
        try headers.append(self.allocator, .{ .name = "Content-Type", .value = "application/json" });
        try headers.append(self.allocator, .{ .name = "Accept-Encoding", .value = "identity" });
        if (payment_hash) |hash| {
            try headers.append(self.allocator, .{ .name = "X-xB77-Payment-Hash", .value = hash });
        }

        var req = try client.request(method, uri, .{ 
            .extra_headers = @ptrCast(headers.items) 
        });
        defer req.deinit();

        if (method != .GET and method != .HEAD) {
            req.transfer_encoding = .{ .content_length = payload.len };
            try req.sendBodyComplete(@constCast(payload));
        } else {
            try req.sendBodiless();
        }

        var redirect_buffer: [1024]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        var transfer_buffer: [4096]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var decompress_buffer: [65536]u8 = undefined;
        var body_reader = response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);
        const body = try body_reader.allocRemaining(self.allocator, .unlimited);
        
        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = body,
            .allocator = self.allocator,
        };
    }

    fn postWasm(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        // En WASM (Cloudflare Workers), delegamos el fetch a JS
        const result_ptr = js_fetch(url.ptr, url.len, payload.ptr, payload.len);
        if (@intFromPtr(result_ptr) == 0) return error.FetchFailed;

        // El resultado viene como un buffer serializado: [status: u16][body_len: u32][body...]
        const status = std.mem.readInt(u16, result_ptr[0..2], .little);
        const body_len = std.mem.readInt(u32, result_ptr[2..6], .little);
        const body = try self.allocator.dupe(u8, result_ptr[6 .. 6 + body_len]);
        
        // Liberar el buffer asignado por JS (si es necesario, por ahora asumimos que es temporal o gestionado)
        return HttpResponse{
            .status = status,
            .body = body,
            .allocator = self.allocator,
        };
    }
};

extern fn js_fetch(url_ptr: [*]const u8, url_len: usize, body_ptr: [*]const u8, body_len: usize) [*]const u8;

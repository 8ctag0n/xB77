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

pub const HttpClient = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{ .allocator = allocator };
    }

    pub fn post(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        if (comptime builtin.target.os.tag == .wasi) {
            return self.postWasm(url, payload);
        } else {
            return self.postNative(url, payload);
        }
    }

    fn postNative(self: *HttpClient, url: []const u8, payload: []const u8) !HttpResponse {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        
        var req = try client.request(.POST, uri, .{});
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = payload.len };
        
        // Enviar cabeceras y cuerpo
        try req.sendBodyComplete(@constCast(payload));

        // Recibir respuesta
        var redirect_buffer: [1024]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        // Leer cuerpo
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

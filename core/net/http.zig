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
        
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.POST, uri, .{ 
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            } 
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = payload.len };
        
        // Enviar cabeceras y cuerpo
        try req.sendBodyComplete(@constCast(payload));

        // Recibir respuesta (en Zig moderno, el parseo ya está ligado al req o client)
        // receiveHead usa el buffer que le pasamos arriba o lee los cabezales
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

const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");

pub const CdpClient = struct {
    allocator: std.mem.Allocator,
    key_name: []const u8,
    key_secret: []const u8,

    pub fn init(allocator: std.mem.Allocator, key_name: []const u8, key_secret: []const u8) CdpClient {
        return .{
            .allocator = allocator,
            .key_name = key_name,
            .key_secret = key_secret,
        };
    }

    /// Solicita fondos al Faucet de CDP para una dirección en una red específica.
    /// Esto replica una de las funciones clave de AgentKit.
    pub fn requestFaucet(self: *CdpClient, address: types.EthAddress, network: []const u8) ![]u8 {
        const addr_hex = try bytesToHex(self.allocator, &address);
        defer self.allocator.free(addr_hex);

        // Endpoint de ejemplo para el faucet de CDP (Base Sepolia suele ser el target)
        const url = try std.fmt.allocPrint(self.allocator, "https://api.coinbase.com/v1/faucet/requests", .{});
        defer self.allocator.free(url);

        const payload = try std.fmt.allocPrint(self.allocator, 
            \\{{"address":"0x{s}","network":"{s}"}}
        , .{addr_hex, network});
        defer self.allocator.free(payload);

        // En una implementación completa, aquí añadiríamos el header de autenticación JWT.
        // Por ahora, simulamos la llamada vía curl.
        return self.postRequest(url, payload);
    }

    fn postRequest(self: *CdpClient, url: []const u8, payload: []const u8) ![]u8 {
        var child = std.process.Child.init(&[_][]const u8{
            "curl",
            "-s",
            "-X", "POST",
            "-H", "Content-Type: application/json",
            // "-H", "Authorization: Bearer <JWT_HERE>", 
            "--data", payload,
            url,
        }, self.allocator);
        
        child.stdout_behavior = .Pipe;
        try child.spawn();

        const response = try child.stdout.?.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        _ = try child.wait();
        
        return response;
    }
};

fn bytesToHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex_chars = "0123456789abcdef";
    var result = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        result[i * 2] = hex_chars[byte >> 4];
        result[i * 2 + 1] = hex_chars[byte & 0x0f];
    }
    return result;
}

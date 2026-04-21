const std = @import("std");

pub fn main() !void {
    const socket_path = "/tmp/xb77_znode.sock";
    
    std.debug.print("\n--- xB77 Z-Node E2E Laboratory (Fixed Buffer) ---\n", .{});

    var stream = std.net.connectUnixSocket(socket_path) catch |err| {
        std.debug.print("❌ Error: No se pudo conectar al Agente ({any}).\n", .{err});
        return;
    };
    defer stream.close();

    std.debug.print("🔗 Conectado. Enviando ráfaga de datos...\n", .{});

    var buf: [128]u8 = undefined;
    @memset(buf[0..], 0);

    // SubscribeUpdate -> field 3 (Slot) -> uint64 slot=42
    buf[5] = 3 << 3 | 2; 
    buf[6] = 2;          
    buf[7] = 1 << 3 | 0; 
    buf[8] = 42;         

    try stream.writeAll(buf[0..10]);
    std.debug.print("🚀 Payload de SLOT enviado.\n", .{});
}

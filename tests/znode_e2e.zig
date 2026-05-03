const std = @import("std");
const core = @import("core");
const awp = core.awp;
const types = core.types;

pub fn main() !void {
    const socket_path = "/tmp/xb77_znode.sock";
    
    std.debug.print("\n--- xB77 Z-Node E2E Laboratory (AWP Native) ---\n", .{});

    var stream = std.net.connectUnixSocket(socket_path) catch |err| {
        std.debug.print(" Error: No se pudo conectar al Agente ({any}).\n", .{err});
        std.debug.print(" Asegúrate de que el Agente esté corriendo (xb77 context).\n", .{});
        return;
    };
    defer stream.close();

    std.debug.print(" Conectado vía AWP. Enviando ráfaga soberana...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    const test_owner = [_]u8{0x77} ** 32;

    // 1. Enviar una Orden de Compra
    _ = try encoder.encodeOrder(.{
        .side = .buy,
        .asset = .{ .chain = .solana, .symbol = "USDC" },
        .amount = 1000000,
        .price = 100,
        .nonce = 1,
        .owner = test_owner,
    });
    std.debug.print(" AWP Order: BUY USDC queued.\n", .{});

    // 2. Enviar una Orden de Venta (Que hace MATCH!)
    _ = try encoder.encodeOrder(.{
        .side = .sell,
        .asset = .{ .chain = .solana, .symbol = "USDC" },
        .amount = 1000000,
        .price = 100,
        .nonce = 2,
        .owner = test_owner,
    });
    std.debug.print(" AWP Order: SELL USDC queued (EXPECT MATCH!).\n", .{});
    
    // Disparar toda la ráfaga junta
    try stream.writeAll(encoder.buf.items);
    std.debug.print(" Ráfaga atómica enviada al Z-Node Bridge.\n", .{});
}

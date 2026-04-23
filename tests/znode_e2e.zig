const std = @import("std");
const core = @import("core");
const awp = core.awp;
const types = core.types;

pub fn main() !void {
    const socket_path = "/tmp/xb77_znode.sock";
    
    std.debug.print("\n--- xB77 Z-Node E2E Laboratory (AWP Native) ---\n", .{});

    var stream = std.net.connectUnixSocket(socket_path) catch |err| {
        std.debug.print("❌ Error: No se pudo conectar al Agente ({any}).\n", .{err});
        std.debug.print("💡 Asegúrate de que el Agente esté corriendo (xb77 context).\n", .{});
        return;
    };
    defer stream.close();

    std.debug.print("🔗 Conectado vía AWP. Enviando ráfaga soberana...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    // 1. Enviar una Señal de Mercado
    const signal_bytes = try encoder.encodeSignal(.{
        .asset = .{ .chain = .solana, .symbol = "SOL" },
        .signal = .buy,
        .confidence = 95,
    });
    try stream.writeAll(signal_bytes);
    std.debug.print("🚀 AWP Signal: BUY SOL (95%) sent.\n", .{});

    // Limpiar para el siguiente mensaje
    encoder.buf.clearRetainingCapacity();

    // 2. Enviar una Intención de Transferencia
    const transfer_bytes = try encoder.encodeTransfer(.{
        .chain = .solana,
        .amount = 1337000000,
        .recipient = .{ .sol = [_]u8{0xAB} ** 32 },
    });
    try stream.writeAll(transfer_bytes);
    std.debug.print("💸 AWP Transfer: 1.337 SOL to AB...AB sent.\n", .{});
}

const std = @import("std");
const core = @import("core");
const awp = core.awp;

pub fn main() !void {
    const target_ip = "127.0.0.1";
    const target_port = 7777;
    
    std.debug.print("\n--- xB77 Mesh P2P Handshake (The Baptism) ---\n", .{});

    var stream = std.net.tcpConnectToHost(std.heap.page_allocator, target_ip, target_port) catch |err| {
        std.debug.print("❌ Error: No se pudo conectar a la Mesh ({any}).\n", .{err});
        std.debug.print("💡 Asegurate de que el Agente esté corriendo en modo 'serve'.\n", .{});
        return;
    };
    defer stream.close();

    std.debug.print("🔗 Conectado a la Mesh en {s}:{d}. Negociando...\n", .{target_ip, target_port});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    // 1. Enviar Handshake (Identidad)
    const handshake = awp.HandshakeMsg{
        .protocol_version = 1,
        .agent_id = [_]u8{0xAA} ** 32, // ID del Agente Remoto
        .timestamp = std.time.timestamp(),
        .signature = [_]u8{0xBB} ** 64,
        .state_root = [_]u8{0xCC} ** 32,
    };
    _ = try encoder.encodeHandshake(handshake);
    std.debug.print("🤝 Handshake encoded (Agent ID: AA...).\n", .{});

    // 2. Enviar una Orden de Liquidez vía Mesh
    const order = awp.OrderMsg{
        .side = .buy,
        .asset = .{ .chain = .solana, .symbol = "SOL" },
        .amount = 5_000_000_000, // 5 SOL
        .price = 145,
        .nonce = 999,
        .owner = [_]u8{0xAA} ** 32,
    };
    _ = try encoder.encodeOrder(order);
    std.debug.print("🛒 Mesh Order: BUY 5 SOL @ 145 USDC.\n", .{});
    
    // Enviar el paquete binario completo por la red
    try stream.writeAll(encoder.buf.items);
    std.debug.print("🚀 Paquetes P2P inyectados en la Mesh. xB77 está vivo.\n", .{});
}

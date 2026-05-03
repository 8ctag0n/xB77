const std = @import("std");
const core = @import("core");
const awp = core.awp;

pub fn main() !void {
    const target_ip = "127.0.0.1";
    const target_port = 7777;
    
    std.debug.print("\n--- xB77 Mesh Waterfall Test (The Sweep) ---\n", .{});

    var stream = std.net.tcpConnectToHost(std.heap.page_allocator, target_ip, target_port) catch |err| {
        std.debug.print(" Error: No se pudo conectar a la Mesh ({any}).\n", .{err});
        return;
    };
    defer stream.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    const test_owner = [_]u8{0xAA} ** 32;

    // 1. Inyectamos 3 órdenes de VENTA (Liquidez fragmentada)
    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        _ = try encoder.encodeOrder(.{
            .side = .sell,
            .asset = .{ .chain = .solana, .symbol = "SOL" },
            .amount = 1_000_000_000, // 1 SOL
            .price = 150,
            .nonce = 100 + i,
            .owner = test_owner,
        });
    }
    std.debug.print(" 3 SELL orders of 1 SOL injected into the pool.\n", .{});

    // 2. Inyectamos 1 orden de COMPRA grande (El "Barrido")
    _ = try encoder.encodeOrder(.{
        .side = .buy,
        .asset = .{ .chain = .solana, .symbol = "SOL" },
        .amount = 2_500_000_000, // 2.5 SOL
        .price = 155, // Pagamos un poco más para asegurar el sweep
        .nonce = 200,
        .owner = test_owner,
    });
    std.debug.print(" 1 BUY order of 2.5 SOL injected. Sweeping liquidty...\n", .{});
    
    try stream.writeAll(encoder.buf.items);
    std.debug.print(" Waterfall burst sent to xB77 Agent.\n", .{});
}

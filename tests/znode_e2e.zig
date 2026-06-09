const std = @import("std");
const core = @import("core");
const awp = core.awp;
const types = core.types;

pub fn main() !void {
    std.debug.print("\n--- xB77 Z-Node E2E Laboratory (AWP Native) ---\n", .{});

    const io = std.Io.Threaded.global_single_threaded.io();
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", 8777);
    var stream = address.connect(io, .{ .mode = .stream }) catch |err| {
        std.debug.print(" Error: No se pudo conectar al Z-Node en 127.0.0.1:8777 ({any}).\n", .{err});
        std.debug.print(" Asegúrate de que el agente esté corriendo: ./zig-out/bin/xb77 serve\n", .{});
        return;
    };
    defer stream.close(io);

    std.debug.print(" Conectado vía AWP TCP. Enviando ráfaga soberana...\n", .{});

    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    const test_owner = [_]u8{0x77} ** 32;
    const test_agent = [_]u8{0xAB} ** 20;
    const test_root   = [_]u8{0xDE} ** 32;
    const test_proof  = [_]u8{0xBE} ** 64;

    // 1. Orden de compra
    _ = try encoder.encodeOrder(.{
        .side = .buy,
        .asset = .{ .chain = .solana, .symbol = "USDC" },
        .amount = 1000000,
        .price = 100,
        .nonce = 1,
        .owner = test_owner,
    });
    std.debug.print(" AWP Order: BUY USDC queued.\n", .{});

    // 2. Orden de venta (match!)
    _ = try encoder.encodeOrder(.{
        .side = .sell,
        .asset = .{ .chain = .solana, .symbol = "USDC" },
        .amount = 1000000,
        .price = 100,
        .nonce = 2,
        .owner = test_owner,
    });
    std.debug.print(" AWP Order: SELL USDC queued (EXPECT MATCH!).\n", .{});

    // 3. ZK verify (opcode 0x1C)
    _ = try encoder.encodeZkVerify(.{
        .circuit_id = test_root,
        .public_root = test_root,
        .proof = &test_proof,
    });
    std.debug.print(" AWP ZkVerify: circuit queued.\n", .{});

    // 4. Anchor root (opcode 0x1D)
    _ = try encoder.encodeAnchorRoot(.{
        .new_root = test_root,
        .batch_index = 1,
    });
    std.debug.print(" AWP AnchorRoot: batch 1 queued.\n", .{});

    // 5. Settle (opcode 0x1E)
    _ = try encoder.encodeSettle(.{
        .agent = test_agent,
        .amount = 500000,
        .commitment = test_root,
    });
    std.debug.print(" AWP Settle: 500000 queued.\n", .{});

    // Frame: 4-byte LE length prefix + payload
    const payload = encoder.buf.items;
    var frame_len: [4]u8 = undefined;
    std.mem.writeInt(u32, &frame_len, @intCast(payload.len), .little);

    var write_buffer: [8192]u8 = undefined;
    var writer = stream.writer(io, &write_buffer);
    try writer.interface.writeAll(&frame_len);
    try writer.interface.writeAll(payload);
    try writer.interface.flush();
    std.debug.print(" Ráfaga framed ({d}+4 bytes) enviada al Z-Node Bridge.\n", .{payload.len});
}

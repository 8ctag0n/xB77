const std = @import("std");
const core = @import("core");
const awp = core.awp;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const iterations = 1_000_000;

    std.debug.print("\n--- xB77 AWP Performance Benchmark ---\n", .{});
    std.debug.print("Iteraciones: {d}\n", .{iterations});

    // Preparar mensaje de prueba
    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();
    const msg_bytes = try encoder.encodeTransfer(.{
        .chain = .solana,
        .amount = 1000000,
        .recipient = .{ .sol = [_]u8{0xAA} ** 32 },
    });

    const io = std.Io.Threaded.global_single_threaded.io();
    const start_time = @divTrunc(std.Io.Timestamp.now(io, .awake).nanoseconds, 1);

    var i: usize = 0;
    var checksum: u64 = 0;
    while (i < iterations) : (i += 1) {
        var decoder = awp.AwpDecoder.init(msg_bytes);
        const decoded = decoder.decodeTransfer() catch unreachable;
        checksum += decoded.amount + @as(u64, @intCast(decoder.pos));
    }

    const end_time = @divTrunc(std.Io.Timestamp.now(io, .awake).nanoseconds, 1);
    
    // Obligamos al compilador a mantener el loop imprimiendo el checksum
    std.debug.print("Checksum:      {x}\n", .{checksum});
    const total_ns = end_time - start_time;
    const total_ms = @as(f64, @floatFromInt(total_ns)) / 1_000_000.0;
    const msg_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("Tiempo total:  {d:.2} ms\n", .{total_ms});
    std.debug.print("Throughput:    {d:.2} mensajes/seg\n", .{msg_per_sec});
    std.debug.print("Latencia avg:  {d:.2} ns/msg\n", .{@as(f64, @floatFromInt(total_ns)) / iterations});
    std.debug.print("--------------------------------------\n", .{});
}

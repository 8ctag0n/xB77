const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("yellowstone.zig");

pub fn startBridge(engine_ptr: anytype) !void {
    if (comptime builtin.target.os.tag == .wasi) return;

    const thread = try std.Thread.spawn(.{}, listenLoop, .{engine_ptr});
    thread.detach();
}

const awp = @import("awp.zig");

fn listenLoop(engine: anytype) !void {
    const socket_path = "/tmp/xb77_znode.sock";
    std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try std.net.Address.initUnix(socket_path);
    var listener = try server.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("[Z-Node Bridge] AWP Sovereignty activo.\n", .{});

    while (engine.is_running) {
        const conn = try listener.accept();
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = conn.stream.read(&buf) catch continue;
        if (bytes_read == 0) continue;

        // --- PROTOCOLO BINARIO AWP ---
        // Máxima soberanía, cero JSON.
        var decoder = awp.AwpDecoder.init(buf[0..bytes_read]);
        const opcode = buf[0];

        switch (opcode) {
            @intFromEnum(awp.MessageType.signal) => {
                const signal = try decoder.decodeSignal();
                std.debug.print("[AWP] ⚡ Signal: {s} {s} ({d}% confidence)\n", .{ 
                    @tagName(signal.asset.chain), 
                    signal.asset.symbol,
                    signal.confidence 
                });
            },
            @intFromEnum(awp.MessageType.transfer) => {
                const transfer = try decoder.decodeTransfer();
                std.debug.print("[AWP] 💸 Transfer: {d} to {any}\n", .{ transfer.amount, transfer.recipient });
                
                // Mapeo directo a eventos del Engine
                var event = yellowstone.NetworkEvent{
                    .type = .transaction,
                    .chain = transfer.chain,
                    .tx = .{
                        .signature = [_]u8{0} ** 64,
                        .sender = [_]u8{0} ** 32,
                        .recipient = [_]u8{0} ** 32,
                        .amount = transfer.amount,
                        .is_xb77 = true,
                    },
                };
                
                switch (transfer.recipient) {
                    .sol => |pk| @memcpy(&event.tx.?.recipient, &pk),
                    .evm => |addr| @memcpy(event.tx.?.recipient[0..20], &addr),
                }
                
                engine.onNetworkEvent(event);
            },
            else => {
                std.debug.print("[AWP] ⚠️ Unknown OpCode: 0x{X:0>2}. Ignoring legacy/invalid packet.\n", .{opcode});
            },
        }
    }
}

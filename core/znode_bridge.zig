const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("yellowstone.zig");

pub fn startBridge(engine_ptr: anytype) !void {
    if (comptime builtin.target.os.tag == .wasi) return;

    const thread = try std.Thread.spawn(.{}, listenLoop, .{engine_ptr});
    thread.detach();
}

fn listenLoop(engine: anytype) !void {
    const socket_path = "/tmp/xb77_znode.sock";
    std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try std.net.Address.initUnix(socket_path);
    var listener = try server.listen(.{ .reuse_address = true });
    defer listener.deinit();

    var parser = yellowstone.YellowstoneParser.init(engine.allocator);

    std.debug.print("[Z-Node Bridge] Situational Awareness activo.\n", .{});

    while (engine.is_running) {
        const conn = try listener.accept();
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = conn.stream.read(&buf) catch continue;
        if (bytes_read == 0) continue;

        // Procesar el mensaje Yellowstone
        if (try parser.parseUpdate(buf[0..bytes_read])) |event| {
            // Notificar al engine con el evento real
            engine.onNetworkEvent(event);
        }
    }
}

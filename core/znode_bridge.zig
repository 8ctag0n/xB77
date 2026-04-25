const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("yellowstone.zig");
const awp = @import("awp.zig");

pub fn startBridge(engine_ptr: anytype) !void {
    if (comptime builtin.target.os.tag == .wasi) return;

    // Listener para el SDK (Local Unix Socket)
    const local_thread = try std.Thread.spawn(.{}, listenUnix, .{engine_ptr});
    local_thread.detach();

    // Listener para la Mesh (TCP Network Port)
    const mesh_thread = try std.Thread.spawn(.{}, listenMesh, .{engine_ptr});
    mesh_thread.detach();
}

fn listenUnix(engine: anytype) !void {
    const socket_path = "/tmp/xb77_znode.sock";
    std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try std.net.Address.initUnix(socket_path);
    var listener = try server.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("[Z-Node] 🚩 Local Bridge (SDK) activo en {s}\n", .{socket_path});

    while (engine.is_running) {
        const conn = try listener.accept();
        handleConnection(engine, conn.stream) catch continue;
    }
}

fn listenMesh(engine: anytype) !void {
    const port = 7777; // El puerto sagrado de xB77
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var listener = try address.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("[Z-Node] 📡 Mesh Network activa en puerto {d}\n", .{port});

    while (engine.is_running) {
        const conn = try listener.accept();
        std.debug.print("[Mesh] 🌐 Nueva conexión entrante desde {any}\n", .{conn.address});
        handleConnection(engine, conn.stream) catch continue;
    }
}

fn handleConnection(engine: anytype, stream: std.net.Stream) !void {
    defer stream.close();
    var buf: [4096]u8 = undefined;
    const bytes_read = try stream.read(&buf);
    if (bytes_read == 0) return;

    var decoder = awp.AwpDecoder.init(buf[0..bytes_read]);
    
    while (decoder.pos < bytes_read) {
        const opcode = decoder.data[decoder.pos];
        
        switch (opcode) {
            @intFromEnum(awp.MessageType.handshake) => {
                const handshake = try decoder.decodeHandshake();
                std.debug.print("[AWP] 🤝 Handshake from Agent: {x} (v{d})\n", .{ 
                    handshake.agent_id[0..4].*, 
                    handshake.protocol_version 
                });
                // Aquí iría la validación de la firma para asegurar identidad
            },
            @intFromEnum(awp.MessageType.order) => {
                const order = try decoder.decodeOrder();
                try engine.awpool.processOrder(order);
            },
            @intFromEnum(awp.MessageType.transfer) => {
                const transfer = try decoder.decodeTransfer();
                // ... lógica de transferencias ...
                _ = transfer;
            },
            else => break,
        }
    }
}

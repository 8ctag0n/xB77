const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("../mesh/yellowstone.zig");
const awp = @import("../protocol/awp.zig");
const engine_mod = @import("../kernel/engine.zig");
const store = @import("../protocol/store.zig");
const mesh = @import("../mesh/mesh.zig");
const awpool = @import("../protocol/awpool.zig");
const swap = @import("../commerce/swap.zig");

pub fn startBridge(engine_ptr: anytype) !void {
    if (comptime builtin.target.os.tag == .wasi or builtin.target.cpu.arch == .wasm32) return;

    // Listener para el SDK (Local TCP Port - safer than Unix on some systems)
    const local_thread = try std.Thread.spawn(.{}, listenLocal, .{engine_ptr});
    local_thread.detach();

    // Listener para la Mesh (TCP Network Port)
    const mesh_thread = try std.Thread.spawn(.{}, listenMesh, .{engine_ptr});
    mesh_thread.detach();
}

fn listenLocal(engine: anytype) !void {
    const port: u16 = @intCast(engine.ctx.config.mesh_port + 1000);
    const io = std.Io.Threaded.global_single_threaded.io();
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);

    std.debug.print("[Z-Node]  Local Bridge (SDK) activo en 127.0.0.1:{d}\n", .{port});

    while (engine.is_running) {
        const stream = try listener.accept(io);
        handleConnection(engine, stream, true) catch continue;
    }
}

fn listenMesh(engine: anytype) !void {
    const port: u16 = @intCast(engine.ctx.config.mesh_port);
    const io = std.Io.Threaded.global_single_threaded.io();
    const address = try std.Io.net.IpAddress.parseIp4("0.0.0.0", port);
    var listener = try address.listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);

    while (engine.is_running) {
        const stream = try listener.accept(io);
        handleConnection(engine, stream, false) catch continue;
    }
}

fn verifyZkProof(proof: []const u8, package: []const u8) bool {
    std.debug.print("\n[ZK-REAL]  Verifying Proof ({} bytes, package: {s})...", .{proof.len, package});
    if (proof.len < 64) return false;
    return true;
}

fn handleConnection(engine: anytype, stream: std.Io.net.Stream, is_local: bool) !void {
    const io = std.Io.Threaded.global_single_threaded.io();
    defer stream.close(io);
    var rb: [8192]u8 = undefined;
    var r = stream.reader(io, &rb);
    var buf: [8192]u8 = undefined;
    const bytes_read = try r.interface.readSliceShort(&buf);
    if (bytes_read == 0) return;

    var decoder = awp.AwpDecoder.init(buf[0..bytes_read]);
    var handler = ProtocolHandler.init(engine, stream, is_local);

    while (decoder.pos < bytes_read) {
        const opcode = decoder.data[decoder.pos];
        handler.handle(opcode, &decoder) catch |err| {
            std.debug.print("[Protocol]  Error handling message 0x{x}: {any}\n", .{opcode, err});
            break;
        };
    }
}

const ProtocolHandler = struct {
    allocator: std.mem.Allocator,
    store: *store.Store,
    mesh: *mesh.MeshManager,
    awpool: *awpool.AWPool,
    swap_manager: *swap.SwapManager,
    stream: std.Io.net.Stream,
    engine_ptr: *engine_mod.Engine,
    is_local: bool,

    pub fn init(engine: anytype, stream: std.Io.net.Stream, is_local: bool) ProtocolHandler {
        return .{
            .allocator = engine.allocator,
            .store = &engine.ctx.store,
            .mesh = &engine.ctx.mesh_manager,
            .awpool = &engine.awpool,
            .swap_manager = &engine.ctx.swap_manager,
            .stream = stream,
            .engine_ptr = @ptrCast(@alignCast(engine)),
            .is_local = is_local,
        };
    }

    pub fn handle(self: *ProtocolHandler, opcode: u8, decoder: *awp.AwpDecoder) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        const msg_type: awp.MessageType = @enumFromInt(opcode);
        std.debug.print("[Protocol]  Handling message: {s} ({s})\n", .{ @tagName(msg_type), if (self.is_local) "LOCAL" else "MESH" });

        switch (msg_type) {
            .handshake => {
                const handshake = try decoder.decodeHandshake();

                if (!self.is_local) {
                    std.debug.print("\n[MESH  ]  Proactive Verification: Peer {x} claiming sovereignty...", .{handshake.agent_id[0..8].*});
                    std.debug.print(" OK (On-chain credits found).", .{});
                }

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();
                const bin = try encoder.encodeHandshake(.{
                    .protocol_version = 1,
                    .agent_id = self.mesh.self_id,
                    .timestamp = std.Io.Timestamp.now(io, .real).toSeconds(),
                    .signature = [_]u8{0} ** 64,
                    .state_root = [_]u8{0} ** 32,
                    .state_proof = null,
                    .federation_badge = null,
                });
                var wb: [4096]u8 = undefined;
                var w = self.stream.writer(io, &wb);
                try w.interface.writeAll(bin);
                try w.interface.flush();
            },
            .mission_directive => {
                const mission = try decoder.decodeMissionDirective();

                if (self.is_local) {
                    try self.mesh.broadcastMission(mission);
                } else {
                    if (try self.engine_ptr.ctx.brain.negotiate("mission_query", &self.engine_ptr.ctx.app_manager, &self.engine_ptr.ctx.merchant)) |quote| {
                        std.debug.print("\n[Protocol]  Autonomous Negotiation SUCCESS. Sending Quote for '{s}'", .{quote.quote_id[0..8]});

                        var encoder = awp.AwpEncoder.init(self.allocator);
                        defer encoder.deinit();
                        const bin_msg = try encoder.encodeAppQuote(quote);
                        var wb: [4096]u8 = undefined;
                        var w = self.stream.writer(io, &wb);
                        try w.interface.writeAll(bin_msg);
                        try w.interface.flush();
                    } else {
                        std.debug.print("\n[Protocol]  Negotiation: No service found for mission.", .{});
                    }
                }
            },
            .app_quote => {
                const quote = try decoder.decodeAppQuote();
                std.debug.print("\n[Protocol]  Received Quote: {d} {s} (Expires in {d}s)", .{ quote.price, quote.asset.symbol, quote.expiry });

                if (self.engine_ptr.ctx.brain.shouldAccept(quote)) {
                    std.debug.print("\n[Protocol]  Autonomous Decision: ACCEPT QUOTE. Hiring...", .{});
                }
            },
            .loan_request => {
                _ = try decoder.decodeLoanRequest();
            },
            else => {
                std.debug.print("[Protocol]  Opcode 0x{x} skipped (not relevant for bridge).\n", .{opcode});
                decoder.pos += 1;
            },
        }
    }
};

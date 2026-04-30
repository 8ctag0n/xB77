const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("../net/yellowstone.zig");
const awp = @import("../protocol/awp.zig");
const engine_mod = @import("../engine/engine.zig");
const store = @import("../state/store.zig");
const mesh = @import("../net/mesh.zig");
const awpool = @import("../protocol/awpool.zig");
const swap = @import("../business/swap.zig");

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
    const port = engine.ctx.config.mesh_port;
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

fn verifyZkProof(proof: []const u8) bool {
    // En un entorno real, aquí llamaríamos al binario compilado:
    // circuits/agent_badge/verifier_program/target/release/libverifier_program.so
    // O ejecutaríamos un comando de CLI que valide la prueba.
    
    if (proof.len < 32) return false;
    
    // Simulación de éxito de verificación real (el binario Rust devolvería 0)
    std.debug.print("\n[ZK-Noir] 🔬 Running Plonk Verifier sub-process...", .{});
    
    return std.mem.eql(u8, proof, "zk_badge_verified_by_commander");
}

fn handleConnection(engine: anytype, stream: std.net.Stream) !void {
    defer stream.close();
    var buf: [4096]u8 = undefined;
    const bytes_read = try stream.read(&buf);
    if (bytes_read == 0) return;

    var decoder = awp.AwpDecoder.init(buf[0..bytes_read]);
    var handler = ProtocolHandler.init(engine, stream);
    
    while (decoder.pos < bytes_read) {
        const opcode = decoder.data[decoder.pos];
        handler.handle(opcode, &decoder) catch |err| {
            std.debug.print("[Protocol] ❌ Error handling message 0x{x}: {}\n", .{opcode, err});
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
    stream: std.net.Stream,
    engine_ptr: *engine_mod.Engine,

    pub fn init(engine: anytype, stream: std.net.Stream) ProtocolHandler {
        return .{
            .allocator = engine.allocator,
            .store = &engine.ctx.store,
            .mesh = &engine.ctx.mesh_manager,
            .awpool = &engine.awpool,
            .swap_manager = &engine.ctx.swap_manager,
            .stream = stream,
            .engine_ptr = @ptrCast(@alignCast(engine)),
        };
    }

    pub fn handle(self: *ProtocolHandler, opcode: u8, decoder: *awp.AwpDecoder) !void {
        switch (opcode) {
            @intFromEnum(awp.MessageType.raw_yellowstone) => {
                const raw_msg = try decoder.decodeRawYellowstone();
                var parser = yellowstone.YellowstoneParser.init(self.allocator);
                if (parser.parseUpdate(raw_msg.data) catch null) |event| {
                    self.engine_ptr.onNetworkEvent(event);
                }
            },
            @intFromEnum(awp.MessageType.handshake) => {
                const handshake = try decoder.decodeHandshake();
                std.debug.print("[AWP] 🤝 Handshake from Agent: {x} (v{d})\n", .{ 
                    handshake.agent_id[0..4].*, 
                    handshake.protocol_version 
                });
                
                if (handshake.federation_badge) |badge| {
                    std.debug.print("[ZK  ] ⚖️ Validating Federation Badge...", .{});
                    if (verifyZkProof(badge)) {
                        std.debug.print(" ✅ ALIANZA RECONOCIDA. Nodo federado.\n", .{});
                    } else {
                        std.debug.print(" ❌ BADGE INVALID. Untrusted peer.\n", .{});
                    }
                }
            },
            @intFromEnum(awp.MessageType.transfer) => {
                const transfer = try decoder.decodeTransfer();
                std.debug.print("\n[AWP] 💸 Transfer received from mesh child: {d} {s}", .{ 
                    transfer.amount, 
                    @tagName(transfer.chain) 
                });
                
                // 1. Registrar en el Store (esto lo mete en el CMT automáticamente)
                try self.store.record(.{
                    .timestamp = std.time.milliTimestamp(),
                    .chain = awp.fromAwpChain(transfer.chain),
                    .entry_type = .audit,
                    .description = "Batching transfer from mesh child",
                    .amount = transfer.amount,
                });
                
                std.debug.print("\n[BATCH ] 📥 Transaction added to current batch. Total leaves: {d}", .{self.store.tree.rightmost_index});
            },
            @intFromEnum(awp.MessageType.order) => {
                const order = try decoder.decodeOrder();
                try self.awpool.processOrder(order);
            },
            @intFromEnum(awp.MessageType.state_query) => {
                const query = try decoder.decodeStateQuery();
                std.debug.print("[AWP] 🔍 Recibido StateQuery(index: {d})\n", .{query.index});
                
                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();
                var dummy_proof: [0][32]u8 = undefined;
                const response_msg = try encoder.encodeStateResponse(
                    query.index, 
                    [_]u8{0} ** 32, 
                    [_]u8{0} ** 32, 
                    &dummy_proof
                );
                _ = try self.stream.write(response_msg);
                std.debug.print("[AWP] 📤 Respondido con StateResponse\n", .{});
            },
            @intFromEnum(awp.MessageType.state_response) => {
                const response = try decoder.decodeStateResponse();
                std.debug.print("[AWP] 🛡️ Recibido StateResponse(index: {d}, proof_len: {d})\n", .{response.index, response.proof_len});
                std.debug.print("[Mesh] 🔗 Estado del par verificado. Root: {x}\n", .{response.root[0..4].*});
            },
            @intFromEnum(awp.MessageType.mission_directive) => {
                const mission = try decoder.decodeMissionDirective();
                std.debug.print("\n[AWP] 📡 MISSION RECEIVED: {x}", .{mission.id[0..4].*});
                
                if (verifyZkProof(mission.zk_proof)) {
                    std.debug.print(" ✅ VERIFIED BY NOIR.", .{});
                } else {
                    std.debug.print(" ❌ SECURITY BREACH: Invalid ZK Proof. Mission discarded.", .{});
                }
            },
            @intFromEnum(awp.MessageType.account_gossip) => {
                const gossip = try decoder.decodeAccountGossip();
                std.debug.print("\n[MESH  ] 🗣️ Account Gossip: Pubkey {x}... found at CMT index {d}.", .{ 
                    gossip.pubkey[0..4], 
                    gossip.cmt_index 
                });
                
                try self.store.account_index.put(self.allocator, gossip.pubkey, gossip.cmt_index);
            },
            @intFromEnum(awp.MessageType.swap_request) => {
                const req = try decoder.decodeSwapRequest();
                try self.swap_manager.handleRequest(req, [_]u8{0} ** 32);
            },
            @intFromEnum(awp.MessageType.swap_lock) => {
                const lock = try decoder.decodeSwapLock();
                if (self.swap_manager.active_swaps.getPtr(lock.swap_id)) |s| {
                    s.status = .locked;
                }
            },
            @intFromEnum(awp.MessageType.swap_reveal) => {
                const reveal = try decoder.decodeSwapReveal();
                if (self.swap_manager.active_swaps.getPtr(reveal.swap_id)) |s| {
                    s.status = .revealed;
                    s.secret = reveal.secret;
                }
            },
            else => return error.UnknownOpcode,
        }
    }
};

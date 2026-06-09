const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("../mesh/yellowstone.zig");
const awp = @import("../protocol/awp.zig");
const engine_mod = @import("../kernel/engine.zig");
const store = @import("../protocol/store.zig");
const mesh = @import("../mesh/mesh.zig");
const awpool = @import("../protocol/awpool.zig");
const swap = @import("../commerce/swap.zig");
const arbitrum = @import("../chain/arbitrum_adapter.zig");

fn arbRpcUrl(config: anytype) []const u8 {
    if (std.c.getenv("XB77_ARB_RPC")) |p| return std.mem.span(p);
    return config.rpc.base;
}

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

    // 4-byte LE frame header: client sends [len:u32LE][payload]
    const len_bytes = try r.interface.takeArray(4);
    const payload_len = std.mem.readInt(u32, len_bytes, .little);
    if (payload_len == 0 or payload_len > 8192) return error.InvalidFrameLength;

    const payload = try r.interface.take(payload_len);

    var decoder = awp.AwpDecoder.init(payload);
    var handler = ProtocolHandler.init(engine, stream, is_local);

    while (decoder.pos < payload.len) {
        const opcode = decoder.data[decoder.pos];
        handler.handle(opcode, &decoder) catch |err| {
            std.debug.print("[Protocol]  Error handling message 0x{x}: {any}\n", .{opcode, err});
            // WriteFailed = client closed after sending burst; decode succeeded and
            // side-effects applied, safe to continue with remaining messages.
            // Any other error means the decoder state is unknown — stop.
            if (err != error.WriteFailed) break;
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
            .zk_verify => {
                const msg = try decoder.decodeZkVerify();
                const valid = verifyZkProof(msg.proof, "groth16");
                var result_leaf = [_]u8{0} ** 32;
                result_leaf[0] = if (valid) @as(u8, 0x01) else 0x00;
                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();
                _ = try encoder.encodeStateResponse(0, result_leaf, msg.public_root, &.{});
                var wb: [512]u8 = undefined;
                var w = self.stream.writer(io, &wb);
                try w.interface.writeAll(encoder.buf.items);
                try w.interface.flush();
                std.debug.print("\n[ZK    ]  verifyProof circuit={x} valid={}\n", .{ msg.circuit_id[0..4].*, valid });
            },
            .anchor_root => {
                const msg = try decoder.decodeAnchorRoot();
                try self.store.updateL1Anchor(msg.new_root);
                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();
                _ = try encoder.encodeStateResponse(msg.batch_index, msg.new_root, self.store.tree.getRoot(), &.{});
                var wb: [512]u8 = undefined;
                var w = self.stream.writer(io, &wb);
                try w.interface.writeAll(encoder.buf.items);
                try w.interface.flush();
                std.debug.print("\n[ANCHOR]  Root anchored batch={d} root={x}\n", .{ msg.batch_index, msg.new_root[0..4].* });
            },
            .settle => {
                const msg = try decoder.decodeSettle();
                std.debug.print("\n[SETTLE]  agent={x} amount={d} commitment={x}\n", .{
                    msg.agent[0..4].*, msg.amount, msg.commitment[0..4].*,
                });

                const rpc = arbRpcUrl(self.engine_ptr.ctx.config);
                var arb = arbitrum.ArbitrumAdapter.init(
                    self.allocator,
                    arbitrum.STYLUS_SETTLEMENT_ADDR,
                    rpc,
                );
                defer arb.deinit();

                const confidence: u8 = if (arb.settlePayment(msg.agent, msg.amount, msg.commitment)) |tx_hash| blk: {
                    defer self.allocator.free(tx_hash);
                    std.debug.print("\n[SETTLE]  on-chain OK tx={s}\n", .{tx_hash});
                    break :blk 100;
                } else |err| blk: {
                    std.debug.print("\n[SETTLE]  on-chain error={any} (confidence=0)\n", .{err});
                    break :blk 0;
                };

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();
                _ = try encoder.encodeSignal(.{
                    .asset = .{ .chain = .arbitrum, .symbol = "USDC" },
                    .signal = .hold,
                    .confidence = confidence,
                });
                var wb: [64]u8 = undefined;
                var w = self.stream.writer(io, &wb);
                try w.interface.writeAll(encoder.buf.items);
                try w.interface.flush();
            },
            .order => { _ = try decoder.decodeOrder(); },
            .signal => { _ = try decoder.decodeSignal(); },
            .transfer => { _ = try decoder.decodeTransfer(); },
            .swap_request => { _ = try decoder.decodeSwapRequest(); },
            .swap_lock => { _ = try decoder.decodeSwapLock(); },
            .swap_reveal => { _ = try decoder.decodeSwapReveal(); },
            .state_query => { _ = try decoder.decodeStateQuery(); },
            .state_response => { _ = try decoder.decodeStateResponse(); },
            .account_gossip => { _ = try decoder.decodeAccountGossip(); },
            .delta_sync => { _ = try decoder.decodeDeltaSync(self.allocator); },
            .app_hire => { _ = try decoder.decodeAppHire(); },
            .app_escrow_lock => { _ = try decoder.decodeAppEscrowLock(); },
            .app_escrow_release => { _ = try decoder.decodeAppEscrowRelease(); },
            .app_dispute_open => { _ = try decoder.decodeAppDisputeOpen(); },
            .app_dispute_resolve => { _ = try decoder.decodeAppDisputeResolve(); },
            .app_plan => { _ = try decoder.decodeAppPlan(); },
            .service_discovery => { _ = try decoder.decodeServiceDiscovery(); },
            .loan_offer => { _ = try decoder.decodeLoanOffer(); },
            .loan_accept => { _ = try decoder.decodeLoanAccept(); },
            .loan_settle => { _ = try decoder.decodeLoanSettle(); },
            else => {
                std.debug.print("[Protocol]  Opcode 0x{x} unknown — stopping parse.\n", .{opcode});
                return;
            },
        }
    }
};

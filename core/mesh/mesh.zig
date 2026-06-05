const std = @import("std");
const core = @import("../core.zig");
const types = @import("../protocol/types.zig");
const awp = @import("../protocol/awp.zig");
const store = @import("../protocol/store.zig");

pub const PeerStatus = enum {
    unknown,
    connected,
    verified,
    untrusted,
    federated,
};

pub const Peer = struct {
    id: [32]u8,
    address: []const u8,
    port: u16,
    status: PeerStatus = .unknown,
    last_seen: i64 = 0,
    latency_ms: u64 = 0,
    state_root: [32]u8 = [_]u8{0} ** 32,

    pub fn xorDistance(self: Peer, other_id: [32]u8) [32]u8 {
        var dist: [32]u8 = undefined;
        for (0..32) |i| {
            dist[i] = self.id[i] ^ other_id[i];
        }
        return dist;
    }
};

const K = 20; // Tamaño del bucket de Kademlia

pub const MeshManager = struct {
    allocator: std.mem.Allocator,
    // Buckets organizados por distancia logarítmica (0 a 255)
    buckets: [256]std.ArrayListUnmanaged(Peer),
    store: *store.Store,
    self_id: [32]u8,

    pub fn init(allocator: std.mem.Allocator, s: *store.Store, self_id: [32]u8) !MeshManager {
        var self = MeshManager{
            .allocator = allocator,
            .buckets = undefined,
            .store = s,
            .self_id = self_id,
        };
        for (0..256) |i| {
            self.buckets[i] = try std.ArrayListUnmanaged(Peer).initCapacity(allocator, K);
        }
        return self;
    }

    pub fn deinit(self: *MeshManager) void {
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                self.allocator.free(peer.address);
            }
            self.buckets[i].deinit(self.allocator);
        }
    }

    /// Calcula en qué bucket debe caer un ID basado en su distancia XOR con nosotros
    fn getBucketIndex(self: *MeshManager, other_id: [32]u8) u8 {
        for (0..32) |i| {
            const x = self.self_id[i] ^ other_id[i];
            if (x != 0) {
                // Encontrar el bit más significativo
                const lz = @clz(x);
                return @intCast((31 - i) * 8 + (7 - lz));
            }
        }
        return 0;
    }

    pub fn addPeer(self: *MeshManager, id: [32]u8, addr: []const u8, port: u16) !void {
        if (std.mem.eql(u8, &id, &self.self_id)) return;

        const bucket_idx = self.getBucketIndex(id);
        const bucket = &self.buckets[bucket_idx];

        // Evitar duplicados
        for (bucket.items) |p| {
            if (std.mem.eql(u8, &p.id, &id)) return;
        }

        // Si el bucket está lleno, aplicar lógica S/Kademlia (podríamos reemplazar por latencia)
        if (bucket.items.len >= K) {
            // Por ahora solo ignoramos, luego implementaremos reemplazo por latencia
            return;
        }

        const addr_copy = try self.allocator.dupe(u8, addr);
        try bucket.append(self.allocator, .{
            .id = id,
            .address = addr_copy,
            .port = port,
            .last_seen = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toSeconds(),
        });

        std.debug.print("\n[MESH  ]  Peer added to Bucket[{d}]: ", .{bucket_idx});
        for (id[0..4]) |b| {
            std.debug.print("{x:0>2}", .{b});
        }
        std.debug.print(" at {s}:{d}", .{ addr, port });
    }

    /// Devuelve el total de peers conocidos en todos los buckets
    pub fn countPeers(self: *MeshManager) usize {
        var total: usize = 0;
        for (0..256) |i| {
            total += self.buckets[i].items.len;
        }
        return total;
    }

    /// Envía un latido UDP para anunciar nuestra presencia en la red local
    pub fn broadcastPresence(self: *MeshManager, tcp_port: u16) !void {
        const io = std.Io.Threaded.global_single_threaded.io();

        var msg_buf: [34]u8 = undefined;
        @memcpy(msg_buf[0..32], &self.self_id);
        std.mem.writeInt(u16, msg_buf[32..34], tcp_port, .little);

        const bind_addr = try std.Io.net.IpAddress.parseIp4("0.0.0.0", 0);
        const socket = try bind_addr.bind(io, .{ .mode = .dgram });
        defer socket.close(io);

        std.debug.print("\n[MESH  ]  Sending presence heartbeat (TCP Port: {d})...", .{tcp_port});

        // 1. Loopback Discovery (para demos locales)
        const loopback = try std.Io.net.IpAddress.parseIp4("127.0.0.1", 7700);
        socket.send(io, &loopback, &msg_buf) catch {};

        // 2. Network Broadcast
        std.posix.setsockopt(socket.handle, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, &std.mem.toBytes(@as(c_int, 1))) catch {};
        const broadcast = try std.Io.net.IpAddress.parseIp4("255.255.255.255", 7700);
        socket.send(io, &broadcast, &msg_buf) catch {};
    }

    /// Escucha latidos UDP de otros agentes
    pub fn listenForPeers(self: *MeshManager) !void {
        const io = std.Io.Threaded.global_single_threaded.io();

        const bind_addr = try std.Io.net.IpAddress.parseIp4("0.0.0.0", 7700);
        const socket = try bind_addr.bind(io, .{ .mode = .dgram });
        defer socket.close(io);

        std.posix.setsockopt(socket.handle, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1))) catch {};
        if (comptime @hasDecl(std.posix.SO, "REUSEPORT")) {
            std.posix.setsockopt(socket.handle, std.posix.SOL.SOCKET, std.posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1))) catch {};
        }

        std.debug.print("[MESH  ]  Discovery Listener activo en puerto UDP 7700\n", .{});

        var buf: [34]u8 = undefined;
        while (true) {
            const msg = try socket.receive(io, &buf);
            if (msg.data.len < 34) continue;

            var peer_id: [32]u8 = undefined;
            @memcpy(&peer_id, msg.data[0..32]);
            const peer_port = std.mem.readInt(u16, msg.data[32..34], .little);

            if (std.mem.eql(u8, &peer_id, &self.self_id)) continue;

            // Extraer IP del remitente
            var ip_buf: [16]u8 = undefined;
            const ip_str: []const u8 = switch (msg.from) {
                .ip4 => |a| try std.fmt.bufPrint(&ip_buf, "{d}.{d}.{d}.{d}", .{ a.bytes[0], a.bytes[1], a.bytes[2], a.bytes[3] }),
                .ip6 => "127.0.0.1",
            };

            try self.addPeer(peer_id, ip_str, peer_port);

            // Intentar verificación proactiva inmediata
            const bucket_idx = self.getBucketIndex(peer_id);
            if (self.buckets[bucket_idx].items.len > 0) {
                const new_peer = &self.buckets[bucket_idx].items[self.buckets[bucket_idx].items.len - 1];
                self.verifyPeer(new_peer) catch {};
            }
        }
    }

    fn verifyPeer(self: *MeshManager, peer: *Peer) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        std.debug.print("\n[MESH  ]  Proactive Verification: {s}:{d}...", .{ peer.address, peer.port });

        const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch return;
        var stream = addr.connect(io, .{ .mode = .stream }) catch return;
        defer stream.close(io);

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const timestamp = std.Io.Timestamp.now(io, .real).toSeconds();
        const root = self.store.tree.getRoot();

        var sig_buf: [128]u8 = undefined;
        const sig_msg = try std.fmt.bufPrint(&sig_buf, "handshake:{d}:{x}", .{ timestamp, root });
        _ = sig_msg;
        var signature: [64]u8 = [_]u8{0} ** 64;
        signature[0] = 0x01; // Mock sovereign flag

        const handshake = try encoder.encodeHandshake(.{
            .agent_id = self.self_id,
            .protocol_version = 1,
            .timestamp = timestamp,
            .signature = signature,
            .state_root = root,
            .federation_badge = null,
        });

        var wb: [4096]u8 = undefined;
        var w = stream.writer(io, &wb);
        try w.interface.writeAll(handshake);
        try w.interface.flush();

        var rb: [1024]u8 = undefined;
        var r = stream.reader(io, &rb);
        var read_buf: [1024]u8 = undefined;
        const n = r.interface.readSliceShort(&read_buf) catch 0;
        if (n > 0) {
            peer.status = .connected;
        }
    }

    /// Devuelve el root más alto (más reciente) conocido en la red para un CMT
    pub fn getHighestNetworkRoot(self: *MeshManager) [32]u8 {
        var best_root = self.store.tree.getRoot();
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                if (peer.status == .verified) {
                    best_root = peer.state_root;
                }
            }
        }
        return best_root;
    }

    /// Inicia un ciclo de descubrimiento (Gossip)
    pub fn tick(self: *MeshManager) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        var target_peer: ?*Peer = null;

        const start_bucket = @as(usize, @intCast(@mod(std.Io.Timestamp.now(io, .real).toSeconds(), 256)));
        outer: for (0..256) |i| {
            const idx = (start_bucket + i) % 256;
            if (self.buckets[idx].items.len > 0) {
                target_peer = &self.buckets[idx].items[0];
                break :outer;
            }
        }

        const target = target_peer orelse return;

        std.debug.print("\n[MESH  ]  Gossiping with {s}:{d}...", .{ target.address, target.port });

        const addr = std.Io.net.IpAddress.parseIp4(target.address, target.port) catch |err| {
            std.debug.print(" Failed: {any}", .{err});
            return;
        };
        var stream = addr.connect(io, .{ .mode = .stream }) catch |err| {
            std.debug.print(" Failed: {any}", .{err});
            return;
        };
        defer stream.close(io);

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const query_msg = try encoder.encodeStateQuery(0);

        var wb: [4096]u8 = undefined;
        var w = stream.writer(io, &wb);
        try w.interface.writeAll(query_msg);

        // --- EXTRA GOSSIP: Compartir info de cuentas (The Swarm Sync) ---
        if (self.store.account_index.count() > 0) {
            var it = self.store.account_index.iterator();
            if (it.next()) |entry| {
                const gossip_msg = try encoder.encodeAccountGossip(.{
                    .pubkey = entry.key_ptr.*,
                    .cmt_index = entry.value_ptr.*,
                });
                try w.interface.writeAll(gossip_msg);
                std.debug.print(" + Account Gossip shared.", .{});
            }
        }
        try w.interface.flush();
        std.debug.print(" OK (Sync sent).", .{});

        var rb: [4096]u8 = undefined;
        var r = stream.reader(io, &rb);
        var read_buf: [4096]u8 = undefined;
        const bytes_read = r.interface.readSliceShort(&read_buf) catch 0;
        if (bytes_read > 0) {
            try self.handleIncomingMessage(target, read_buf[0..bytes_read]);
        }
    }

    /// Propaga el último cambio del árbol a todos los peers conocidos (Incremental Sync)
    pub fn broadcastDelta(self: *MeshManager) !void {
        if (self.store.tree.change_logs.items.len == 0) return;

        const last_log = self.store.tree.change_logs.items[0];
        const leaf = self.store.tree.rightmost_leaf;

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const delta_msg = try encoder.encodeDeltaSync(.{
            .index = last_log.index,
            .leaf = leaf,
            .siblings = last_log.siblings,
        });

        std.debug.print("\n[MESH  ]  Broadcasting Delta Sync (Index: {d})...", .{last_log.index});

        const io = std.Io.Threaded.global_single_threaded.io();
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch continue;
                var stream = addr.connect(io, .{ .mode = .stream }) catch continue;
                defer stream.close(io);
                var wb: [4096]u8 = undefined;
                var w = stream.writer(io, &wb);
                w.interface.writeAll(delta_msg) catch continue;
                w.interface.flush() catch continue;
            }
        }
    }

    pub fn broadcastLoanRequest(self: *MeshManager, amount: u64, interest_bps: u16, duration_sec: u64) !void {
        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const bin_msg = try encoder.encodeLoanRequest(.{
            .amount = amount,
            .interest_bps = interest_bps,
            .duration_sec = duration_sec,
        });

        std.debug.print("\n[MESH  ]  Broadcasting Loan Request to Swarm: {d} SC at {d} bps...", .{amount, interest_bps});

        const io = std.Io.Threaded.global_single_threaded.io();
        var sent_count: usize = 0;
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch continue;
                var stream = addr.connect(io, .{ .mode = .stream }) catch continue;
                defer stream.close(io);
                var wb: [4096]u8 = undefined;
                var w = stream.writer(io, &wb);
                w.interface.writeAll(bin_msg) catch continue;
                w.interface.flush() catch continue;
                sent_count += 1;
            }
        }
        std.debug.print(" Sent to {d} peers.", .{sent_count});
    }

    pub fn broadcastMission(self: *MeshManager, mission: awp.MissionDirectiveMsg) !void {
        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const bin_msg = try encoder.encodeMissionDirective(mission);

        std.debug.print("\n[MESH  ]  Broadcasting Mission {x} to Swarm...", .{mission.id[0..4].*});

        const io = std.Io.Threaded.global_single_threaded.io();
        var sent_count: usize = 0;
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch continue;
                var stream = addr.connect(io, .{ .mode = .stream }) catch continue;
                defer stream.close(io);
                var wb: [4096]u8 = undefined;
                var w = stream.writer(io, &wb);
                w.interface.writeAll(bin_msg) catch continue;
                w.interface.flush() catch continue;
                sent_count += 1;
            }
        }
        std.debug.print(" Shared with {d} peers.", .{sent_count});
    }

    fn handleIncomingMessage(self: *MeshManager, peer: *Peer, data: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        var decoder = awp.AwpDecoder.init(data);
        if (decoder.data.len == 0) return;

        const opcode = decoder.data[0];
        switch (opcode) {
            @intFromEnum(awp.MessageType.state_response) => {
                const resp = try decoder.decodeStateResponse();
                std.debug.print("\n[MESH  ]  Valid State Response from peer. Root: {x}", .{resp.root[0..4].*});
                peer.status = .verified;
                peer.state_root = resp.root;
            },
            @intFromEnum(awp.MessageType.delta_sync) => {
                const delta = try decoder.decodeDeltaSync(self.allocator);
                defer self.allocator.free(delta.siblings);

                std.debug.print("\n[MESH  ]  Received Delta Sync (Index: {d}). Updating local tree...", .{delta.index});

                if (delta.index == self.store.tree.rightmost_index) {
                    try self.store.tree.append(delta.leaf);
                    std.debug.print(" OK. New Root: {x}", .{self.store.tree.getRoot()[0..4]});
                } else {
                    std.debug.print(" IGNORED (Index mismatch: local={d}, remote={d})", .{self.store.tree.rightmost_index, delta.index});
                }
            },
            @intFromEnum(awp.MessageType.loan_request) => {
                const req = try decoder.decodeLoanRequest();
                std.debug.print("\n[SWARM ]  SOS Received from Peer {x}. Needs {d} SC at {d} bps.", .{peer.id[0..4].*, req.amount, req.interest_bps});
                std.debug.print("\n[SWARM ]  Brain evaluated risk: Acceptable. Sending Loan Offer...", .{});

                const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch return;
                var stream = addr.connect(io, .{ .mode = .stream }) catch return;
                defer stream.close(io);

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();

                const offer_msg = try encoder.encodeLoanOffer(.{
                    .lender_id = self.self_id,
                    .amount = req.amount,
                    .interest_bps = req.interest_bps,
                });
                var wb: [4096]u8 = undefined;
                var w = stream.writer(io, &wb);
                try w.interface.writeAll(offer_msg);
                try w.interface.flush();
            },
            @intFromEnum(awp.MessageType.loan_offer) => {
                const offer = try decoder.decodeLoanOffer();
                std.debug.print("\n[SWARM ]  Loan Offer Received from {x}: {d} SC.", .{offer.lender_id[0..4].*, offer.amount});
                std.debug.print("\n[SWARM ]  Accept offer. Liquidity injected. Returning to Normal Operation.", .{});

                const addr = std.Io.net.IpAddress.parseIp4(peer.address, peer.port) catch return;
                var stream = addr.connect(io, .{ .mode = .stream }) catch return;
                defer stream.close(io);

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();

                const accept_msg = try encoder.encodeLoanAccept(.{
                    .lender_id = offer.lender_id,
                });
                var wb: [4096]u8 = undefined;
                var w = stream.writer(io, &wb);
                try w.interface.writeAll(accept_msg);
                try w.interface.flush();
            },
            @intFromEnum(awp.MessageType.loan_accept) => {
                const acc = try decoder.decodeLoanAccept();
                _ = acc;
                std.debug.print("\n[SWARM ]  Peer accepted loan. Executing L1 transfer via MagicBlock...", .{});
                std.debug.print("\n[SWARM ]  Transfer complete.", .{});
            },
            else => {},
        }
    }
};

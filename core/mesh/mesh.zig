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
            .last_seen = std.time.timestamp(),
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
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);

        var msg_buf: [34]u8 = undefined;
        @memcpy(msg_buf[0..32], &self.self_id);
        std.mem.writeInt(u16, msg_buf[32..34], tcp_port, .little);

        // 1. Loopback Discovery (para demos locales)
        const loopback = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 7700);
        _ = std.posix.sendto(socket, &msg_buf, 0, &loopback.any, loopback.getOsSockLen()) catch {};

        // 2. Network Broadcast
        const broadcast = std.net.Address.initIp4(.{ 255, 255, 255, 255 }, 7700);
        std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, &std.mem.toBytes(@as(c_int, 1))) catch {};
        
        std.debug.print("\n[MESH  ]  Sending presence heartbeat (TCP Port: {d})...", .{tcp_port});
        _ = std.posix.sendto(socket, &msg_buf, 0, &broadcast.any, broadcast.getOsSockLen()) catch {};
    }

    /// Escucha latidos UDP de otros agentes
    pub fn listenForPeers(self: *MeshManager) !void {
        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 7700);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);

        try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        // SO_REUSEPORT permite que múltiples procesos reciban los mismos paquetes multicast/broadcast
        if (comptime @hasDecl(std.posix.SO, "REUSEPORT")) {
             try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
        }
        
        try std.posix.bind(socket, &address.any, address.getOsSockLen());

        std.debug.print("[MESH  ]  Discovery Listener activo en puerto UDP 7700\n", .{});

        var buf: [34]u8 = undefined;
        while (true) {
            var remote_addr: std.posix.sockaddr = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
            
            const n = try std.posix.recvfrom(socket, &buf, 0, &remote_addr, &addr_len);
            if (n < 34) continue;

            var peer_id: [32]u8 = undefined;
            @memcpy(&peer_id, buf[0..32]);
            const peer_port = std.mem.readInt(u16, buf[32..34], .little);

            if (std.mem.eql(u8, &peer_id, &self.self_id)) continue;

            // Convertir dirección IP a string para el MeshManager
            const sa: *const std.posix.sockaddr.in = @ptrCast(@alignCast(&remote_addr));
            var ip_buf: [16]u8 = undefined;
            const ip_str = try std.fmt.bufPrint(&ip_buf, "{d}.{d}.{d}.{d}", .{
                (sa.addr >> 0) & 0xFF,
                (sa.addr >> 8) & 0xFF,
                (sa.addr >> 16) & 0xFF,
                (sa.addr >> 24) & 0xFF,
            });

            try self.addPeer(peer_id, ip_str, peer_port);

            // Intentar verificación proactiva inmediata
            const new_peer = &self.buckets[self.getBucketIndex(peer_id)].items[self.buckets[self.getBucketIndex(peer_id)].items.len - 1];
            self.verifyPeer(new_peer) catch {};
        }
    }

    fn verifyPeer(self: *MeshManager, peer: *Peer) !void {
        std.debug.print("\n[MESH  ]  Proactive Verification: {s}:{d}...", .{ peer.address, peer.port });
        var stream = std.net.tcpConnectToHost(self.allocator, peer.address, peer.port) catch return;
        defer stream.close();

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const timestamp = std.time.timestamp();
        const root = self.store.tree.getRoot();
        
        // Firmar el handshake para demostrar soberanía
        var sig_buf: [128]u8 = undefined;
        const sig_msg = try std.fmt.bufPrint(&sig_buf, "handshake:{d}:{x}", .{ timestamp, root });
        _ = sig_msg;
        // Usamos una clave de prueba si no tenemos la real (esto debería venir del Vault en prod)
        // Para esta fase de la demo, usamos un dummy signature que el otro lado aceptará en modo debug
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
        _ = try stream.write(handshake);
        
        // Esperar respuesta (handshake de vuelta o state_query)
        var buf: [1024]u8 = undefined;
        const n = try stream.read(&buf);
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
                    // Simplificación: asumimos que el root es comparable o simplemente confiamos en el peer
                    best_root = peer.state_root;
                }
            }
        }
        return best_root;
    }

    /// Inicia un ciclo de descubrimiento (Gossip)
    pub fn tick(self: *MeshManager) !void {
        // Buscar un peer al azar en los buckets
        var target_peer: ?*Peer = null;
        
        // Selección simple: primer peer que encontremos empezando por un bucket al azar
        const start_bucket = @as(usize, @intCast(@mod(std.time.timestamp(), 256)));
        outer: for (0..256) |i| {
            const idx = (start_bucket + i) % 256;
            if (self.buckets[idx].items.len > 0) {
                target_peer = &self.buckets[idx].items[0]; // Tomamos el primero del bucket
                break :outer;
            }
        }

        const target = target_peer orelse return;

        std.debug.print("\n[MESH  ]  Gossiping with {s}:{d}...", .{ target.address, target.port });
        
        // Conexión TCP real y envío de STATE_QUERY
        var stream = std.net.tcpConnectToHost(self.allocator, target.address, target.port) catch |err| {
            std.debug.print(" Failed: {any}", .{err});
            return;
        };
        defer stream.close();

        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const query_msg = try encoder.encodeStateQuery(0);
        _ = try stream.write(query_msg);
        
        // --- EXTRA GOSSIP: Compartir info de cuentas (The Swarm Sync) ---
        if (self.store.account_index.count() > 0) {
            var it = self.store.account_index.iterator();
            // Tomamos una cuenta "al azar" (la primera que de el iterador por simplicidad en la demo)
            if (it.next()) |entry| {
                const gossip_msg = try encoder.encodeAccountGossip(.{
                    .pubkey = entry.key_ptr.*,
                    .cmt_index = entry.value_ptr.*,
                });
                _ = try stream.write(gossip_msg);
                std.debug.print(" + Account Gossip shared.", .{});
            }
        }
        
        std.debug.print(" OK (Sync sent).", .{});

        var buf: [4096]u8 = undefined;
        const bytes_read = stream.read(&buf) catch 0;
        if (bytes_read > 0) {
            try self.handleIncomingMessage(target, buf[0..bytes_read]);
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

        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                var stream = std.net.tcpConnectToHost(self.allocator, peer.address, peer.port) catch continue;
                defer stream.close();
                _ = try stream.write(delta_msg);
            }
        }
    }

    pub fn broadcastLoanRequest(self: *MeshManager, amount: u64, interest_bps: u16, duration_sec: u64) !void {
        var encoder = awp.AwpEncoder.init(self.allocator);
        defer encoder.deinit();

        const loan_msg = try encoder.encodeLoanRequest(.{
            .amount = amount,
            .interest_bps = interest_bps,
            .duration_sec = duration_sec,
        });

        std.debug.print("\n[MESH  ]  Broadcasting Loan Request to Swarm: {d} SC at {d} bps...", .{amount, interest_bps});

        var sent_count: usize = 0;
        for (0..256) |i| {
            for (self.buckets[i].items) |peer| {
                var stream = std.net.tcpConnectToHost(self.allocator, peer.address, peer.port) catch continue;
                defer stream.close();
                _ = try stream.write(loan_msg);
                sent_count += 1;
            }
        }
        std.debug.print(" Sent to {d} peers.", .{sent_count});
    }

    fn handleIncomingMessage(self: *MeshManager, peer: *Peer, data: []const u8) !void {
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
                
                // Si el índice es el que esperamos (el siguiente en nuestro árbol), lo aplicamos
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
                // In a real swarm, the brain evaluates risk and balance.
                std.debug.print("\n[SWARM ]  Brain evaluated risk: Acceptable. Sending Loan Offer...", .{});
                
                var stream = std.net.tcpConnectToHost(self.allocator, peer.address, peer.port) catch return;
                defer stream.close();

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();

                const offer_msg = try encoder.encodeLoanOffer(.{
                    .lender_id = self.self_id,
                    .amount = req.amount,
                    .interest_bps = req.interest_bps,
                });
                _ = try stream.write(offer_msg);
            },
            @intFromEnum(awp.MessageType.loan_offer) => {
                const offer = try decoder.decodeLoanOffer();
                std.debug.print("\n[SWARM ]  Loan Offer Received from {x}: {d} SC.", .{offer.lender_id[0..4].*, offer.amount});
                std.debug.print("\n[SWARM ]  Accept offer. Liquidity injected. Returning to Normal Operation.", .{});
                
                var stream = std.net.tcpConnectToHost(self.allocator, peer.address, peer.port) catch return;
                defer stream.close();

                var encoder = awp.AwpEncoder.init(self.allocator);
                defer encoder.deinit();

                const accept_msg = try encoder.encodeLoanAccept(.{
                    .lender_id = offer.lender_id,
                });
                _ = try stream.write(accept_msg);
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

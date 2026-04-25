const std = @import("std");
const core = @import("core.zig");
const types = @import("types.zig");
const awp = @import("awp.zig");
const store = @import("store.zig");

pub const PeerStatus = enum {
    unknown,
    connected,
    verified,
    untrusted,
};

pub const Peer = struct {
    id: [32]u8,
    address: []const u8,
    port: u16,
    status: PeerStatus = .unknown,
    last_seen: i64 = 0,
    state_root: [32]u8 = [_]u8{0} ** 32,
};

pub const MeshManager = struct {
    allocator: std.mem.Allocator,
    peers: std.ArrayListUnmanaged(Peer),
    store: *store.Store,
    self_id: [32]u8,

    pub fn init(allocator: std.mem.Allocator, s: *store.Store, self_id: [32]u8) !MeshManager {
        return .{
            .allocator = allocator,
            .peers = try std.ArrayListUnmanaged(Peer).initCapacity(allocator, 16),
            .store = s,
            .self_id = self_id,
        };
    }

    pub fn deinit(self: *MeshManager) void {
        for (self.peers.items) |peer| {
            self.allocator.free(peer.address);
        }
        self.peers.deinit(self.allocator);
    }

    pub fn addPeer(self: *MeshManager, id: [32]u8, addr: []const u8, port: u16) !void {
        // Evitar duplicados
        for (self.peers.items) |p| {
            if (std.mem.eql(u8, &p.id, &id)) return;
        }

        const addr_copy = try self.allocator.dupe(u8, addr);
        try self.peers.append(self.allocator, .{
            .id = id,
            .address = addr_copy,
            .port = port,
            .last_seen = std.time.timestamp(),
        });

        std.debug.print("\n[MESH  ] 🕸️ New Peer discovered: ", .{});
        for (id[0..4]) |b| {
            std.debug.print("{x:0>2}", .{b});
        }
        std.debug.print(" at {s}:{d}", .{ addr, port });
    }

    /// Inicia un ciclo de descubrimiento (Gossip)
    pub fn tick(self: *MeshManager) !void {
        if (self.peers.items.len == 0) return;

        // Seleccionar un par al azar (simulado por ahora)
        const peer_idx = @as(usize, @intCast(@mod(std.time.timestamp(), @as(i64, @intCast(self.peers.items.len)))));
        const target = &self.peers.items[peer_idx];

        std.debug.print("\n[MESH  ] 📡 Gossiping with {s}:{d}...", .{ target.address, target.port });
        
        // Aquí vendría la lógica de conexión y envío de STATE_QUERY
    }
};

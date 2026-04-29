const std = @import("std");
const core = @import("../core.zig");
const store = @import("../state/store.zig");

pub const SovereignPortal = struct {
    allocator: std.mem.Allocator,
    store: *store.Store,
    vaults: *@import("../state/vault.zig").VaultSet,
    mesh: *@import("../net/mesh.zig").MeshManager,
    port: u16,

    pub fn init(allocator: std.mem.Allocator, s: *store.Store, v: *@import("../state/vault.zig").VaultSet, m: *@import("../net/mesh.zig").MeshManager, port: u16) SovereignPortal {
        return .{
            .allocator = allocator,
            .store = s,
            .vaults = v,
            .mesh = m,
            .port = port,
        };
    }

    pub fn start(self: *SovereignPortal) !void {
        const address = try std.net.Address.parseIp("0.0.0.0", self.port);
        var server = try address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("[PORTAL] 🌐 Sovereign Gateway active at http://0.0.0.0:{d}\n", .{self.port});

        while (true) {
            const conn = try server.accept();
            try self.handleRequest(conn.stream);
        }
    }

    fn handleRequest(self: *SovereignPortal, stream: std.net.Stream) !void {
        defer stream.close();
        var buf: [4096]u8 = undefined;
        const n = try stream.read(&buf);
        if (n == 0) return;

        const request = buf[0..n];
        
        // Router de API minimalista
        if (std.mem.indexOf(u8, request, "GET /status") != null) {
            try self.sendJsonResponse(stream, 200, try self.getStatusJson());
        } else if (std.mem.indexOf(u8, request, "GET /balance") != null) {
            try self.sendJsonResponse(stream, 200, try self.getBalanceJson());
        } else if (std.mem.indexOf(u8, request, "GET /proof") != null) {
            // Extraer el índice de la query string (simplificado)
            const proof_json = try self.getProofJson(request);
            try self.sendJsonResponse(stream, 200, proof_json);
        } else {
            try self.sendJsonResponse(stream, 404, "{\"error\": \"Not Found\"}");
        }
    }

    fn getProofJson(self: *SovereignPortal, request: []const u8) ![]const u8 {
        // Parseo rústico de ?index=X
        var index: u64 = 0;
        if (std.mem.indexOf(u8, request, "index=")) |pos| {
            const idx_start = pos + 6;
            var end = idx_start;
            while (end < request.len and std.ascii.isDigit(request[end])) : (end += 1) {}
            index = std.fmt.parseInt(u64, request[idx_start..end], 10) catch 0;
        }

        const max_idx = self.store.tree.rightmost_index;
        if (index >= max_idx) return try self.allocator.dupe(u8, "{\"error\": \"Index out of bounds\"}");

        const proof = try self.allocator.alloc([32]u8, self.store.tree.depth);
        defer self.allocator.free(proof);
        
        try self.store.tree.getProof(index, proof);

        // Construir JSON de la prueba
        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(self.allocator);
        const w = list.writer(self.allocator);

        try w.print("{{\"index\": {d}, \"proof\": [", .{index});
        for (proof, 0..) |p, i| {
            try w.print("\"{x}\"{s}", .{ p[0..4].*, if (i == proof.len - 1) "" else ", " });
        }
        try w.print("], \"root\": \"{x}\"}}", .{self.store.tree.getRoot()[0..4].*});

        return list.toOwnedSlice(self.allocator);
    }

    fn getStatusJson(self: *SovereignPortal) ![]const u8 {
        const root = self.store.tree.getRoot();
        const entries = self.store.tree.rightmost_index;
        const peers = self.mesh.countPeers();

        return try std.fmt.allocPrint(self.allocator, 
            \\{{"status": "active", "merkle_root": "{x}", "total_entries": {d}, "mesh_peers": {d}, "version": "0.1.0"}}
        , .{ root[0..4], entries, peers });
    }

    fn getBalanceJson(self: *SovereignPortal) ![]const u8 {
        const sol_addr = try self.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);
        
        return try std.fmt.allocPrint(self.allocator, 
            \\{{"address": "{s}", "balances": {{"sol": 0, "compressed": 0}}}}
        , .{ sol_addr });
    }

    fn sendJsonResponse(_: *SovereignPortal, stream: std.net.Stream, status: u16, body: []const u8) !void {
        var buf: [4096]u8 = undefined;
        const response = try std.fmt.bufPrint(&buf, 
            "HTTP/1.1 {d} OK\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Connection: close\r\n\r\n" ++
            "{s}",
            .{ status, body.len, body }
        );
        _ = try stream.write(response);
    }
};

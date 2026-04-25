const std = @import("std");
const crypto = @import("crypto.zig");

/// Concurrent Merkle Tree (CMT) - xB77 Sovereign Implementation
/// Basado en "Compressing Digital Assets with Concurrent Merkle Trees" (Xiao et al.)
/// Permite compresión ZK y actualizaciones concurrentes en la Mesh P2P.

pub const CMTError = error{
    TreeFull,
    InvalidProof,
    IndexOutOfBounds,
};

pub const ConcurrentMerkleTree = struct {
    allocator: std.mem.Allocator,
    depth: u8,
    
    // El Buffer de Raíces históricas para permitir concurrencia
    root_buffer: std.ArrayListUnmanaged([32]u8),
    
    // El Change Log que guarda los siblings de las inserciones recientes
    change_logs: std.ArrayListUnmanaged(ChangeLog),
    
    // El estado actual de la rama derecha (para appends rápidos)
    rightmost_proof: std.ArrayListUnmanaged([32]u8),
    rightmost_index: u64,
    rightmost_leaf: [32]u8,

    max_buffer_size: usize = 1024,

    pub const ChangeLog = struct {
        index: u64,
        siblings: [][32]u8,
    };

    pub fn init(allocator: std.mem.Allocator, depth: u8) !ConcurrentMerkleTree {
        var tree = ConcurrentMerkleTree{
            .allocator = allocator,
            .depth = depth,
            .root_buffer = try std.ArrayListUnmanaged([32]u8).initCapacity(allocator, 1024),
            .change_logs = try std.ArrayListUnmanaged(ChangeLog).initCapacity(allocator, 1024),
            .rightmost_proof = try std.ArrayListUnmanaged([32]u8).initCapacity(allocator, depth),
            .rightmost_index = 0,
            .rightmost_leaf = [_]u8{0} ** 32,
        };

        // Inicializar el árbol vacío (todos ceros)
        const empty_root = try tree.computeEmptyRoot(depth);
        try tree.root_buffer.append(allocator, empty_root);
        
        // Inicializar la prueba derecha con nodos vacíos
        var i: u8 = 0;
        while (i < depth) : (i += 1) {
            try tree.rightmost_proof.append(allocator, try tree.computeEmptyNode(i));
        }

        return tree;
    }

    pub fn deinit(self: *ConcurrentMerkleTree) void {
        self.root_buffer.deinit(self.allocator);
        for (self.change_logs.items) |log| {
            self.allocator.free(log.siblings);
        }
        self.change_logs.deinit(self.allocator);
        self.rightmost_proof.deinit(self.allocator);
    }

    fn computeEmptyNode(self: *const ConcurrentMerkleTree, level: u8) ![32]u8 {
        if (level == 0) return [_]u8{0} ** 32;
        const child = try self.computeEmptyNode(level - 1);
        var out: [32]u8 = undefined;
        
        // H(child, child)
        var hasher = crypto.Keccak256.init(.{});
        hasher.update(&child);
        hasher.update(&child);
        hasher.final(&out);
        return out;
    }

    fn computeEmptyRoot(self: *const ConcurrentMerkleTree, depth: u8) ![32]u8 {
        return self.computeEmptyNode(depth);
    }

    /// Implementación del Algoritmo 2: Concurrent Append
    pub fn append(self: *ConcurrentMerkleTree, leaf: [32]u8) !void {
        if (self.rightmost_index >= (@as(u64, 1) << @intCast(self.depth))) return CMTError.TreeFull;

        var node = leaf;
        const index = self.rightmost_index;
        
        // El punto donde el nuevo append intersecta con el árbol existente
        const intersection_level = if (index == 0) self.depth else @as(u8, @intCast(@ctz(index)));

        var siblings = try self.allocator.alloc([32]u8, self.depth);
        errdefer self.allocator.free(siblings);

        var j: u8 = 0;
        while (j < self.depth) : (j += 1) {
            if (j < intersection_level) {
                // Nodo en sub-árbol vacío
                const empty = try self.computeEmptyNode(j);
                siblings[j] = empty;
                node = self.hashNodes(node, empty, false); // node es left, empty es right
                self.rightmost_proof.items[j] = empty;
            } else if (j == intersection_level) {
                // Nodo crítico de intersección
                const sibling = self.rightmost_proof.items[j];
                siblings[j] = sibling;
                node = self.hashNodes(node, sibling, true); // node es right, sibling es left
            } else {
                // Reutilizar nodos de la prueba derecha
                const sibling = self.rightmost_proof.items[j];
                siblings[j] = sibling;
                const node_is_right = (index >> @intCast(j)) & 1 == 1;
                node = self.hashNodes(node, sibling, node_is_right);
            }
        }

        // Actualizar el estado global
        try self.root_buffer.insert(self.allocator, 0, node);
        if (self.root_buffer.items.len > self.max_buffer_size) _ = self.root_buffer.pop();

        try self.change_logs.insert(self.allocator, 0, .{
            .index = index,
            .siblings = siblings,
        });
        if (self.change_logs.items.len > self.max_buffer_size) {
            const old = self.change_logs.pop().?;
            self.allocator.free(old.siblings);
        }

        self.rightmost_index += 1;
        self.rightmost_leaf = leaf;
    }

    fn hashNodes(_: *const ConcurrentMerkleTree, node: [32]u8, sibling: [32]u8, node_is_right: bool) [32]u8 {
        var out: [32]u8 = undefined;
        var hasher = crypto.Keccak256.init(.{});
        if (node_is_right) {
            hasher.update(&sibling);
            hasher.update(&node);
        } else {
            hasher.update(&node);
            hasher.update(&sibling);
        }
        hasher.final(&out);
        return out;
    }

    pub fn getRoot(self: *const ConcurrentMerkleTree) [32]u8 {
        if (self.root_buffer.items.len == 0) return [_]u8{0} ** 32;
        return self.root_buffer.items[0];
    }

    /// Verifica una prueba de inclusión
    pub fn verifyProof(root: [32]u8, leaf: [32]u8, index: u64, proof: [][32]u8) bool {
        var current = leaf;
        for (proof, 0..) |sibling, i| {
            const node_is_right = (index >> @intCast(i)) & 1 == 1;
            var out: [32]u8 = undefined;
            var hasher = crypto.Keccak256.init(.{});
            if (node_is_right) {
                hasher.update(&sibling);
                hasher.update(&current);
            } else {
                hasher.update(&current);
                hasher.update(&sibling);
            }
            hasher.final(&out);
            current = out;
        }
        return std.mem.eql(u8, &current, &root);
    }

    /// Exporta los datos de una prueba al formato Prover.toml de Noir
    pub fn exportToNoir(self: *const ConcurrentMerkleTree, log_index: usize, leaf: [32]u8, root: [32]u8, writer_param: anytype) !void {
        const log = self.change_logs.items[log_index];
        
        // Manejar la inconsistencia de la API de Writer en Zig 0.15.2
        var w = if (comptime @hasField(@TypeOf(writer_param.*), "interface")) writer_param.interface else writer_param;

        try w.print("root = [\n", .{});
        for (root, 0..) |b, i| {
            try w.print("  {d}{s}\n", .{ b, if (i == 31) "" else "," });
        }
        try w.print("]\n\n", .{});

        try w.print("index = {d}\n\n", .{log.index});

        try w.print("leaf = [\n", .{});
        for (leaf, 0..) |b, i| {
            try w.print("  {d}{s}\n", .{ b, if (i == 31) "" else "," });
        }
        try w.print("]\n\n", .{});

        try w.print("siblings = [\n", .{});
        for (log.siblings, 0..) |p, i| {
            try w.print("  [\n", .{});
            for (p, 0..) |b, j| {
                try w.print("    {d}{s}\n", .{ b, if (j == 31) "" else "," });
            }
            try w.print("  ]{s}\n", .{ if (i == log.siblings.len - 1) "" else "," });
        }
        try w.print("]\n", .{});
    }
};

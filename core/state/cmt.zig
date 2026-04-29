const std = @import("std");
const bn254 = @import("../crypto/bn254.zig");
const poseidon = @import("../crypto/poseidon.zig");
const Fr = bn254.Fr;
const Poseidon = poseidon.Poseidon;

/// Concurrent Merkle Tree (CMT) - xB77 Sovereign Implementation (ZK-Native)
/// Basado en "Compressing Digital Assets with Concurrent Merkle Trees" (Xiao et al.)
/// Utiliza Poseidon (BN254) para compatibilidad nativa con Noir y Solana ZK.

// --- C Interface (Legacy for Proof Extraction, logic now in Zig) ---
pub const cmt_hash_t = extern struct {
    hash: [32]u8,
};

pub extern fn cmt_get_proof(tree_nodes: [*]const cmt_hash_t, index: u64, depth: u8, out_siblings: [*]cmt_hash_t) void;

// ----------------------------------------

pub const CMTError = error{
    TreeFull,
    InvalidProof,
    IndexOutOfBounds,
};

pub const ConcurrentMerkleTree = struct {
    allocator: std.mem.Allocator,
    depth: u8,
    
    // Buffer opcional para el árbol completo (inyectado vía mmap por el Store)
    nodes_buffer: ?[*]cmt_hash_t = null,
    
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

        // Inicializar el árbol vacío (nodos base de Poseidon)
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
        
        // H(child, child) usando Poseidon nativo
        const child_u256 = @as(u256, @bitCast(child));
        const hash_val = Poseidon.hash2(child_u256, child_u256);
        return @bitCast(hash_val);
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

        // Si tenemos el buffer binario mapeado, actualizamos el árbol completo en Zig
        if (self.nodes_buffer) |buffer| {
            self.updateNodeInVault(buffer, index, node);
        }
    }

    /// Genera una prueba de inclusión para cualquier índice (Alta Performance)
    pub fn getProof(self: *const ConcurrentMerkleTree, index: u64, out: [][32]u8) !void {
        if (index >= self.rightmost_index) return CMTError.IndexOutOfBounds;
        const buffer = self.nodes_buffer orelse return error.NoBinaryVault;
        
        // Seguimos usando la lógica de navegación de C para la estructura del buffer
        const c_out: [*]cmt_hash_t = @ptrCast(out.ptr);
        cmt_get_proof(buffer, index, self.depth, c_out);
    }

    fn hashNodes(_: *const ConcurrentMerkleTree, node: [32]u8, sibling: [32]u8, node_is_right: bool) [32]u8 {
        const n_u256 = @as(u256, @bitCast(node));
        const s_u256 = @as(u256, @bitCast(sibling));
        
        const hash_val = if (node_is_right) 
            Poseidon.hash2(s_u256, n_u256) 
        else 
            Poseidon.hash2(n_u256, s_u256);
            
        return @bitCast(hash_val);
    }

    pub fn getRoot(self: *const ConcurrentMerkleTree) [32]u8 {
        if (self.nodes_buffer) |buf| {
            return buf[0].hash;
        }
        
        if (self.root_buffer.items.len == 0) {
            return [_]u8{0} ** 32;
        }
        return self.root_buffer.items[0];
    }

    /// Actualiza el nodo en el vault físico usando Poseidon (Zig implementation)
    fn updateNodeInVault(self: *ConcurrentMerkleTree, buffer: [*]cmt_hash_t, leaf_index: u64, new_leaf: [32]u8) void {
        var current_idx = ((@as(u64, 1) << @intCast(self.depth)) - 1) + leaf_index;
        buffer[current_idx].hash = new_leaf;
        
        while (current_idx > 0) {
            const parent_idx = (current_idx - 1) / 2;
            const is_right = current_idx % 2 == 0;
            const sibling_idx = if (is_right) current_idx - 1 else current_idx + 1;
            
            const node = buffer[current_idx].hash;
            const sibling = buffer[sibling_idx].hash;
            
            buffer[parent_idx].hash = self.hashNodes(node, sibling, is_right);
            current_idx = parent_idx;
        }
    }

    /// Inicializa el buffer binario con los hashes de nodos vacíos correctos para cada nivel.
    pub fn initializeEmptyVault(self: *ConcurrentMerkleTree) !void {
        const buffer = self.nodes_buffer orelse return;
        const total_nodes = (@as(u64, 1) << @as(u6, @intCast(self.depth + 1))) - 1;

        // 1. Llenar todo con ceros primero (hojas vacías)
        @memset(buffer[0..total_nodes], .{ .hash = [_]u8{0} ** 32 });

        // 2. Calcular y llenar los nodos internos de abajo hacia arriba
        var level: u8 = 1;
        while (level <= self.depth) : (level += 1) {
            const empty_hash = try self.computeEmptyNode(level);
            const level_start = (@as(u64, 1) << @as(u6, @intCast(self.depth - level))) - 1;
            const level_end = (@as(u64, 1) << @as(u6, @intCast(self.depth - level + 1))) - 1;

            var i = level_start;
            while (i < level_end) : (i += 1) {
                buffer[i].hash = empty_hash;
            }
        }
        
        // 3. El root (nivel depth) también debe ser el empty root
        buffer[0].hash = try self.computeEmptyRoot(self.depth);
    }

    /// Reconstruye la rama derecha desde el buffer binario.
    pub fn reconstructRightmostPath(self: *ConcurrentMerkleTree) !void {
        const buffer = self.nodes_buffer orelse return;
        if (self.rightmost_index == 0) return;

        std.debug.print("\n[CMT   ] 🔄 Reconstructing with Poseidon from Index: {d}, Vault Root: {x}...", .{
            self.rightmost_index, buffer[0].hash[0..4]
        });

        const last_index = self.rightmost_index - 1;
        const proof_slice = try self.allocator.alloc([32]u8, self.depth);
        defer self.allocator.free(proof_slice);

        try self.getProof(last_index, proof_slice);

        for (proof_slice, 0..) |p, i| {
            self.rightmost_proof.items[i] = p;
        }

        const leaf_offset = ((@as(u64, 1) << @as(u6, @intCast(self.depth))) - 1) + last_index;
        @memcpy(&self.rightmost_leaf, &buffer[leaf_offset].hash);
        
        try self.root_buffer.insert(self.allocator, 0, buffer[0].hash);
    }

    /// Verifica una prueba de inclusión (100% Zig + Poseidon)
    pub fn verifyProof(root: [32]u8, leaf: [32]u8, index: u64, proof: [][32]u8) bool {
        var current = leaf;
        for (proof, 0..) |sibling, i| {
            const node_is_right = (index >> @intCast(i)) & 1 == 1;
            
            const n_u256 = @as(u256, @bitCast(current));
            const s_u256 = @as(u256, @bitCast(sibling));
            
            const hash_val = if (node_is_right) 
                Poseidon.hash2(s_u256, n_u256) 
            else 
                Poseidon.hash2(n_u256, s_u256);
                
            current = @bitCast(hash_val);
        }
        return std.mem.eql(u8, &current, &root);
    }

    /// Exporta los datos de una prueba al formato Prover.toml de Noir
    pub fn exportToNoir(self: *const ConcurrentMerkleTree, log_index: usize, leaf: [32]u8, root: [32]u8, file_writer: anytype) !void {
        const log = self.change_logs.items[log_index];
        
        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(self.allocator);
        const w = list.writer(self.allocator);

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

        try file_writer.writeAll(list.items);
    }

};

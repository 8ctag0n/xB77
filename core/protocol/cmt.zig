const std = @import("std");
const bn254 = @import("../security/bn254.zig");
const poseidon = @import("../security/poseidon.zig");
const crypto = @import("../security/crypto.zig");
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
pub extern fn cmt_keccak256(data: [*]const u8, len: usize, out: [*]u8) void;

// ----------------------------------------

pub const CMTError = error{
    TreeFull,
    InvalidProof,
    IndexOutOfBounds,
};

pub const HashType = enum {
    poseidon,
    keccak,
};

pub const ConcurrentMerkleTree = struct {
    allocator: std.mem.Allocator,
    depth: u8,
    hash_type: HashType = .poseidon,
    
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

    pub fn init(allocator: std.mem.Allocator, depth: u8, hash_type: HashType) !ConcurrentMerkleTree {
        var tree = ConcurrentMerkleTree{
            .allocator = allocator,
            .depth = depth,
            .hash_type = hash_type,
            .root_buffer = try std.ArrayListUnmanaged([32]u8).initCapacity(allocator, 1024),
            .change_logs = try std.ArrayListUnmanaged(ChangeLog).initCapacity(allocator, 1024),
            .rightmost_proof = try std.ArrayListUnmanaged([32]u8).initCapacity(allocator, depth),
            .rightmost_index = 0,
            .rightmost_leaf = [_]u8{0} ** 32,
        };

        // Inicializar el árbol vacío (nodos base)
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

    pub fn computeEmptyNode(self: *const ConcurrentMerkleTree, level: u8) ![32]u8 {
        if (level == 0) return [_]u8{0} ** 32;
        const child = try self.computeEmptyNode(level - 1);
        
        return self.hashNodes(child, child, false);
    }

    fn computeEmptyRoot(self: *const ConcurrentMerkleTree, depth: u8) ![32]u8 {
        return self.computeEmptyNode(depth);
    }

    /// Implementación del Algoritmo 2: Concurrent Append
    pub fn append(self: *ConcurrentMerkleTree, leaf: [32]u8) !void {
        if (self.rightmost_index >= (@as(u64, 1) << @intCast(self.depth))) return CMTError.TreeFull;

        const index = self.rightmost_index;

        // Canonical incremental-Merkle append (Tornado/Semaphore "filledSubtrees").
        // rightmost_proof[j] holds the frontier node at level j — the left sibling
        // that a future right-child insertion at that level will hash against.
        // The co-path recorded in `siblings` is leaf-independent, so the circuit can
        // reconstruct both the pre-image root (leaf = 0) and the post root (new leaf)
        // from the same siblings. This is what makes the append chain verifiable.
        var node = leaf;
        var current_index = index;

        var siblings = try self.allocator.alloc([32]u8, self.depth);
        errdefer self.allocator.free(siblings);

        var j: u8 = 0;
        while (j < self.depth) : (j += 1) {
            if (current_index & 1 == 0) {
                // Left child: right sibling is the empty subtree at this level.
                // Remember this node as the frontier for the next right-child insert.
                const empty = try self.computeEmptyNode(j);
                siblings[j] = empty;
                self.rightmost_proof.items[j] = node;
                node = self.hashNodes(node, empty, false); // node left, empty right
            } else {
                // Right child: left sibling is the stored frontier node.
                const sibling = self.rightmost_proof.items[j];
                siblings[j] = sibling;
                node = self.hashNodes(node, sibling, true); // sibling left, node right
            }
            current_index >>= 1;
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

    fn hashNodes(self: *const ConcurrentMerkleTree, node: [32]u8, sibling: [32]u8, node_is_right: bool) [32]u8 {
        if (self.hash_type == .poseidon) {
            const n_u256 = @as(u256, @bitCast(node));
            const s_u256 = @as(u256, @bitCast(sibling));
            
            const hash_val = if (node_is_right) 
                Poseidon.hash2(s_u256, n_u256) 
            else 
                Poseidon.hash2(n_u256, s_u256);
                
            return @bitCast(hash_val);
        } else {
            // Priority path (Keccak256 via C)
            var buf: [64]u8 = undefined;
            if (node_is_right) {
                @memcpy(buf[0..32], &sibling);
                @memcpy(buf[32..64], &node);
            } else {
                @memcpy(buf[0..32], &node);
                @memcpy(buf[32..64], &sibling);
            }
            var out: [32]u8 = undefined;
            cmt_keccak256(&buf, 64, &out);
            return out;
        }
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

        std.debug.print("\n[CMT   ]  Reconstructing with {s} from Index: {d}, Vault Root: {x}...", .{
            @tagName(self.hash_type), self.rightmost_index, buffer[0].hash[0..4]
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

    /// Verifica una prueba de inclusión (100% Zig + Poseidon/Keccak)
    pub fn verifyProof(root: [32]u8, leaf: [32]u8, index: u64, proof: [][32]u8, hash_type: HashType) bool {
        var current = leaf;
        for (proof, 0..) |sibling, i| {
            const node_is_right = (index >> @intCast(i)) & 1 == 1;
            
            if (hash_type == .poseidon) {
                const n_u256 = @as(u256, @bitCast(current));
                const s_u256 = @as(u256, @bitCast(sibling));
                
                const hash_val = if (node_is_right) 
                    Poseidon.hash2(s_u256, n_u256) 
                else 
                    Poseidon.hash2(n_u256, s_u256);
                    
                current = @bitCast(hash_val);
            } else {
                var buf: [64]u8 = undefined;
                if (node_is_right) {
                    @memcpy(buf[0..32], &sibling);
                    @memcpy(buf[32..64], &current);
                } else {
                    @memcpy(buf[0..32], &current);
                    @memcpy(buf[32..64], &sibling);
                }
                cmt_keccak256(&buf, 64, &current);
            }
        }
        return std.mem.eql(u8, &current, &root);
    }

    /// Exporta un lote de 5 transiciones al formato Prover.toml de Noir
    pub fn exportBatchToNoir(
        self: *const ConcurrentMerkleTree, 
        log_indices: [5]usize, 
        amounts: [5]u64,
        entry_types: [5]u8,
        tx_hashes: [5][32]u8,
        initial_root: [32]u8, 
        final_root: [32]u8, 
        total_tax: u64,
        file_writer: anytype
    ) !void {
        var list = std.ArrayListUnmanaged(u8).empty;
        defer list.deinit(self.allocator);

        // CMT nodes are stored as little-endian byte encodings of BN254 field
        // elements (hashNodes uses @bitCast on a LE host). Noir's Prover.toml
        // expects big-endian field-element hex, so every 32-byte value is
        // byte-reversed on the way out. Without this the circuit sees inputs
        // that exceed the field modulus / fail the transition constraints.
        const beHex = struct {
            fn f(alloc: std.mem.Allocator, v: [32]u8) ![]u8 {
                var be: [32]u8 = undefined;
                for (v, 0..) |b, k| be[31 - k] = b;
                return crypto.bytesToHex(alloc, &be);
            }
        }.f;

        const initial_root_hex = try beHex(self.allocator, initial_root);
        defer self.allocator.free(initial_root_hex);
        try list.print(self.allocator, "initial_root = \"0x{s}\"\n", .{initial_root_hex});

        const final_root_hex = try beHex(self.allocator, final_root);
        defer self.allocator.free(final_root_hex);
        try list.print(self.allocator, "final_root = \"0x{s}\"\n", .{final_root_hex});

        try list.print(self.allocator, "total_tax_collected = {d}\n", .{total_tax});

        // Arrays de 5
        try list.print(self.allocator, "indices = [", .{});
        for (log_indices, 0..) |idx, i| {
            try list.print(self.allocator, "{d}{s}", .{ self.change_logs.items[idx].index, if (i == 4) "" else ", " });
        }
        try list.print(self.allocator, "]\n", .{});

        try list.print(self.allocator, "amounts = [", .{});
        for (amounts, 0..) |amt, i| {
            try list.print(self.allocator, "{d}{s}", .{ amt, if (i == 4) "" else ", " });
        }
        try list.print(self.allocator, "]\n", .{});

        try list.print(self.allocator, "entry_types = [", .{});
        for (entry_types, 0..) |t, i| {
            try list.print(self.allocator, "{d}{s}", .{ t, if (i == 4) "" else ", " });
        }
        try list.print(self.allocator, "]\n", .{});

        try list.print(self.allocator, "tx_hashes = [\n", .{});
        for (tx_hashes, 0..) |h, i| {
            const h_hex = try beHex(self.allocator, h);
            defer self.allocator.free(h_hex);
            try list.print(self.allocator, "  \"0x{s}\"{s}\n", .{ h_hex, if (i == 4) "" else "," });
        }
        try list.print(self.allocator, "]\n", .{});

        try list.print(self.allocator, "siblings = [\n", .{});
        for (log_indices, 0..) |idx, i| {
            const log = self.change_logs.items[idx];
            try list.print(self.allocator, "  [\n", .{});
            for (log.siblings, 0..) |p, j| {
                const p_hex = try beHex(self.allocator, p);
                defer self.allocator.free(p_hex);
                try list.print(self.allocator, "    \"0x{s}\"{s}\n", .{ p_hex, if (j == log.siblings.len - 1) "" else "," });
            }
            try list.print(self.allocator, "  ]{s}\n", .{ if (i == 4) "" else "," });
        }
        try list.print(self.allocator, "]\n", .{});

        const _io = std.Io.Threaded.global_single_threaded.io();
        try file_writer.writeStreamingAll(_io, list.items);
    }

};

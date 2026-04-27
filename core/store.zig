const std = @import("std");
const types = @import("types.zig");
const cmt = @import("cmt.zig");

pub const EntryType = enum {
    audit,
    receipt,
    tax,
    risk_blocked,
    compliance_fail,
    match,
};

pub const LedgerEntry = struct {
    timestamp: i64,
    chain: types.Chain,
    entry_type: EntryType,
    description: []const u8,
    amount: u64 = 0,
    tx_hash: []const u8 = "",

    pub fn hash(self: LedgerEntry, out: *[32]u8) void {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var ts_buf: [8]u8 = undefined;
        std.mem.writeInt(i64, &ts_buf, self.timestamp, .little);
        hasher.update(&ts_buf);
        hasher.update(&[_]u8{@intFromEnum(self.chain)});
        hasher.update(&[_]u8{@intFromEnum(self.entry_type)});
        hasher.update(self.description);
        var amt_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &amt_buf, self.amount, .little);
        hasher.update(&amt_buf);
        hasher.update(self.tx_hash);
        hasher.final(out);
    }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    file_path: []const u8,
    vault_path: []const u8,
    index_path: []const u8,
    tree: cmt.ConcurrentMerkleTree,
    vault_ptr: []align(4096) u8,
    vault_file: std.fs.File,

    // El mapa de búsqueda rápida: Pubkey -> CMT Index
    account_index: std.AutoHashMapUnmanaged([32]u8, u64),

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !Store {
        // Aseguramos que el directorio exista
        std.fs.cwd().makePath(base_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const file_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
        const vault_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "state.vault" });
        const index_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "accounts.idx" });
        
        // Inicializar Ledger (JSONL para humanos)
        const ledger_file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        ledger_file.close();

        // Inicializar Vault (Binario para Agentes)
        // Tamaño por defecto: 1MB para el CMT de profundidad 14
        const vault_size = 1024 * 1024;
        const vault_file = try std.fs.cwd().createFile(vault_path, .{ .read = true, .truncate = false });
        try vault_file.setEndPos(vault_size);

        // Mapear el archivo en memoria (mmap)
        const vault_ptr = try std.posix.mmap(
            null,
            vault_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            vault_file.handle,
            0,
        );

        // Inicializar el CMT con profundidad 14 (16k entradas) para la demo
        var tree = try cmt.ConcurrentMerkleTree.init(allocator, 14);
        
        // VINCULAR EL VAULT BINARIO (Sovereign Compression Layer)
        tree.nodes_buffer = @ptrCast(vault_ptr.ptr);

        var self = Store{
            .allocator = allocator,
            .file_path = file_path,
            .vault_path = vault_path,
            .index_path = index_path,
            .tree = tree,
            .vault_ptr = vault_ptr,
            .vault_file = vault_file,
            .account_index = .{},
        };

        // Rehidratar el árbol desde el archivo si ya tiene datos
        try self.rehydrate();

        return self;
    }

    fn rehydrate(self: *Store) !void {
        const file = try std.fs.cwd().openFile(self.file_path, .{ .mode = .read_only });
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB limit
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const entry = std.json.parseFromSlice(LedgerEntry, self.allocator, line, .{}) catch continue;
            defer entry.deinit();
            
            var leaf: [32]u8 = undefined;
            entry.value.hash(&leaf);
            
            // Rehidratar el mmap también si es necesario
            const idx = self.tree.rightmost_index;
            const offset = idx * 32;
            if (offset + 32 <= self.vault_ptr.len) {
                @memcpy(self.vault_ptr[offset..offset+32], &leaf);
            }

            try self.tree.append(leaf);
        }
    }

    pub fn deinit(self: *Store) void {
        self.account_index.deinit(self.allocator);
        std.posix.munmap(self.vault_ptr);
        self.vault_file.close();
        self.allocator.free(self.file_path);
        self.allocator.free(self.vault_path);
        self.allocator.free(self.index_path);
        self.tree.deinit();
    }

    pub fn record(self: *Store, entry: LedgerEntry) !void {
        const file = try std.fs.cwd().openFile(self.file_path, .{ .mode = .write_only });
        defer file.close();
        try file.seekFromEnd(0);

        const line = try std.fmt.allocPrint(self.allocator, "{f}\n", .{std.json.fmt(entry, .{})});
        defer self.allocator.free(line);
        try file.writeAll(line);

        // Actualizar el CMT y el mmap
        var leaf: [32]u8 = undefined;
        entry.hash(&leaf);
        
        const idx = self.tree.rightmost_index;
        try self.tree.append(leaf);
        
        // Guardar la hoja en el mmap (O(1) access)
        const offset = idx * 32;
        if (offset + 32 <= self.vault_ptr.len) {
            @memcpy(self.vault_ptr[offset..offset+32], &leaf);
        }

        // --- THE PHOTON KILLER: Indexación Automática ---
        if (entry.entry_type == .match) {
            // Indexamos esta entrada para búsqueda rápida
            var owner_pk: [32]u8 = [_]u8{0x77} ** 32; // Simulación de Pubkey
            try self.account_index.put(self.allocator, owner_pk, idx);
            std.debug.print("\n[INDEX ] 📑 Account {x} mapped to CMT index {d}.", .{owner_pk[0..4], idx});
        }
        
        std.debug.print("\n[VAULT ] 🗄️ Sovereign State Vault updated (Index: {d}).", .{idx});
        std.debug.print("\n[STATE ] 🌳 CMT Updated. New Root: {x}...", .{self.tree.getRoot()[0..4]});
    }

    /// Lee todas las entradas para auditoría (memoria intensivo, usar con cuidado)
    pub fn getEntries(self: *Store, allocator: std.mem.Allocator) ![]LedgerEntry {
        return self.getHistory(allocator);
    }

    pub fn getHistory(self: *Store, allocator: std.mem.Allocator) ![]LedgerEntry {
        const file = try std.fs.cwd().openFile(self.file_path, .{ .mode = .read_only });
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB limit for now
        defer allocator.free(content);

        var list = std.ArrayListUnmanaged(LedgerEntry){};
        errdefer list.deinit(allocator);

        var lines = std.mem.splitScalar(u8, content, '\n');
        
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const entry = try std.json.parseFromSlice(LedgerEntry, allocator, line, .{});
            defer entry.deinit();
            try list.append(allocator, try cloneEntry(allocator, entry.value));
        }

        return list.toOwnedSlice(allocator);
    }

    /// Motor de Búsqueda Convencional (The Photon Alternative)
    pub const QueryParams = struct {
        entry_type: ?EntryType = null,
        chain: ?types.Chain = null,
        min_amount: u64 = 0,
        asset_symbol: ?[]const u8 = null,
    };

    pub fn query(self: *Store, allocator: std.mem.Allocator, params: QueryParams) ![]LedgerEntry {
        const history = try self.getHistory(allocator);
        defer {
            for (history) |entry| {
                allocator.free(entry.description);
                allocator.free(entry.tx_hash);
            }
            allocator.free(history);
        }

        var results = std.ArrayList(LedgerEntry).init(allocator);
        errdefer {
            for (results.items) |e| {
                allocator.free(e.description);
                allocator.free(e.tx_hash);
            }
            results.deinit();
        }

        for (history) |entry| {
            if (params.entry_type) |t| {
                if (entry.entry_type != t) continue;
            }
            if (params.chain) |c| {
                if (entry.chain != c) continue;
            }
            if (entry.amount < params.min_amount) continue;
            
            if (params.asset_symbol) |sym| {
                if (!std.mem.containsAtLeast(u8, entry.description, 1, sym)) continue;
            }

            try results.append(try cloneEntry(allocator, entry));
        }

        return results.toOwnedSlice();
    }

    fn cloneEntry(allocator: std.mem.Allocator, entry: LedgerEntry) !LedgerEntry {
        return LedgerEntry{
            .timestamp = entry.timestamp,
            .chain = entry.chain,
            .entry_type = entry.entry_type,
            .description = try allocator.dupe(u8, entry.description),
            .amount = entry.amount,
            .tx_hash = try allocator.dupe(u8, entry.tx_hash),
        };
    }
};

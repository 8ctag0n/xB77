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
    tree: cmt.ConcurrentMerkleTree,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !Store {
        // Aseguramos que el directorio exista
        std.fs.cwd().makePath(base_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const file_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
        
        // Probamos abrirlo/crearlo para asegurar permisos
        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        file.close();

        // Inicializar el CMT con profundidad 14 (16k entradas) para la demo
        const tree = try cmt.ConcurrentMerkleTree.init(allocator, 14);

        var self = Store{
            .allocator = allocator,
            .file_path = file_path,
            .tree = tree,
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
            try self.tree.append(leaf);
        }
    }

    pub fn deinit(self: *Store) void {
        self.allocator.free(self.file_path);
        self.tree.deinit();
    }

    pub fn record(self: *Store, entry: LedgerEntry) !void {
        const file = try std.fs.cwd().openFile(self.file_path, .{ .mode = .write_only });
        defer file.close();
        try file.seekFromEnd(0);

        const line = try std.fmt.allocPrint(self.allocator, "{f}\n", .{std.json.fmt(entry, .{})});
        defer self.allocator.free(line);
        try file.writeAll(line);

        // Actualizar el CMT
        var leaf: [32]u8 = undefined;
        entry.hash(&leaf);
        try self.tree.append(leaf);
        
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

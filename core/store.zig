const std = @import("std");
const types = @import("types.zig");

pub const EntryType = enum {
    audit,
    receipt,
    tax,
    risk_blocked,
    compliance_fail,
};

pub const LedgerEntry = struct {
    timestamp: i64,
    chain: types.Chain,
    entry_type: EntryType,
    description: []const u8,
    amount: u64 = 0,
    tx_hash: []const u8 = "",
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !Store {
        // Aseguramos que el directorio exista
        std.fs.cwd().makePath(base_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const file_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
        
        // Probamos abrirlo/crearlo para asegurar permisos
        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        file.close();

        return Store{
            .allocator = allocator,
            .file_path = file_path,
        };
    }

    pub fn deinit(self: *Store) void {
        self.allocator.free(self.file_path);
    }

    pub fn record(self: *Store, entry: LedgerEntry) !void {
        const file = try std.fs.cwd().openFile(self.file_path, .{ .mode = .write_only });
        defer file.close();
        try file.seekFromEnd(0);

        const line = try std.fmt.allocPrint(self.allocator, "{f}\n", .{std.json.fmt(entry, .{})});
        defer self.allocator.free(line);
        try file.writeAll(line);
    }

    /// Lee todas las entradas para auditoría (memoria intensivo, usar con cuidado)
    pub fn getEntries(self: *Store, allocator: std.mem.Allocator) ![]LedgerEntry {
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

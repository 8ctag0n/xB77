const std = @import("std");
const core = @import("core");
const cmt = core.cmt;
const store = core.store;

test "The Ghost Proof: Zig to Noir State Anchor" {
    const allocator = std.testing.allocator;
    const test_dir = "./.test_noir_bridge";
    std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), test_dir) catch {};
    defer std.Io.Dir.cwd().deleteTree(std.Io.Threaded.global_single_threaded.io(), test_dir) catch {};

    var s = try store.Store.init(allocator, test_dir);
    defer s.deinit();

    // 1. Registrar una acción soberana
    const entry = store.LedgerEntry{
        .timestamp = 123456789,
        .chain = .solana,
        .entry_type = .match,
        .description = "P2P Sovereign Match",
        .amount = 777,
        .tx_hash = "abc123magic",
    };
    try s.record(entry);

    // 2. Exportar Prover.toml para el circuito state_anchor
    const prover_path = try std.fs.path.join(allocator, &[_][]const u8{ test_dir, "Prover.toml" });
    defer allocator.free(prover_path);
    
    var content_list = std.ArrayListUnmanaged(u8).empty;
    defer content_list.deinit(allocator);

    // 2. Exportar Batch de 5 (simulados)
    const log_indices: [5]usize = [_]usize{0} ** 5;
    const amounts: [5]u64 = [_]u64{entry.amount} ** 5;
    const entry_types: [5]u8 = [_]u8{@intFromEnum(entry.entry_type)} ** 5;

    var tx_hashes: [5][32]u8 = undefined;
    for (0..5) |i| {
        tx_hashes[i] = [_]u8{0} ** 32;
        @memcpy(tx_hashes[i][0..@min(entry.tx_hash.len, 32)], entry.tx_hash[0..@min(entry.tx_hash.len, 32)]);
    }

    const initial_root = try s.tree.computeEmptyNode(s.tree.depth);
    const total_tax = (entry.amount * 2011 * 5) / 100000;

    // Inline writer adapter: exportBatchToNoir calls writeStreamingAll(io, data).
    // Replaces the removed ArrayListUnmanaged.writer(allocator) API.
    const ListWriter = struct {
        buf: *std.ArrayListUnmanaged(u8),
        gpa: std.mem.Allocator,
        pub fn writeStreamingAll(self: *@This(), io: std.Io, data: []const u8) !void {
            _ = io;
            try self.buf.appendSlice(self.gpa, data);
        }
    };
    var lw = ListWriter{ .buf = &content_list, .gpa = allocator };
    try s.tree.exportBatchToNoir(
        log_indices,
        amounts,
        entry_types,
        tx_hashes,
        initial_root,
        s.tree.getRoot(),
        total_tax,
        &lw
    );

    const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), prover_path, .{});
    defer file.close(std.Io.Threaded.global_single_threaded.io());
    try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), content_list.items);

    std.debug.print("\n[GHOST ]  Prover.toml (Batch) exported to {s}", .{prover_path});

    // 3. Verificar que el archivo existe y tiene el formato de batch
    const content = try std.Io.Dir.cwd().readFileAlloc(std.Io.Threaded.global_single_threaded.io(), prover_path, allocator, @enumFromInt(1024 * 10));
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "initial_root = \"0x") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "final_root = \"0x") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "indices = [") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "amounts = [") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "total_tax_collected = ") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "siblings = [") != null);
}

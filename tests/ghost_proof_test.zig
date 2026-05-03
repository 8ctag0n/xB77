const std = @import("std");
const core = @import("core");
const cmt = core.cmt;
const store = core.store;

test "The Ghost Proof: Zig to Noir State Anchor" {
    const allocator = std.testing.allocator;
    const test_dir = "./.test_noir_bridge";
    std.fs.cwd().makePath(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

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
    
    var content_list = std.ArrayListUnmanaged(u8){};
    defer content_list.deinit(allocator);

    var leaf: [32]u8 = undefined;
    entry.hash(&leaf);
    
    var writer = content_list.writer(allocator);
    try s.tree.exportToNoir(0, leaf, s.tree.getRoot(), &writer);

    const file = try std.fs.cwd().createFile(prover_path, .{});
    defer file.close();
    try file.writeAll(content_list.items);

    std.debug.print("\n[GHOST ]  Prover.toml exported to {s}", .{prover_path});

    // 3. Verificar que el archivo existe y tiene el formato correcto
    const content = try std.fs.cwd().readFileAlloc(allocator, prover_path, 1024 * 10);
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "root = [") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "index = ") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "siblings = [") != null);
}

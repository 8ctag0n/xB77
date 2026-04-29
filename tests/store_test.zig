const std = @import("std");
const core = @import("core");
const store = core.store;
const types = core.types;

test "Store - Basic record and retrieve" {
    const allocator = std.testing.allocator;
    const test_path = "./.test_xb77";
    defer std.fs.cwd().deleteTree(test_path) catch {};

    var s = try store.Store.init(allocator, test_path);
    defer s.deinit();

    const entry = store.LedgerEntry{
        .timestamp = 123456789,
        .chain = .solana,
        .entry_type = .audit,
        .description = "Test audit entry",
        .amount = 1000,
        .tx_hash = "fake_hash",
    };

    try s.record(entry);

    const entries = try s.getEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.description);
            allocator.free(e.tx_hash);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqual(entry.timestamp, entries[0].timestamp);
    try std.testing.expectEqualStrings(entry.description, entries[0].description);
    try std.testing.expectEqualStrings(entry.tx_hash, entries[0].tx_hash);
}

test "Store - Sovereign Persistence (The Photon-Killer Reboot)" {
    const allocator = std.testing.allocator;
    const test_path = "./.test_persistence";
    defer std.fs.cwd().deleteTree(test_path) catch {};

    var initial_root: [32]u8 = undefined;

    // --- SESIÓN 1: El Agente opera y se apaga ---
    {
        var s = try store.Store.init(allocator, test_path);
        defer s.deinit();

        try s.record(.{
            .timestamp = 100,
            .chain = .solana,
            .entry_type = .match,
            .description = "Entry 1",
            .tx_hash = "tx1",
        });
        try s.record(.{
            .timestamp = 200,
            .chain = .solana,
            .entry_type = .match,
            .description = "Entry 2",
            .tx_hash = "tx2",
        });

        initial_root = s.tree.getRoot();
        try std.testing.expect(s.header.next_index == 2);
        std.debug.print("\n[TEST] Session 1 finished. Root: {x}...", .{initial_root[0..4]});
    }

    // --- SESIÓN 2: El Agente renace instantáneamente ---
    {
        std.debug.print("\n[TEST] Session 2 starting (Reboot)...", .{});
        var s = try store.Store.init(allocator, test_path);
        defer s.deinit();

        // 1. Debe recordar dónde quedó por el VaultHeader
        try std.testing.expect(s.header.next_index == 2);
        
        const current_root = s.tree.getRoot();
        try std.testing.expectEqualStrings(&initial_root, &current_root);
        std.debug.print("\n[TEST] Session 2 rehydrated correctly. Root matches.", .{});

        // 2. Debe poder seguir operando y actualizando el CMT correctamente
        try s.record(.{
            .timestamp = 300,
            .chain = .solana,
            .entry_type = .match,
            .description = "Entry 3",
            .tx_hash = "tx3",
        });

        try std.testing.expect(s.header.next_index == 3);
        const final_root = s.tree.getRoot();
        try std.testing.expect(!std.mem.eql(u8, &initial_root, &final_root));
        std.debug.print("\n[TEST] Session 2 record successful. New Root: {x}...", .{final_root[0..4]});
    }
}

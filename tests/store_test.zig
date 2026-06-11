const std = @import("std");
const core = @import("core");
const store = core.store;
const types = core.types;

test "Store - Basic record and retrieve" {
    const allocator = std.testing.allocator;
    const test_path = "./.test_xb77";
    defer std.Io.Dir.cwd().deleteTree(std.Io.Threaded.global_single_threaded.io(), test_path) catch {};

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
    defer std.Io.Dir.cwd().deleteTree(std.Io.Threaded.global_single_threaded.io(), test_path) catch {};

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

// Generates a consistent state_anchor witness (Prover.toml) from a real CMT
// run: 5 sequential appends into a depth-14 Poseidon tree, exported big-endian.
// Run with: zig build gen-anchor-witness
test "gen state_anchor witness (real CMT, big-endian export)" {
    if (std.c.getenv("XB77_GEN_ANCHOR") == null) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const io = std.Io.Threaded.global_single_threaded.io();

    var tree = try core.cmt.ConcurrentMerkleTree.init(allocator, 14, .poseidon);
    defer tree.deinit();

    // Empty-tree root, captured before any append.
    const initial_root = tree.root_buffer.items[0];

    var amounts: [5]u64 = undefined;
    var entry_types: [5]u8 = undefined;
    var tx_hashes: [5][32]u8 = undefined;
    var total_tax: u64 = 0;

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        // tx_hash kept small (LE byte 0 only) so its field value < BN254 modulus.
        var txh: [32]u8 = [_]u8{0} ** 32;
        txh[0] = @intCast(0x11 + i);

        const entry = store.LedgerEntry{
            .timestamp = @intCast(1000 + i),
            .chain = .arbitrum,
            .entry_type = .receipt,
            .description = "anchor-batch",
            .amount = 2_000_000_000,
            .tx_hash = &txh,
        };

        try tree.append(entry.poseidonHash());

        amounts[i] = entry.amount;
        entry_types[i] = @intFromEnum(entry.entry_type);
        tx_hashes[i] = txh;
        total_tax += (entry.amount * 2011) / 100000;
    }

    const final_root = tree.root_buffer.items[0];

    // change_logs.items[0] is newest; transition order is chronological → reverse.
    const log_indices = [5]usize{ 4, 3, 2, 1, 0 };

    const file = try std.Io.Dir.cwd().createFile(io, "circuits/state_anchor/Prover.toml", .{});
    defer file.close(io);
    try tree.exportBatchToNoir(log_indices, amounts, entry_types, tx_hashes, initial_root, final_root, total_tax, file);

    std.debug.print("\n[GEN] state_anchor/Prover.toml written. tax={d}\n", .{total_tax});
}

// Verifies the Solana anchor path: computeTransitionRoot (client-side climb that
// feeds new_root and the BatchRootMismatch guard in anchorMeshState) reproduces
// the real CMT root — i.e. matches what xb77_compression recomputes on-chain.
test "Solana anchor: computeTransitionRoot matches CMT root" {
    const allocator = std.testing.allocator;

    var tree = try core.cmt.ConcurrentMerkleTree.init(allocator, 14, .poseidon);
    defer tree.deinit();

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        var txh: [32]u8 = [_]u8{0} ** 32;
        txh[0] = @intCast(0x11 + i);
        const entry = store.LedgerEntry{
            .timestamp = @intCast(1000 + i),
            .chain = .arbitrum,
            .entry_type = .receipt,
            .description = "anchor-batch",
            .amount = 2_000_000_000,
            .tx_hash = &txh,
        };
        try tree.append(entry.poseidonHash());
    }

    // Newest change log = the 5th append (leaf index 4); its climb must hit final root.
    const log = tree.change_logs.items[0];
    var siblings: [14][32]u8 = undefined;
    for (log.siblings, 0..) |s, j| siblings[j] = s;

    var txh4: [32]u8 = [_]u8{0} ** 32;
    txh4[0] = 0x15; // small value < BN254 modulus, so no reduction needed
    const tx_hash_field = std.mem.readInt(u256, &txh4, .little);

    const climbed = core.solana.SolanaClient.computeTransitionRoot(
        2_000_000_000,
        @intFromEnum(store.EntryType.receipt),
        tx_hash_field,
        log.index,
        siblings,
    );

    const expected = std.mem.readInt(u256, &tree.root_buffer.items[0], .little);
    try std.testing.expectEqual(expected, climbed);
    std.debug.print("\n[TEST] Solana climb matches CMT final root ✓\n", .{});
}

const std = @import("std");
const core = @import("core");
const cmt = core.cmt;
const store = core.store;
const types = core.types;

test "Sovereign State: CMT Append and Verify" {
    const allocator = std.testing.allocator;
    
    // CMT Profundidad 3 (max 8 hojas)
    var tree = try cmt.ConcurrentMerkleTree.init(allocator, 3, .poseidon);
    defer tree.deinit();

    const root0 = tree.getRoot();
    
    // Hoja 1
    var leaf1 = [_]u8{0} ** 32;
    leaf1[0] = 0xAA;
    try tree.append(leaf1);
    
    const root1 = tree.getRoot();
    try std.testing.expect(!std.mem.eql(u8, &root0, &root1));

    // Hoja 2
    var leaf2 = [_]u8{0} ** 32;
    leaf2[0] = 0xBB;
    try tree.append(leaf2);
    
    const root2 = tree.getRoot();
    try std.testing.expect(!std.mem.eql(u8, &root1, &root2));

    // Verificar Prueba de Hoja 1
    const log1 = tree.change_logs.items[1];
    try std.testing.expect(log1.index == 0);
    try std.testing.expect(cmt.ConcurrentMerkleTree.verifyProof(root1, leaf1, 0, log1.siblings, .poseidon));
}

test "Sovereign State: Store Rehydration" {
    const allocator = std.testing.allocator;
    const test_dir = "./.test_store_cmt";
    std.fs.cwd().makePath(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    {
        var s = try store.Store.init(allocator, test_dir);
        defer s.deinit();

        try s.record(.{
            .timestamp = 1000,
            .chain = .solana,
            .entry_type = .match,
            .description = "Test Match 1",
            .amount = 500,
            .tx_hash = "hash1",
        });

        try s.record(.{
            .timestamp = 2000,
            .chain = .base,
            .entry_type = .match,
            .description = "Test Match 2",
            .amount = 1000,
            .tx_hash = "hash2",
        });
    }

    // Rehidratar en una nueva instancia
    {
        var s = try store.Store.init(allocator, test_dir);
        defer s.deinit();

        // El índice debería ser 2
        try std.testing.expect(s.tree.rightmost_index == 2);
        
        // La raíz debería ser consistente
        const root = s.tree.getRoot();
        try std.testing.expect(!std.mem.eql(u8, &root, &([_]u8{0} ** 32)));
        
        std.debug.print("\n[TEST  ] Rehydration Successful. Root: {x}...", .{root[0..4]});
    }
}

test "Priority State: CMT Append and Verify (Keccak)" {
    const allocator = std.testing.allocator;
    
    // CMT Profundidad 3 (max 8 hojas)
    var tree = try cmt.ConcurrentMerkleTree.init(allocator, 3, .keccak);
    defer tree.deinit();

    const root0 = tree.getRoot();
    
    // Hoja 1
    var leaf1 = [_]u8{0} ** 32;
    leaf1[0] = 0xAA;
    try tree.append(leaf1);

    const root1 = tree.getRoot();
    try std.testing.expect(!std.mem.eql(u8, &root0, &root1));

    // Hoja 2
    var leaf2 = [_]u8{0} ** 32;
    leaf2[0] = 0xBB;
    try tree.append(leaf2);
    
    const root2 = tree.getRoot();

    // Verify with proof
    const log1 = tree.change_logs.items[1]; // Hoja 1
    try std.testing.expect(cmt.ConcurrentMerkleTree.verifyProof(root1, leaf1, 0, log1.siblings, .keccak));
    
    const log2 = tree.change_logs.items[0]; // Hoja 2
    try std.testing.expect(cmt.ConcurrentMerkleTree.verifyProof(root2, leaf2, 1, log2.siblings, .keccak));
}

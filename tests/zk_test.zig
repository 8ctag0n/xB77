const std = @import("std");
const core = @import("core");
const receipt = core.receipt;

test "Ghost Strategy: Generate ZK Prover File" {
    const allocator = std.testing.allocator;
    const test_path = "./.test_zk";
    std.fs.cwd().makePath(test_path) catch {};
    defer std.fs.cwd().deleteTree(test_path) catch {};

    const amount: u64 = 1_000_000_000; // 1 SOL
    const tax: u64 = 20_110_000;      // 2.011%
    const recipient_pk = [_]u8{0xAB} ** 32;

    const r = try receipt.ZkReceipt.generate(amount, tax, .{ .sol = recipient_pk });
    
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ test_path, "Prover.toml" });
    defer allocator.free(file_path);

    try r.writeProverToml(file_path);

    // Verificar contenido
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 4096);
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "amount = 1000000000") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "tax_paid = 20110000") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "recipient_pubkey = \"0xab") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "secret_salt = \"0x") != null);
}

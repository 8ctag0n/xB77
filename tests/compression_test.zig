const std = @import("std");
const core = @import("core");
const compression = core.compression;

test "Compression: Zero-Copy State Transition" {
    var raw_data: [160]u8 align(4096) = [_]u8{0} ** 160;
    
    // Simulamos que estos punteros apuntan al mmap
    const acc1: *compression.CompressedAccount = @ptrCast(&raw_data[0]);
    const acc2: *compression.CompressedAccount = @ptrCast(&raw_data[80]);
    
    acc1.owner = [_]u8{0x11} ** 32;
    acc1.amount = 1000;
    acc1.nonce = 42;
    acc1.asset_id = [_]u8{0xAA} ** 32;
    
    acc2.owner = [_]u8{0x22} ** 32;
    acc2.amount = 0;
    acc2.nonce = 0;
    acc2.asset_id = [_]u8{0xAA} ** 32;

    var engine = compression.CompressionEngine.init(std.testing.allocator);
    try engine.transfer(acc1, acc2, 500);

    // Verificamos que el buffer "crudo" cambió (Zero-Copy)
    try std.testing.expectEqual(acc1.amount, 1000 - 500 - 111);
    try std.testing.expectEqual(acc2.amount, 500);
    try std.testing.expectEqual(acc1.nonce, 43);
    
    // El hash debe ser consistente y usar keccak256 (vía C)
    var h1: [32]u8 = undefined;
    acc1.hash(&h1);
    
    // El hash no debe ser el de un bloque vacío
    var empty: [32]u8 = [_]u8{0} ** 32;
    try std.testing.expect(!std.mem.eql(u8, &h1, &empty));
}

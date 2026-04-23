const std = @import("std");
const core = @import("core");
const awp = core.awp;
const types = core.types;

test "AWP: Encode and Decode TransferMsg" {
    const allocator = std.testing.allocator;

    var encoder = awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    const msg = awp.TransferMsg{
        .chain = .solana,
        .amount = 42_000_000,
        .recipient = .{ .sol = [_]u8{0x77} ** 32 },
    };

    // 1. Zig: Codifica a bytes
    const encoded = try encoder.encodeTransfer(msg);
    
    // El tamaño debería ser súper chico:
    // 1 (type) + 1 (chain) + ~4 (varint para 42M) + 32 (pubkey) = ~38 bytes
    try std.testing.expect(encoded.len <= 40);

    // 2. Zig: Decodifica sin alocar memoria extra
    var decoder = awp.AwpDecoder.init(encoded);
    const decoded = try decoder.decodeTransfer();

    // Verificamos que los datos estén intactos
    try std.testing.expectEqual(decoded.chain, .solana);
    try std.testing.expectEqual(decoded.amount, 42_000_000);
    try std.testing.expectEqualSlices(u8, &decoded.recipient.sol, &msg.recipient.sol);
}

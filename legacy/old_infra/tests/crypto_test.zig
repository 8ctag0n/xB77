const std = @import("std");
const core = @import("core");
const crypto = core;
const types = core.types;

test "Base58: Solana Pubkey encoding" {
    const allocator = std.testing.allocator;
    
    // Una pubkey real de Solana (32 bytes de ceros es '1111...')
    var pubkey = [_]u8{0} ** 32;
    const encoded = try crypto.encodeBase58(allocator, &pubkey);
    defer allocator.free(encoded);
    
    try std.testing.expectEqualStrings("11111111111111111111111111111111", encoded);
}

test "Base58: Roundtrip" {
    const allocator = std.testing.allocator;
    const input = "xB77 Agent Commerce";
    
    const encoded = try crypto.encodeBase58(allocator, input);
    defer allocator.free(encoded);
    
    const decoded = try crypto.decodeBase58(allocator, encoded);
    defer allocator.free(decoded);
    
    try std.testing.expectEqualStrings(input, decoded);
}

test "Ed25519: Sign and Verify" {
    const kp = crypto.generateKeypair();
    const message = "Hello Solana, I am xB77";
    
    const signature = crypto.sign(message, &kp);
    const is_valid = crypto.verify(message, &signature, &kp.public);
    
    try std.testing.expect(is_valid);
}

test "Ed25519: Invalid signature fails" {
    const kp = crypto.generateKeypair();
    const message = "Clean message";
    const signature = crypto.sign(message, &kp);
    
    const is_valid = crypto.verify("Tampered message", &signature, &kp.public);
    
    try std.testing.expect(!is_valid);
}

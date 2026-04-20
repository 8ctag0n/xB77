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

test "Secp256k1: Ethereum Address Generation" {
    const kp = try crypto.generateEthKeypair();
    // La dirección debe tener 20 bytes
    try std.testing.expect(kp.address.len == 20);
}

test "Secp256k1: Ethereum Signing and v Recovery" {
    const kp = try crypto.generateEthKeypair();
    const message = "Ethereum xB77 Transaction";
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(message, &hash, .{});
    
    const sig = try crypto.signEthMessage(hash, kp.secret);
    
    // El recovery ID debe ser 0 o 1
    try std.testing.expect(sig.v == 0 or sig.v == 1);
    
    // Recuperar pubkey y verificar dirección
    const recovered_pk = try crypto.recoverEthPublicKey(hash, sig.r, sig.s, sig.v);
    const recovered_bytes = recovered_pk.toUncompressedSec1();
    
    // Hash de la pubkey recuperada (sin el primer byte 0x04) para obtener dirección
    var addr_hash: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(recovered_bytes[1..], &addr_hash, .{});
    
    try std.testing.expectEqualStrings(&kp.address, addr_hash[12..32]);
}

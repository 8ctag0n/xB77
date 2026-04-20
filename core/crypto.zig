const std = @import("std");
pub const types = @import("types.zig");

pub const Ed25519 = std.crypto.sign.Ed25519;
pub const Secp256k1 = std.crypto.ecc.Secp256k1;
pub const Keccak256 = std.crypto.hash.sha3.Keccak256;

/// Genera un nuevo par de llaves Ed25519 (Solana).
pub fn generateKeypair() types.Keypair {
    const kp = Ed25519.KeyPair.generate();
    return .{
        .public = kp.public_key.toBytes(),
        .secret = kp.secret_key.toBytes(),
    };
}

/// Firma un mensaje Ed25519.
pub fn sign(message: []const u8, keypair: *const types.Keypair) types.Signature {
    const sk = Ed25519.SecretKey.fromBytes(keypair.secret) catch unreachable;
    const pk = Ed25519.PublicKey.fromBytes(keypair.public) catch unreachable;
    const kp = Ed25519.KeyPair{
        .public_key = pk,
        .secret_key = sk,
    };
    const signature = kp.sign(message, null) catch unreachable;
    return signature.toBytes();
}

/// Genera un nuevo par de llaves Secp256k1 (Ethereum).
pub fn generateEthKeypair() !types.EthKeypair {
    const secret_key = std.crypto.ecc.Secp256k1.scalar.random(.big);
    const public_key = try std.crypto.ecc.Secp256k1.basePoint.mul(secret_key, .big);
    
    // La dirección de Ethereum son los últimos 20 bytes del hash Keccak de la pubkey (sin el primer byte 0x04)
    const uncompressed_pk = public_key.toUncompressedSec1();
    var hash: [32]u8 = undefined;
    Keccak256.hash(uncompressed_pk[1..], &hash, .{});
    
    var addr: [20]u8 = undefined;
    @memcpy(&addr, hash[12..32]);

    return .{
        .address = addr,
        .secret = secret_key,
    };
}

pub const EthSignature = struct {
    r: [32]u8,
    s: [32]u8,
    v: u8,
};

/// Firma un mensaje con Secp256k1 (formato Ethereum).
pub fn signEthMessage(message_hash: [32]u8, secret_key_bytes: [32]u8) !EthSignature {
    const EcdsaKeccak = std.crypto.sign.ecdsa.Ecdsa(std.crypto.ecc.Secp256k1, std.crypto.hash.sha3.Keccak256);
    const sk = try EcdsaKeccak.SecretKey.fromBytes(secret_key_bytes);
    const keypair = try EcdsaKeccak.KeyPair.fromSecretKey(sk);
    const sig = try keypair.sign(&message_hash, null);
    
    // Para obtener 'v' (recovery ID), derivamos la pubkey y probamos cuál v la recupera.
    const actual_pk_bytes = keypair.public_key.toUncompressedSec1();

    var v: u8 = 0;
    while (v < 2) : (v += 1) {
        if (recoverEthPublicKey(message_hash, sig.r, sig.s, v)) |recovered_pk| {
            const recovered_bytes = recovered_pk.toUncompressedSec1();
            if (std.mem.eql(u8, &actual_pk_bytes, &recovered_bytes)) {
                return EthSignature{
                    .r = sig.r,
                    .s = sig.s,
                    .v = v,
                };
            }
        } else |_| {}
    }

    return error.RecoveryFailed;
}

/// Recupera la llave pública a partir de una firma y el hash del mensaje.
pub fn recoverEthPublicKey(message_hash: [32]u8, r: [32]u8, s: [32]u8, v: u8) !std.crypto.ecc.Secp256k1 {
    // 1. Levantar R a partir de r y v
    var compressed_R = [_]u8{0} ** 33;
    compressed_R[0] = 0x02 + v;
    @memcpy(compressed_R[1..33], &r);
    const R = try Secp256k1.fromSec1(&compressed_R);
    
    // 2. Q = r⁻¹ * (sR - zG)
    const r_scalar = try Secp256k1.scalar.Scalar.fromBytes(r, .big);
    const r_inv = Secp256k1.scalar.Scalar.invert(r_scalar);
    const sR = try R.mul(s, .big);
    const zG = try Secp256k1.basePoint.mul(message_hash, .big);
    
    const neg_zG = zG.neg();
    const sR_minus_zG = sR.add(neg_zG);
    
    return try sR_minus_zG.mul(Secp256k1.scalar.Scalar.toBytes(r_inv, .big), .big);
}

pub fn bytesToHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex_chars = "0123456789abcdef";
    var result = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        result[i * 2] = hex_chars[byte >> 4];
        result[i * 2 + 1] = hex_chars[byte & 0x0f];
    }
    return result;
}

/// Verifica una firma.
pub fn verify(message: []const u8, signature_bytes: *const types.Signature, pubkey_bytes: *const types.Pubkey) bool {
    const sig = Ed25519.Signature.fromBytes(signature_bytes.*);
    const pk = Ed25519.PublicKey.fromBytes(pubkey_bytes.*) catch return false;
    
    sig.verify(message, pk) catch return false;
    return true;
}

// --- Base58 (Alphabet: Solana/Bitcoin) ---
const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

pub fn encodeBase58(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return try allocator.dupe(u8, "");

    var zeroes: usize = 0;
    while (zeroes < input.len and input[zeroes] == 0) : (zeroes += 1) {}

    const size = (input.len - zeroes) * 138 / 100 + 1;
    var buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);
    @memset(buffer, 0);

    var length: usize = 0;
    for (input[zeroes..]) |byte| {
        var carry: u32 = byte;
        var i: usize = 0;
        while (i < length or carry != 0) : (i += 1) {
            if (i >= size) return error.BufferTooSmall;
            carry += @as(u32, buffer[i]) << 8;
            buffer[i] = @intCast(carry % 58);
            carry /= 58;
        }
        length = i;
    }

    var result = try allocator.alloc(u8, zeroes + length);
    for (0..zeroes) |i| result[i] = '1';
    for (0..length) |i| {
        result[zeroes + i] = ALPHABET[buffer[length - 1 - i]];
    }

    return result;
}

pub fn decodeBase58(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return try allocator.dupe(u8, "");

    var zeroes: usize = 0;
    while (zeroes < input.len and input[zeroes] == '1') : (zeroes += 1) {}

    const size = input.len * 733 / 1000 + 1;
    var buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);
    @memset(buffer, 0);

    var length: usize = 0;
    for (input[zeroes..]) |char| {
        const value = std.mem.indexOfScalar(u8, ALPHABET, char) orelse return error.InvalidCharacter;
        var carry: u32 = @intCast(value);
        var i: usize = 0;
        while (i < length or carry != 0) : (i += 1) {
            if (i >= size) return error.BufferTooSmall;
            carry += @as(u32, buffer[i]) * 58;
            buffer[i] = @intCast(carry & 0xFF);
            carry >>= 8;
        }
        length = i;
    }

    var result = try allocator.alloc(u8, zeroes + length);
    @memset(result[0..zeroes], 0);
    for (0..length) |i| {
        result[zeroes + i] = buffer[length - 1 - i];
    }

    return result;
}

pub fn pubkeyToString(allocator: std.mem.Allocator, pubkey: *const types.Pubkey) ![]u8 {
    return encodeBase58(allocator, pubkey);
}

pub fn stringToPubkey(allocator: std.mem.Allocator, str: []const u8) !types.Pubkey {
    const decoded = try decodeBase58(allocator, str);
    defer allocator.free(decoded);
    if (decoded.len != 32) return error.InvalidPubkeyLength;
    var pubkey: types.Pubkey = undefined;
    @memcpy(&pubkey, decoded[0..32]);
    return pubkey;
}

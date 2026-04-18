const std = @import("std");
pub const types = @import("types.zig");

pub const Ed25519 = std.crypto.sign.Ed25519;

/// Genera un nuevo par de llaves Ed25519.
pub fn generateKeypair() types.Keypair {
    const kp = Ed25519.KeyPair.generate();
    return .{
        .public = kp.public_key.toBytes(),
        .secret = kp.secret_key.toBytes(),
    };
}

/// Firma un mensaje con la llave secreta.
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

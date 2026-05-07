const std = @import("std");
const types = @import("../protocol/types.zig");

pub const Ed25519 = std.crypto.sign.Ed25519;
pub const Secp256k1 = std.crypto.ecc.Secp256k1;
pub const Keccak256 = std.crypto.hash.sha3.Keccak256;
pub const Sha256 = std.crypto.hash.sha2.Sha256;
pub const EcdsaKeccak = std.crypto.sign.ecdsa.Ecdsa(Secp256k1, Keccak256);

pub fn hash256(input: []const u8, out: *[32]u8) void {
    var h = Sha256.init(.{});
    h.update(input);
    h.final(out);
}

pub fn doubleSha256(input: []const u8, out: *[32]u8) void {
    var temp: [32]u8 = undefined;
    hash256(input, &temp);
    hash256(&temp, out);
}

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
    const kp = Ed25519.KeyPair{ .public_key = pk, .secret_key = sk };
    
    const signature = kp.sign(message, null) catch unreachable;
    return signature.toBytes();
}

/// Genera un nuevo par de llaves Secp256k1 (Ethereum).
pub fn generateEthKeypair() !types.EthKeypair {
    const kp = EcdsaKeccak.KeyPair.generate();
    const uncompressed_pk = kp.public_key.p.toUncompressedSec1();
    var hash: [32]u8 = undefined;
    Keccak256.hash(uncompressed_pk[1..], &hash, .{});
    
    var addr: [20]u8 = undefined;
    @memcpy(&addr, hash[12..32]);

    return .{
        .address = addr,
        .secret = kp.secret_key.toBytes(),
    };
}

pub const EthSignature = struct {
    r: [32]u8,
    s: [32]u8,
    v: u8,
};

const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

pub fn encodeBase58(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return try allocator.dupe(u8, "");
    var zeroes: usize = 0;
    while (zeroes < input.len and input[zeroes] == 0) : (zeroes += 1) {}
    const size = (input.len - zeroes) * 138 / 100 + 1;
    var b58 = try allocator.alloc(u8, size);
    defer allocator.free(b58);
    @memset(b58, 0);
    var length: usize = 0;
    for (input[zeroes..]) |byte| {
        var carry: u32 = byte;
        var i: usize = 0;
        while (i < length or carry != 0) : (i += 1) {
            if (i >= size) return error.BufferTooSmall;
            carry += @as(u32, b58[i]) * 256;
            b58[i] = @intCast(carry % 58);
            carry /= 58;
        }
        length = i;
    }
    var result = try allocator.alloc(u8, zeroes + length);
    for (0..zeroes) |i| result[i] = '1';
    for (0..length) |i| {
        result[zeroes + i] = BASE58_ALPHABET[b58[length - 1 - i]];
    }
    return result;
}

pub fn decodeBase58(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return try allocator.dupe(u8, "");
    var zeroes: usize = 0;
    while (zeroes < input.len and input[zeroes] == '1') : (zeroes += 1) {}
    const size = (input.len - zeroes) * 733 / 1000 + 1;
    var bin = try allocator.alloc(u8, size);
    defer allocator.free(bin);
    @memset(bin, 0);
    var length: usize = 0;
    for (input[zeroes..]) |char| {
        const index = std.mem.indexOfScalar(u8, BASE58_ALPHABET, char) orelse return error.InvalidCharacter;
        var carry: u32 = @intCast(index);
        var i: usize = 0;
        while (i < length or carry != 0) : (i += 1) {
            if (i >= size) return error.BufferTooSmall;
            carry += @as(u32, bin[i]) * 58;
            bin[i] = @intCast(carry % 256);
            carry /= 256;
        }
        length = i;
    }
    var result = try allocator.alloc(u8, zeroes + length);
    @memset(result[0..zeroes], 0);
    for (0..length) |i| {
        result[zeroes + i] = bin[length - 1 - i];
    }
    return result;
}

pub fn signEthMessage(message_hash: [32]u8, secret_key_bytes: [32]u8) !EthSignature {
    const sk = try EcdsaKeccak.SecretKey.fromBytes(secret_key_bytes);
    const keypair = try EcdsaKeccak.KeyPair.fromSecretKey(sk);
    const sig = try keypair.signPrehashed(message_hash, null);
    
    // En Ethereum EIP-1559, v es 0 o 1.
    // Probamos ambos para ver cuál recupera nuestra clave pública.
    for (0..2) |v| {
        const recovered_pk = recoverEthPublicKey(message_hash, sig.r, sig.s, @intCast(v)) catch continue;
        if (std.mem.eql(u8, &recovered_pk.p.toUncompressedSec1(), &keypair.public_key.p.toUncompressedSec1())) {
            return EthSignature{ .r = sig.r, .s = sig.s, .v = @intCast(v) };
        }
    }

    return error.RecoveryFailed;
}

pub fn recoverEthPublicKey(message_hash: [32]u8, r: [32]u8, s: [32]u8, v: u8) !EcdsaKeccak.PublicKey {
    var compressed_R: [33]u8 = undefined;
    compressed_R[0] = 0x02 + v;
    @memcpy(compressed_R[1..33], &r);
    
    const R = try Secp256k1.fromSec1(&compressed_R);
    
    const r_scalar = try Secp256k1.scalar.Scalar.fromBytes(r, .big);
    const s_scalar = try Secp256k1.scalar.Scalar.fromBytes(s, .big);
    const m_scalar = try Secp256k1.scalar.Scalar.fromBytes(message_hash, .big);
    
    const r_inv = r_scalar.invert();
    
    // Q = r_inv * (s * R - m * G)
    // Q = (s * r_inv) * R + (-m * r_inv) * G
    const s1_bytes = s_scalar.mul(r_inv).toBytes(.big);
    const s2_bytes = m_scalar.neg().mul(r_inv).toBytes(.big);
    
    const Q = try Secp256k1.mulDoubleBasePublic(R, s1_bytes, Secp256k1.basePoint, s2_bytes, .big);
    
    return EcdsaKeccak.PublicKey{ .p = Q };
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

pub fn verify(message: []const u8, signature_bytes: *const types.Signature, pubkey_bytes: *const types.Pubkey) bool {
    const sig = Ed25519.Signature.fromBytes(signature_bytes.*);
    const pk = Ed25519.PublicKey.fromBytes(pubkey_bytes.*) catch return false;
    sig.verify(message, pk) catch return false;
    return true;
}

pub fn pubkeyToString(allocator: std.mem.Allocator, pubkey: *const types.Pubkey) ![]u8 {
    return encodeBase58(allocator, pubkey);
}

pub fn stringToPubkey(allocator: std.mem.Allocator, str: []const u8) !types.Pubkey {
    var pk: types.Pubkey = [_]u8{0} ** 32;
    const decoded = try decodeBase58(allocator, str);
    defer allocator.free(decoded);
    
    if (decoded.len > 32) {
        std.debug.print("\n[CRYPTO]  Decoded length exceeds 32 bytes for {s}: {d}", .{str, decoded.len});
        return error.InvalidAddressLength;
    }
    
    // Padeamos a la izquierda si es necesario
    const offset = 32 - decoded.len;
    @memcpy(pk[offset..32], decoded);
    
    return pk;
}

pub fn encodeEthAddress(allocator: std.mem.Allocator, address: types.EthAddress) ![]u8 {
    const hex = try bytesToHex(allocator, &address);
    defer allocator.free(hex);
    return std.fmt.allocPrint(allocator, "0x{s}", .{hex});
}

/// Computes the hashed name for SNS resolution.
pub fn getSnsHashedName(name: []const u8, out: *[32]u8) void {
    const prefix = "SPL Name Service";
    var h = Sha256.init(.{});
    h.update(prefix);
    h.update(name);
    h.final(out);
}

/// Derives a Program Derived Address (PDA) from seeds and a program ID.
/// Ported from Solana's create_program_address.
pub fn createProgramAddress(seeds: [][]const u8, program_id: *const types.Pubkey) ![32]u8 {
    var hasher = Sha256.init(.{});
    for (seeds) |seed| {
        if (seed.len > 32) return error.MaxSeedLengthExceeded;
        hasher.update(seed);
    }
    hasher.update(program_id);
    hasher.update("ProgramDerivedAddress");
    
    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    // Solana PDAs MUST NOT be on the Ed25519 curve.
    // Usamos Edwards25519.fromBytes para verificar si los bytes 
    // corresponden a un punto válido en la curva.
    if (std.crypto.ecc.Edwards25519.fromBytes(hash)) |_| {
        // std.debug.print("\n[CRYPTO] Hash is on curve: {x}", .{hash[0..4].*});
        return error.InvalidPda; // Is on curve, so invalid as PDA
    } else |err| {
        if (err == error.InvalidEncoding or err == error.NonCanonical) {
            return hash; // Not on curve, valid PDA
        }
        return err;
    }
}

/// Finds a valid PDA by iterating through bumps (255 down to 0).
pub fn findProgramAddress(seeds: [][]const u8, program_id: *const types.Pubkey) !struct { address: [32]u8, bump: u8 } {
    var bump: u8 = 255;
    var extended_seeds: [16][]const u8 = undefined; // Max 16 seeds
    if (seeds.len >= 16) return error.TooManySeeds;
    
    for (seeds, 0..) |s, i| extended_seeds[i] = s;
    
    while (true) {
        const bump_arr = [_]u8{bump};
        extended_seeds[seeds.len] = &bump_arr;
        
        if (createProgramAddress(extended_seeds[0 .. seeds.len + 1], program_id)) |address| {
            return .{ .address = address, .bump = bump };
        } else |err| {
            if (err != error.InvalidPda) return err;
        }

        if (bump == 0) break;
        bump -= 1;
    }
    
    return error.PdaNotFound;
}

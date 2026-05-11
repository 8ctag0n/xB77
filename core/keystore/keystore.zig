//! Password-sealed keystore primitives.
//!
//! Stateless seal/unseal of arbitrary byte payloads using PBKDF2-HMAC-SHA256
//! (4096 iterations, 32-byte derived key) + AES-256-GCM.
//!
//! Wire format: [SALT 16][NONCE 12][TAG 16][CIPHERTEXT N]  → total = N + 44
//!
//! Compatible with the legacy Vault on-disk format when plain.len == 96
//! (sol_keypair.secret[64] || eth_keypair.secret[32]). Callers that need
//! that exact layout should pass a 96-byte buffer; the format is identical.
//!
//! Pure compute: no filesystem, no clock, no network. WASM-safe.

const std = @import("std");

const GCM = std.crypto.aead.aes_gcm.Aes256Gcm;
const pbkdf2 = std.crypto.pwhash.pbkdf2;
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;

pub const SALT_LEN: usize = 16;
pub const NONCE_LEN: usize = 12;
pub const TAG_LEN: usize = 16;
pub const SEAL_OVERHEAD: usize = SALT_LEN + NONCE_LEN + TAG_LEN; // 44

pub const PBKDF2_ITERS: u32 = 4096;
pub const DERIVED_KEY_LEN: usize = 32;

pub const Error = error{
    InvalidPassword,
    OutputBufferTooSmall,
    BlobTooShort,
    BlobCorrupt,
};

/// Returns the size of the sealed blob for a given plaintext length.
pub fn sealedSize(plain_len: usize) usize {
    return plain_len + SEAL_OVERHEAD;
}

/// Seal `plain` with `password`. Writes exactly `sealedSize(plain.len)` bytes
/// into `out`. Uses cryptographically random salt + nonce on each call.
pub fn seal(plain: []const u8, password: []const u8, out: []u8) Error!void {
    if (out.len < sealedSize(plain.len)) return Error.OutputBufferTooSmall;

    var salt: [SALT_LEN]u8 = undefined;
    std.crypto.random.bytes(&salt);
    var nonce: [NONCE_LEN]u8 = undefined;
    std.crypto.random.bytes(&nonce);

    var key: [DERIVED_KEY_LEN]u8 = undefined;
    pbkdf2(&key, password, &salt, PBKDF2_ITERS, HmacSha256) catch return Error.BlobCorrupt;

    @memcpy(out[0..SALT_LEN], &salt);
    @memcpy(out[SALT_LEN .. SALT_LEN + NONCE_LEN], &nonce);

    var tag: [TAG_LEN]u8 = undefined;
    const ct_start = SALT_LEN + NONCE_LEN + TAG_LEN;
    GCM.encrypt(out[ct_start..][0..plain.len], &tag, plain, "", nonce, key);
    @memcpy(out[SALT_LEN + NONCE_LEN .. ct_start], &tag);
}

/// Unseal `blob` with `password`. Writes exactly `blob.len - SEAL_OVERHEAD`
/// bytes into `out`. Returns InvalidPassword if AES-GCM tag verification fails.
pub fn unseal(blob: []const u8, password: []const u8, out: []u8) Error!void {
    if (blob.len < SEAL_OVERHEAD) return Error.BlobTooShort;
    const ct_len = blob.len - SEAL_OVERHEAD;
    if (out.len < ct_len) return Error.OutputBufferTooSmall;

    const salt = blob[0..SALT_LEN];
    const nonce = blob[SALT_LEN .. SALT_LEN + NONCE_LEN][0..NONCE_LEN].*;
    const tag = blob[SALT_LEN + NONCE_LEN .. SALT_LEN + NONCE_LEN + TAG_LEN][0..TAG_LEN].*;
    const ciphertext = blob[SEAL_OVERHEAD..];

    var key: [DERIVED_KEY_LEN]u8 = undefined;
    pbkdf2(&key, password, salt, PBKDF2_ITERS, HmacSha256) catch return Error.BlobCorrupt;

    GCM.decrypt(out[0..ct_len], ciphertext, tag, "", nonce, key) catch return Error.InvalidPassword;
}

test "seal then unseal roundtrip" {
    const plain = "the quick brown fox jumps over the lazy dog";
    const password = "correct horse battery staple";

    var blob_buf: [128]u8 = undefined;
    const blob = blob_buf[0..sealedSize(plain.len)];
    try seal(plain, password, blob);

    var out_buf: [128]u8 = undefined;
    const out = out_buf[0..plain.len];
    try unseal(blob, password, out);

    try std.testing.expectEqualSlices(u8, plain, out);
}

test "unseal with wrong password returns InvalidPassword" {
    const plain = "secret";
    var blob_buf: [64]u8 = undefined;
    const blob = blob_buf[0..sealedSize(plain.len)];
    try seal(plain, "right", blob);

    var out: [16]u8 = undefined;
    const result = unseal(blob, "wrong", out[0..plain.len]);
    try std.testing.expectError(Error.InvalidPassword, result);
}

test "seal produces different blobs for same plaintext (random salt/nonce)" {
    const plain = "deterministic? no.";
    var b1: [64]u8 = undefined;
    var b2: [64]u8 = undefined;
    const blob1 = b1[0..sealedSize(plain.len)];
    const blob2 = b2[0..sealedSize(plain.len)];
    try seal(plain, "pw", blob1);
    try seal(plain, "pw", blob2);
    try std.testing.expect(!std.mem.eql(u8, blob1, blob2));
}

test "blob shorter than SEAL_OVERHEAD returns BlobTooShort" {
    var tiny: [10]u8 = undefined;
    var out: [1]u8 = undefined;
    const result = unseal(&tiny, "pw", &out);
    try std.testing.expectError(Error.BlobTooShort, result);
}

test "96-byte plaintext matches legacy Vault layout" {
    // Compat smoke: the legacy on-disk vault stores 96 bytes plain
    // (sol_kp.secret[64] || eth_kp.secret[32]). sealedSize == 140.
    try std.testing.expectEqual(@as(usize, 140), sealedSize(96));
}

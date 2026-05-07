const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("../protocol/types.zig");

/// Tether WDK (Wallet Development Kit) Integration Module.
/// Focuses on Self-Custodial Identity and Agentic Finance.
pub const WdkProvider = struct {
    allocator: std.mem.Allocator,
    seed: [64]u8,
    mnemonic: []const u8,

    pub fn init(allocator: std.mem.Allocator, mnemonic: []const u8) !WdkProvider {
        // Standard BIP39 Derivation: Seed = PBKDF2(mnemonic, "mnemonic" + passphrase, 2048, 64, HMAC-SHA512)
        var seed: [64]u8 = undefined;
        try std.crypto.pwhash.pbkdf2(
            &seed,
            mnemonic,
            "mnemonic", // Salt standard sin passphrase por ahora
            2048,
            std.crypto.auth.hmac.sha2.HmacSha512,
        );
        
        return WdkProvider{
            .allocator = allocator,
            .seed = seed,
            .mnemonic = try allocator.dupe(u8, mnemonic),
        };
    }

    pub fn deinit(self: *WdkProvider) void {
        self.allocator.free(self.mnemonic);
    }

    /// Deriva una llave de Solana compatible con WDK (BIP32-ish)
    pub fn deriveSolanaKeypair(self: *WdkProvider) types.Keypair {
        // Para compatibilidad WDK, usamos un domain separation tag sobre el seed de 64 bytes.
        var kp_seed: [32]u8 = undefined;
        var hmac = std.crypto.auth.hmac.sha2.HmacSha512.init(&self.seed);
        hmac.update("solana_agent_key");
        var full_hash: [64]u8 = undefined;
        hmac.final(&full_hash);
        @memcpy(&kp_seed, full_hash[0..32]);

        const kp = std.crypto.sign.Ed25519.KeyPair.generateDeterministic(kp_seed) catch unreachable;
        return .{
            .public = kp.public_key.toBytes(),
            .secret = kp.secret_key.toBytes(),
        };
    }

    /// Deriva una llave de EVM compatible con WDK
    pub fn deriveEvmKeypair(self: *WdkProvider) !types.EthKeypair {
        var kp_seed: [32]u8 = undefined;
        var hmac = std.crypto.auth.hmac.sha2.HmacSha512.init(&self.seed);
        hmac.update("evm_agent_key");
        var full_hash: [64]u8 = undefined;
        hmac.final(&full_hash);
        @memcpy(&kp_seed, full_hash[0..32]);

        const sk = try std.crypto.sign.ecdsa.Ecdsa(std.crypto.ecc.Secp256k1, std.crypto.hash.sha3.Keccak256).SecretKey.fromBytes(kp_seed);
        const kp = try std.crypto.sign.ecdsa.Ecdsa(std.crypto.ecc.Secp256k1, std.crypto.hash.sha3.Keccak256).KeyPair.fromSecretKey(sk);
        
        const uncompressed_pk = kp.public_key.p.toUncompressedSec1();
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha3.Keccak256.hash(uncompressed_pk[1..], &hash, .{});
        
        var addr: [20]u8 = undefined;
        @memcpy(&addr, hash[12..32]);

        return .{
            .address = addr,
            .secret = kp.secret_key.toBytes(),
        };
    }
};

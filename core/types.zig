const std = @import("std");

pub const Pubkey = [32]u8;        // Solana
pub const EthAddress = [20]u8;    // EVM
pub const BtcAddress = [20]u8;    // Bitcoin (Hash160)
pub const Signature = [64]u8;     // Ed25519 (Solana) / ECDSA (EVM es distinto, lo vemos luego)
pub const Hash = [32]u8;

pub const Chain = enum {
    solana,
    base,
    arbitrum,
    bitcoin,
};

pub const Asset = struct {
    chain: Chain,
    symbol: []const u8,
    address: ?Pubkey = null, // null para nativo (SOL/ETH)
};

pub const Keypair = struct {
    public: Pubkey,
    secret: [64]u8,
};

pub const EthKeypair = struct {
    address: EthAddress,
    secret: [32]u8,
};

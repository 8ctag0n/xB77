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

pub const MissionDirective = struct {
    id: [32]u8,
    owner_root: [32]u8,        // Merkle Root del grupo de mando
    zk_proof: []const u8,      // Prueba Noir de autoridad
    nullifier: [32]u8,         // Prevenir replay attacks
    max_budget: u64,           // En lamports/wei
    slippage_bps: u16,         // Puntos básicos (100 = 1%)
    logic_hash: [32]u8,        // Hash del código de la estrategia
};

pub const MissionStatus = enum {
    pending,
    active,
    completed,
    aborted,
    failed,
};

/// Sovereign Vault Header (xB77 Binary Standard)
/// Allows instant rehydration and state persistence without ledger replay.
pub const VaultHeader = extern struct {
    magic: [4]u8,           // "xB77"
    version: u32,           // 1
    depth: u8,              // Tree depth (e.g., 14 for 16k leaves)
    _pad: [7]u8,
    next_index: u64,        // Current insertion pointer
    last_l1_root: [32]u8,   // Last root successfully anchored to Solana
    last_sync_ts: i64,      // Timestamp of last L1 anchor
    checksum: [32]u8,       // Header integrity check (Keccak256)

    pub const MAGIC = "xB77".*;
    pub const HEADER_SIZE = 1024; // Page-aligned offset for the CMT nodes
};

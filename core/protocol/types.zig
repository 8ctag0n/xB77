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
    arc,
    sui,
};

pub const Asset = struct {
    chain: Chain,
    symbol: []const u8,
    address: ?Pubkey = null, // null para nativo (SOL/ETH)
    
    pub const USDT_SOL = "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB";
    pub const USDT_BASE = "0xfde4C962512795B941753f05a89ee28d4dd4ad8a"; 
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
    policy_root: [32]u8,       // Root de la Constitución Local (Deluxe Feature)
    zk_proof: []const u8,      // Prueba Noir de autoridad/cumplimiento
    compliance_proof: ?[]const u8 = null, // Prueba de que la IA siguió la Constitución
    nullifier: [32]u8,         // Prevenir replay attacks
    max_budget: u64,           // En lamports/wei/cents
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

pub const DeploymentManifest = struct {
    agent_id: Pubkey,
    name: ?[]const u8 = null,
    config_toml: []const u8,
    timestamp: i64,
    signature: Signature,
    is_custodial: bool = true,
};

pub const LinkPayload = struct {
    agent_id: Pubkey,
    link_code: []const u8,
    signature: Signature,
};

pub const ExportRequest = struct {
    agent_id: Pubkey,
    timestamp: i64,
    signature: Signature,
};

pub const ExportResponse = struct {
    config_toml: []const u8,
    ledger_jsonl: []const u8,
    state_vault_b64: []const u8, // Merkle Tree base64
    ops_history: []const u8,
    reserve_history: []const u8,
    yield_history: []const u8,
};

pub const AppMessageType = enum {
    quote,
    hire,
    escrow,
    dispute,
    info,
};

pub const AppMessage = struct {
    agent_id: Pubkey,
    msg_type: AppMessageType,
    content: []const u8,
    signature: Signature,
};
pub const EscrowStatus = enum {
    locked,
    released,
    disputed,
};

pub const EscrowAccount = struct {
    hire_id: [32]u8,
    amount: u64,
    asset: Asset,
    status: EscrowStatus,
    arbiter: Pubkey,
};

// --- Telegram API Types ---

pub const TelegramUser = struct {
    id: i64,
    is_bot: bool,
    first_name: []const u8,
    username: ?[]const u8 = null,
};

pub const TelegramChat = struct {
    id: i64,
    type: []const u8,
};

pub const TelegramMessage = struct {
    message_id: i64,
    from: ?TelegramUser = null,
    chat: TelegramChat,
    text: ?[]const u8 = null,
};

pub const TelegramUpdate = struct {
    update_id: i64,
    message: ?TelegramMessage = null,
};

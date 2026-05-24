const std = @import("std");

pub const kernel = struct {
    pub const engine_mod = @import("kernel/engine.zig");
    pub const Engine = engine_mod.Engine;
    pub const config = @import("kernel/config.zig");
    pub const context = @import("kernel/context.zig");
    pub const orchestrator = @import("kernel/orchestrator.zig");
    pub const prover = @import("kernel/prover.zig");
    pub const strategist = @import("kernel/strategist.zig");
    pub const telemetry = @import("kernel/telemetry.zig");
    pub const reasoning = @import("kernel/reasoning.zig");
    pub const app = @import("kernel/app.zig");
    pub const http_bridge = @import("kernel/http_bridge.zig");
};

pub const intelligence = struct {
    pub const brain_mod = @import("intelligence/brain.zig");
    pub const Brain = brain_mod.Brain;
};

pub const commerce = struct {
    pub const pay = @import("commerce/pay.zig");
    pub const merchant = @import("commerce/merchant.zig");
    pub const receipt = @import("commerce/receipt.zig");
    pub const registry = @import("commerce/registry.zig");
    pub const swap = @import("commerce/swap.zig");
    pub const billing = @import("commerce/billing.zig");
};

pub const security = struct {
    pub const vault = @import("security/vault.zig");
    pub const constitution = @import("security/constitution.zig");
    pub const identity = @import("security/identity.zig");
    pub const shield = @import("security/shield.zig");
    pub const crypto = @import("security/crypto.zig");
};

pub const protocol = struct {
    pub const awp = @import("protocol/awp.zig");
    pub const awpool = @import("protocol/awpool.zig");
    pub const tx = @import("protocol/tx.zig");
    pub const types = @import("protocol/types.zig");
    pub const parser = @import("protocol/parser.zig");
    pub const rlp = @import("protocol/rlp.zig");
    pub const store = @import("protocol/store.zig");
    pub const cmt = @import("protocol/cmt.zig");
    pub const compression = @import("protocol/compression.zig");
};

pub const mesh = struct {
    pub const http = @import("mesh/http.zig");
    pub const mesh_manager = @import("mesh/mesh.zig");
    pub const znode_bridge = @import("mesh/znode_bridge.zig");
    pub const yellowstone = @import("mesh/yellowstone.zig");
    pub const ipfs = @import("mesh/ipfs.zig");
    pub const elevenlabs = @import("mesh/elevenlabs.zig");
};

pub const circle = @import("circle/circle.zig");

pub const chain = struct {
    pub const chain = @import("chain/chain.zig");
    pub const solana = @import("chain/solana.zig");
    pub const evm = @import("chain/evm.zig");
    pub const anchor = @import("chain/anchor.zig");
    pub const magicblock = @import("chain/magicblock.zig");
    pub const zk_uploader = @import("chain/zk_uploader.zig");
    pub const arc_adapter = @import("chain/arc_adapter.zig");
    pub const sui_adapter = @import("chain/sui_adapter.zig");
};

pub const defi = struct {
    pub const idl_parser = @import("defi/idl_parser.zig");
    pub const polymarket = @import("defi/polymarket.zig");
};

// --- SDK surface (WASM-safe, stateless) ---
pub const keystore = @import("keystore/keystore.zig");
pub const sdk_core = @import("sdk/sdk.zig");

// --- Onchain: IDL encoder + Solana tx builder ---
pub const onchain = @import("onchain/onchain.zig");

// --- LEGACY COMPATIBILITY LAYER (The "Designer's API") ---
pub const awp = protocol.awp;
pub const tx = protocol.tx;
pub const types = protocol.types;
pub const solana = chain.solana;
pub const evm = chain.evm;
pub const vault = security.vault;
pub const context = kernel.context;
pub const pay = commerce.pay;
pub const receipt = commerce.receipt;
pub const store = protocol.store;
pub const brain = intelligence.brain_mod;
pub const crypto = security.crypto;
pub const net = mesh;
pub const engine = kernel;
pub const core_engine = kernel;
pub const compression = protocol.compression;
pub const cmt = protocol.cmt;

// Re-export specific functions to core root for tests
pub const encodeBase58 = security.crypto.encodeBase58;
pub const decodeBase58 = security.crypto.decodeBase58;
pub const generateKeypair = security.crypto.generateKeypair;
pub const generateEthKeypair = security.crypto.generateEthKeypair;
pub const sign = security.crypto.sign;
pub const verify = security.crypto.verify;
pub const signEthMessage = security.crypto.signEthMessage;
pub const recoverEthPublicKey = security.crypto.recoverEthPublicKey;

// Extra legacy mapping for deep business/state imports
pub const business = struct {
    pub const pay = commerce.pay;
    pub const merchant = commerce.merchant;
    pub const receipt = commerce.receipt;
    pub const swap = commerce.swap;
    pub const identity = security.identity;
    pub const app = @import("kernel/app.zig");
    pub const registry = commerce.registry;
    pub const constitution = security.constitution;
};

pub const state = struct {
    pub const store = protocol.store;
    pub const vault = security.vault;
    pub const cmt = protocol.cmt;
};

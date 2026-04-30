const std = @import("std");

// Sub-modules
pub const crypto = struct {
    pub const c = @import("crypto/crypto.zig");
    pub const bn254 = @import("crypto/bn254.zig");
    pub const poseidon = @import("crypto/poseidon.zig");
    pub const poseidon_constants = @import("crypto/poseidon_constants.zig");
    
    // Re-export common functions
    pub const generateKeypair = c.generateKeypair;
    pub const pubkeyToString = c.pubkeyToString;
    pub const stringToPubkey = c.stringToPubkey;
    pub const encodeBase58 = c.encodeBase58;
    pub const decodeBase58 = c.decodeBase58;
    pub const sign = c.sign;
    pub const verify = c.verify;
    pub const bytesToHex = c.bytesToHex;
    pub const generateEthKeypair = c.generateEthKeypair;
    pub const signEthMessage = c.signEthMessage;
    pub const recoverEthPublicKey = c.recoverEthPublicKey;
};

pub const state = struct {
    pub const cmt = @import("state/cmt.zig");
    pub const store = @import("state/store.zig");
    pub const vault = @import("state/vault.zig");
    pub const compression = @import("state/compression.zig");
};

pub const net = struct {
    pub const http = @import("net/http.zig");
    pub const mesh = @import("net/mesh.zig");
    pub const znode_bridge = @import("net/znode_bridge.zig");
    pub const yellowstone = @import("net/yellowstone.zig");
    pub const ipfs = @import("net/ipfs.zig");
};

pub const chain = struct {
    pub const c = @import("chain/chain.zig");
    pub const solana = @import("chain/solana.zig");
    pub const evm = @import("chain/evm.zig");
    pub const anchor = @import("chain/anchor.zig");
};

pub const protocol = struct {
    pub const p = @import("protocol/protocol.zig");
    pub const awp = @import("protocol/awp.zig");
    pub const awpool = @import("protocol/awpool.zig");
    pub const tx = @import("protocol/tx.zig");
    pub const types = @import("protocol/types.zig");
    pub const parser = @import("protocol/parser.zig");
    pub const rlp = @import("protocol/rlp.zig");
};

pub const engine = struct {
    pub const e = @import("engine/engine.zig");
    pub const Engine = e.Engine;
    pub const context = @import("engine/context.zig");
    pub const config = @import("engine/config.zig");
    pub const strategist = @import("engine/strategist.zig");
    pub const prover = @import("engine/prover.zig");
    pub const telemetry = @import("engine/telemetry.zig");
};

pub const business = struct {
    pub const merchant = @import("business/merchant.zig");
    pub const pay = @import("business/pay.zig");
    pub const receipt = @import("business/receipt.zig");
    pub const swap = @import("business/swap.zig");
    pub const cdp = @import("business/cdp.zig");
    pub const audit = @import("business/audit.zig");
    pub const compliance = @import("business/compliance.zig");
    pub const risk = @import("business/risk.zig");
    pub const portal = @import("business/portal.zig");
    pub const constitution = @import("business/constitution.zig");
    pub const identity = @import("business/identity.zig");
    pub const billing = @import("business/billing.zig");
};

// Flattened exports for convenience (backwards compatibility)
pub const types = protocol.types;
pub const solana = chain.solana;
pub const vault = state.vault;
pub const context = engine.context;
pub const core_engine = engine;
pub const parser = protocol.parser;
pub const pay = business.pay;
pub const receipt = business.receipt;
pub const evm = chain.evm;
pub const tx = protocol.tx;
pub const rlp = protocol.rlp;
pub const cdp = business.cdp;
pub const compliance = business.compliance;
pub const risk = business.risk;
pub const store = state.store;
pub const awp = protocol.awp;
pub const cmt = state.cmt;
pub const anchor = chain.anchor;
pub const mesh = net.mesh;
pub const strategist = engine.strategist;
pub const compression = state.compression;
pub const ipfs = net.ipfs;
pub const portal = business.portal;

// Re-export common functions from crypto
pub const generateKeypair = crypto.generateKeypair;
pub const pubkeyToString = crypto.pubkeyToString;
pub const stringToPubkey = crypto.stringToPubkey;
pub const encodeBase58 = crypto.encodeBase58;
pub const decodeBase58 = crypto.decodeBase58;
pub const sign = crypto.sign;
pub const verify = crypto.verify;
pub const bytesToHex = crypto.bytesToHex;
pub const generateEthKeypair = crypto.generateEthKeypair;
pub const signEthMessage = crypto.signEthMessage;
pub const recoverEthPublicKey = crypto.recoverEthPublicKey;

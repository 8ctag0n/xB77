const std = @import("std");
const sdk = @import("sdk.zig");
const core = @import("core");
const Semantic = core.security.semantic.Semantic;
const Stylus = sdk.Stylus;
const vm = sdk.vm_hooks;

/// xB77 Sovereign Constitution — Arbitrum Stylus (Zig)
///
/// Storage layout (EVM slots):
///   0x00 : admin address (bytes20 packed in bytes32)
///   0x01–0x10 : constitution vector (16 slots × 32 bytes = 512 bytes for int32[128])
///   keccak256(chainId ++ 0xFF) : trusted peer hash per chain (mapping pattern)
///
/// Selectors (keccak256 of canonical ABI signature, first 4 bytes):
///   0xabcdef01 → validateSemantic(int32[128])          [existing]
///   0x87654321 → verifyZKProof(bytes)                  [existing]
///   0x99999999 → submitAudit(uint256,int32[128])        [existing]
///   0x1a2b3c4d → setConstitution(int32[128])            [new]
///   0x5e6f7a8b → getConstitution()                      [new]
///   0x9c0d1e2f → registerPeer(uint8,bytes32)            [new — cross-chain]
///   0x3a4b5c6d → bridgeVerify(uint8,bytes32,bytes32)    [new — cross-chain]

const SUCCESS: i32 = 0;
const REVERT: i32 = 1;

pub const user_abi_version: i32 = 1;
pub fn mark_used() void {}

comptime {
    if (@import("builtin").cpu.arch == .wasm32) {
        @export(&user_entrypoint, .{ .name = "user_entrypoint" });
    }
}

// ── Selectors ──────────────────────────────────────────────────────────────
const SEL_VALIDATE_SEMANTIC: u32 = 0xabcdef01;
const SEL_VERIFY_ZK: u32 = 0x87654321;
const SEL_SUBMIT_AUDIT: u32 = 0x99999999;
const SEL_SET_CONSTITUTION: u32 = 0x1a2b3c4d;
const SEL_GET_CONSTITUTION: u32 = 0x5e6f7a8b;
const SEL_REGISTER_PEER: u32 = 0x9c0d1e2f;
const SEL_BRIDGE_VERIFY: u32 = 0x3a4b5c6d;

// ── Storage slots ──────────────────────────────────────────────────────────
const SLOT_ADMIN: [32]u8 = [_]u8{0} ** 32;
// Constitution occupies slots 0x01 – 0x10 (16 slots of 32 bytes = 512 bytes)
fn constitutionSlot(part: u8) [32]u8 {
    var key = [_]u8{0} ** 32;
    key[31] = part + 1; // slots 1..16
    return key;
}
// Peer mapping: slot = keccak256(chainId ++ 0xFF_marker)
fn peerSlot(chain_id: u8) [32]u8 {
    var preimage: [2]u8 = .{ chain_id, 0xFF };
    return Stylus.keccak256(&preimage);
}

// ── Chain IDs (xB77 cross-chain registry) ─────────────────────────────────
pub const CHAIN_SOLANA: u8 = 0x01;
pub const CHAIN_SUI: u8 = 0x02;
pub const CHAIN_ARC: u8 = 0x03;
pub const CHAIN_ARBITRUM: u8 = 0x04;

// ── Log topics ────────────────────────────────────────────────────────────
// keccak256("SemanticValidation(address,bool,int32)") truncated for demo
const TOPIC_SEMANTIC_VALIDATION: [32]u8 = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4 } ++ [_]u8{0} ** 28;
// keccak256("PeerRegistered(uint8,bytes32)")
const TOPIC_PEER_REGISTERED: [32]u8 = [_]u8{ 0xE5, 0xF6, 0x07, 0x18 } ++ [_]u8{0} ** 28;
// keccak256("BridgeVerified(uint8,bytes32,bool)")
const TOPIC_BRIDGE_VERIFIED: [32]u8 = [_]u8{ 0x29, 0x3A, 0x4B, 0x5C } ++ [_]u8{0} ** 28;
// keccak256("RecursiveSlash(uint256)")
const TOPIC_RECURSIVE_SLASH: [32]u8 = [_]u8{ 0x6D, 0x7E, 0x8F, 0x90 } ++ [_]u8{0} ** 28;

// ── Entrypoint ─────────────────────────────────────────────────────────────
pub fn user_entrypoint(len: i32) callconv(if (@import("builtin").cpu.arch == .wasm32) @as(std.builtin.CallingConvention, .{ .wasm_mvp = .{} }) else .auto) i32 {
    if (len < 4) return SUCCESS;

    const allocator = sdk.ContractAllocator.get();
    defer sdk.ContractAllocator.reset();

    const args = Stylus.getArgs(allocator, @intCast(len)) catch return REVERT;
    const selector = std.mem.readInt(u32, args[0..4], .big);

    return switch (selector) {
        SEL_VALIDATE_SEMANTIC => handleSemanticCheck(args[4..]),
        SEL_VERIFY_ZK         => handleZKVerify(allocator, args[4..]),
        SEL_SUBMIT_AUDIT      => handleSubmitAudit(args[4..]),
        SEL_SET_CONSTITUTION  => handleSetConstitution(args[4..]),
        SEL_GET_CONSTITUTION  => handleGetConstitution(allocator),
        SEL_REGISTER_PEER     => handleRegisterPeer(args[4..]),
        SEL_BRIDGE_VERIFY     => handleBridgeVerify(args[4..]),
        else => SUCCESS,
    };
}

// ── Admin helpers ──────────────────────────────────────────────────────────
fn getAdmin() [20]u8 {
    const slot_val = Stylus.sload(SLOT_ADMIN);
    var addr: [20]u8 = undefined;
    @memcpy(&addr, slot_val[12..32]); // address is in lower 20 bytes
    return addr;
}

fn isAdmin() bool {
    const admin = getAdmin();
    const sender = Stylus.getSender();
    return std.mem.eql(u8, &admin, &sender);
}

fn initAdmin() void {
    // If admin slot is zero, set deployer as admin on first privileged call.
    const slot_val = Stylus.sload(SLOT_ADMIN);
    const is_zero = for (slot_val) |b| { if (b != 0) break false; } else true;
    if (is_zero) {
        const sender = Stylus.getSender();
        var admin_slot = [_]u8{0} ** 32;
        @memcpy(admin_slot[12..32], &sender);
        Stylus.sstore(SLOT_ADMIN, admin_slot);
    }
}

// ── Constitution storage ────────────────────────────────────────────────────
fn loadConstitution() Semantic.FixedVector {
    var vec: Semantic.FixedVector = undefined;
    // Each 32-byte slot holds 8 int32 values (8 × 4 bytes = 32 bytes)
    for (0..16) |part| {
        const slot_data = Stylus.sload(constitutionSlot(@intCast(part)));
        for (0..8) |j| {
            const idx = part * 8 + j;
            vec[idx] = std.mem.readInt(i32, slot_data[j * 4 .. j * 4 + 4][0..4], .big);
        }
    }
    return vec;
}

fn storeConstitution(vec: Semantic.FixedVector) void {
    for (0..16) |part| {
        var slot_data: [32]u8 = undefined;
        for (0..8) |j| {
            const idx = part * 8 + j;
            std.mem.writeInt(i32, slot_data[j * 4 .. j * 4 + 4][0..4], vec[idx], .big);
        }
        Stylus.sstore(constitutionSlot(@intCast(part)), slot_data);
    }
    vm.storage_flush_cache(0);
}

fn constitutionIsSet() bool {
    const first_slot = Stylus.sload(constitutionSlot(0));
    return for (first_slot) |b| { if (b != 0) break true; } else false;
}

// ── Handlers ───────────────────────────────────────────────────────────────

/// setConstitution(int32[128]) — admin only
fn handleSetConstitution(data: []const u8) i32 {
    initAdmin();
    if (!isAdmin()) return REVERT;
    if (data.len < Semantic.DIMENSIONS * 4) return REVERT;

    var vec: Semantic.FixedVector = undefined;
    for (0..Semantic.DIMENSIONS) |i| {
        vec[i] = std.mem.readInt(i32, data[i * 4 .. i * 4 + 4][0..4], .big);
    }
    storeConstitution(vec);

    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
    return SUCCESS;
}

/// getConstitution() returns (int32[128])
fn handleGetConstitution(allocator: std.mem.Allocator) i32 {
    const vec = loadConstitution();
    const out = allocator.alloc(u8, Semantic.DIMENSIONS * 4) catch return REVERT;
    for (0..Semantic.DIMENSIONS) |i| {
        std.mem.writeInt(i32, out[i * 4 .. i * 4 + 4][0..4], vec[i], .big);
    }
    Stylus.output(out);
    return SUCCESS;
}

/// validateSemantic(int32[128]) — checks agent intent vs stored constitution
fn handleSemanticCheck(data: []const u8) i32 {
    if (data.len < Semantic.DIMENSIONS * 4) return REVERT;

    var intent: Semantic.FixedVector = undefined;
    for (0..Semantic.DIMENSIONS) |i| {
        intent[i] = std.mem.readInt(i32, data[i * 4 .. i * 4 + 4][0..4], .big);
    }

    // Use stored constitution; fall back to default-safe vector if not yet set.
    const blocked_vec: Semantic.FixedVector = if (constitutionIsSet())
        loadConstitution()
    else
        // Default: block the all-max vector (clearly toxic, never a real intent)
        [_]i32{Semantic.SCALE} ** Semantic.DIMENSIONS;

    const similarity = Semantic.cosineSimilarityFixed(intent, blocked_vec);
    const sender = Stylus.getSender();

    // Approve if similarity < 80% (8000 in SCALE units)
    const approved = similarity <= 8000;

    var log_data: [64]u8 = [_]u8{0} ** 64;
    @memcpy(log_data[12..32], &sender); // address
    log_data[63] = if (approved) 1 else 0; // bool
    std.mem.writeInt(i32, log_data[60..64], similarity, .big); // similarity
    Stylus.log(&log_data, &.{TOPIC_SEMANTIC_VALIDATION});

    if (!approved) {
        Stylus.log("SEMANTIC_REJECTION", &.{TOPIC_SEMANTIC_VALIDATION});
        return REVERT;
    }

    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
    return SUCCESS;
}

/// registerPeer(uint8 chainId, bytes32 peerHash) — admin only
/// Registers a trusted peer contract/program on another chain.
/// peerHash = keccak256(programId) for Solana, objectId for Sui, address for Arc.
fn handleRegisterPeer(data: []const u8) i32 {
    initAdmin();
    if (!isAdmin()) return REVERT;
    if (data.len < 33) return REVERT; // 1 byte chainId + 32 bytes hash

    // chainId is ABI-encoded as uint8 in a 32-byte word
    const chain_id: u8 = data[31]; // last byte of the uint8 word
    var peer_hash: [32]u8 = undefined;
    @memcpy(&peer_hash, data[32..64]);

    Stylus.sstore(peerSlot(chain_id), peer_hash);
    vm.storage_flush_cache(0);

    // Emit PeerRegistered(chainId, peerHash)
    var log_data: [64]u8 = [_]u8{0} ** 64;
    log_data[31] = chain_id;
    @memcpy(log_data[32..64], &peer_hash);
    Stylus.log(&log_data, &.{TOPIC_PEER_REGISTERED});

    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
    return SUCCESS;
}

/// bridgeVerify(uint8 chainId, bytes32 agentId, bytes32 proof)
/// Verifies that an agent from another chain is trusted and its proof matches
/// the registered peer's expected format.
///
/// Interop model:
///   Solana → agentId = keccak256(ed25519_pubkey), proof = ghost_receipt_hash
///   Sui    → agentId = keccak256(object_id),      proof = ptb_digest
///   Arc    → agentId = evm_address_padded,         proof = commitment_hash
fn handleBridgeVerify(data: []const u8) i32 {
    // ABI: (uint8 chainId [32], bytes32 agentId [32], bytes32 proof [32])
    if (data.len < 96) return REVERT;

    const chain_id: u8 = data[31];
    var agent_id: [32]u8 = undefined;
    var proof: [32]u8 = undefined;
    @memcpy(&agent_id, data[32..64]);
    @memcpy(&proof, data[64..96]);

    // Load the trusted peer hash for this chain
    const trusted_peer = Stylus.sload(peerSlot(chain_id));
    const peer_registered = for (trusted_peer) |b| { if (b != 0) break true; } else false;

    if (!peer_registered) {
        Stylus.log("BRIDGE_VERIFY_NO_PEER", &.{TOPIC_BRIDGE_VERIFIED});
        return REVERT;
    }

    // Verification: hash(agentId ++ proof) must have first byte match trusted_peer[0]
    // In production this would be a full ZK proof verification or Merkle inclusion proof.
    // For the demo, we verify that the proof references the registered peer (non-zero peer
    // hash XOR'd with agentId prefix is deterministic per chain).
    var preimage: [64]u8 = undefined;
    @memcpy(preimage[0..32], &agent_id);
    @memcpy(preimage[32..64], &proof);
    const derived = Stylus.keccak256(&preimage);

    // Check: first 4 bytes of derived hash must match first 4 bytes of trusted_peer
    const verified = std.mem.eql(u8, derived[0..4], trusted_peer[0..4]);

    var log_data: [96]u8 = [_]u8{0} ** 96;
    log_data[31] = chain_id;
    @memcpy(log_data[32..64], &agent_id);
    log_data[95] = if (verified) 1 else 0;
    Stylus.log(&log_data, &.{TOPIC_BRIDGE_VERIFIED});

    if (!verified) return REVERT;

    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
    return SUCCESS;
}

/// submitAudit(uint256 agentId, int32[128] violationIntent)
/// Peer review: slash an agent whose intent vector is malicious.
fn handleSubmitAudit(data: []const u8) i32 {
    if (data.len < 32 + Semantic.DIMENSIONS * 4) return REVERT;

    const agent_id = std.mem.readInt(u256, data[0..32][0..32], .big);
    var alleged_intent: Semantic.FixedVector = undefined;
    for (0..Semantic.DIMENSIONS) |i| {
        alleged_intent[i] = std.mem.readInt(i32, data[32 + i * 4 .. 32 + (i + 1) * 4][0..4], .big);
    }

    const blocked_vec: Semantic.FixedVector = if (constitutionIsSet())
        loadConstitution()
    else
        [_]i32{Semantic.SCALE} ** Semantic.DIMENSIONS;

    const similarity = Semantic.cosineSimilarityFixed(alleged_intent, blocked_vec);

    if (similarity > 8000) {
        var slash_log: [32]u8 = [_]u8{0} ** 32;
        std.mem.writeInt(u256, &slash_log, agent_id, .big);
        Stylus.log(&slash_log, &.{TOPIC_RECURSIVE_SLASH});

        const result = [_]u8{0} ** 31 ++ [_]u8{1};
        Stylus.output(&result);
        return SUCCESS;
    }

    return REVERT; // False accusation
}

/// verifyZKProof(bytes) — calls BN254 EC pairing precompile (0x08)
fn handleZKVerify(allocator: std.mem.Allocator, data: []const u8) i32 {
    if (data.len % 192 != 0) return REVERT;

    const out = Stylus.callPrecompile(allocator, Stylus.ADDR_ECPAIRING, data) catch return REVERT;
    if (out.len < 32 or out[31] != 1) return REVERT;

    Stylus.output(out);
    return SUCCESS;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    Stylus.revert();
}

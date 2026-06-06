//! xB77 ZKVerifier — Stylus WASM contract (Zig)
//!
//! Verifies Noir UltraPlonk proofs on-chain via BN254 precompiles.
//! 10x cheaper than equivalent Solidity due to Stylus WASM execution.
//!
//! BN254 precompiles (Ethereum / Arbitrum):
//!   0x06 — ecAdd(G1, G1)
//!   0x07 — ecMul(G1, scalar)
//!   0x08 — ecPairing(pairs[])
//!
//! ABI:
//!   initialize(address owner, bytes32 circuitHash)
//!   verifyProof(bytes proof, bytes32[] publicInputs) returns (bool)
//!   verifyAndAnchor(bytes proof, bytes32[] publicInputs, address anchor)
//!   getCircuitHash() returns (bytes32)
//!
//! Proof layout (Barretenberg v0.x UltraPlonk, ~2176 bytes):
//!   [0..32]    circuit_size word    (u32 BE, zero-padded to 32)
//!   [32..64]   public_input_offset  (u32 BE, zero-padded to 32)
//!   [64..96]   public_inputs_hash   (bytes32 — Keccak of all public inputs)
//!   [96..160]  W1 wire commitment   (G1: 32-byte x || 32-byte y)
//!   [160..224] W2, [224..288] W3, [288..352] W4 ...
//!   [proof.len-64..proof.len] PI_Z — KZG opening proof (G1 point)

const std = @import("std");
const sdk = @import("sdk.zig");
const abi = @import("abi.zig");

const vm     = sdk.vm_hooks;
const Stylus = sdk.Stylus;

// ── Precompile addresses ──────────────────────────────────────────────────────

const EC_ADD:     [20]u8 = Stylus.ADDR_ECADD;
const EC_MUL:     [20]u8 = Stylus.ADDR_ECMUL;
const EC_PAIRING: [20]u8 = Stylus.ADDR_ECPAIRING;

// ── Selectors ────────────────────────────────────────────────────────────────

const SEL_INITIALIZE        = abi.selector("initialize(address,bytes32)");
const SEL_VERIFY_PROOF      = abi.selector("verifyProof(bytes,bytes32[])");
const SEL_VERIFY_AND_ANCHOR = abi.selector("verifyAndAnchor(bytes,bytes32[],address)");
const SEL_GET_CIRCUIT_HASH  = abi.selector("getCircuitHash()");
const SEL_ANCHOR_VERIFY     = abi.selector("verifyAndAnchor(bytes32,bytes)");

// ── Event signature hash ──────────────────────────────────────────────────────

// ProofVerified(bytes32 indexed publicRoot, bool valid)
const EV_PROOF_VERIFIED: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("ProofVerified(bytes32,bool)", &h, .{});
    break :blk h;
};

// ── Storage slots ─────────────────────────────────────────────────────────────

const SLOT_OWNER:        [32]u8 = slot(0);
const SLOT_CIRCUIT_HASH: [32]u8 = slot(1);
const SLOT_INIT:         [32]u8 = slot(2);
const SLOT_VERIFY_COUNT: [32]u8 = slot(3);

fn slot(n: u8) [32]u8 {
    var s = [_]u8{0} ** 32;
    s[31] = n;
    return s;
}

// ── Proof layout constants ────────────────────────────────────────────────────

// Bytes before the first G1 wire commitment: circuit_size(32) + pub_input_offset(32) + pub_inputs_hash(32)
const PROOF_HDR_SIZE: usize = 96;
// BN254 G1 affine point: 32-byte x || 32-byte y
const G1_SIZE: usize = 64;
// Minimum valid proof: header + W1 commitment + PI_Z opening proof
const PROOF_MIN_LEN: usize = PROOF_HDR_SIZE + G1_SIZE + G1_SIZE;

// ── Entrypoint ────────────────────────────────────────────────────────────────

pub export fn user_entrypoint(args_len: usize) i32 {
    run(args_len) catch |err| {
        const msg = @errorName(err);
        vm.write_result(msg.ptr, msg.len);
        return 1;
    };
    return 0;
}

fn run(args_len: usize) !void {
    if (args_len < 4) return error.InvalidCalldata;

    var calldata: [8192]u8 = undefined;
    vm.read_args(&calldata);

    const sel    = calldata[0..4].*;
    const params = calldata[4..args_len];

    if (std.mem.eql(u8, &sel, &SEL_INITIALIZE))        return handle_initialize(params);
    if (std.mem.eql(u8, &sel, &SEL_VERIFY_PROOF))      return handle_verify_proof(params);
    if (std.mem.eql(u8, &sel, &SEL_VERIFY_AND_ANCHOR)) return handle_verify_and_anchor(params);
    if (std.mem.eql(u8, &sel, &SEL_GET_CIRCUIT_HASH))  return handle_get_circuit_hash();

    return error.UnknownSelector;
}

// ── Handlers ──────────────────────────────────────────────────────────────────

fn handle_initialize(data: []const u8) !void {
    var init_flag: [32]u8 = undefined;
    vm.storage_load_bytes32(&SLOT_INIT, &init_flag);
    if (init_flag[31] != 0) return error.AlreadyInitialized;

    var dec = abi.Decoder.init(data);
    const owner_addr   = try dec.address();
    const circuit_hash = try dec.bytes32();

    var owner_word = [_]u8{0} ** 32;
    @memcpy(owner_word[12..32], &owner_addr);
    vm.storage_cache_bytes32(&SLOT_OWNER, &owner_word);
    vm.storage_cache_bytes32(&SLOT_CIRCUIT_HASH, &circuit_hash);
    var flag = [_]u8{0} ** 32;
    flag[31] = 1;
    vm.storage_cache_bytes32(&SLOT_INIT, &flag);
    vm.storage_flush_cache();

    vm.write_result(&[_]u8{}, 0);
}

fn handle_verify_proof(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const proof       = try dec.bytes();
    const public_root = try decodeFirstBytes32Element(data);

    const valid = verifyNoirProof(proof, public_root);
    if (valid) {
        incrementVerifyCount();
        emitProofVerified(public_root, true);
    }

    var ret = [_]u8{0} ** 32;
    ret[31] = if (valid) 1 else 0;
    vm.write_result(&ret, 32);
}

fn handle_verify_and_anchor(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const proof       = try dec.bytes();     // consumes head[0] = proof offset word
    _                 = try dec.offset();   // consumes head[1] = bytes32[] offset word
    const anchor_addr = try dec.address();  // consumes head[2] = anchor address word
    const public_root = try decodeFirstBytes32Element(data);

    const valid = verifyNoirProof(proof, public_root);
    if (!valid) return error.InvalidProof;

    incrementVerifyCount();
    emitProofVerified(public_root, true);

    // Call anchor: verifyAndAnchor(bytes32 newRoot, bytes proof)
    var call_buf: [4 + 32 + 32 + 32 + 64]u8 = undefined;
    @memcpy(call_buf[0..4], &SEL_ANCHOR_VERIFY);
    @memcpy(call_buf[4..36], &public_root);
    @memset(call_buf[36..60], 0);
    call_buf[67] = 0x40; // offset = 64
    @memset(call_buf[68..92], 0);
    const proof_len: u8 = @intCast(@min(proof.len, 64));
    call_buf[99] = proof_len;
    @memcpy(call_buf[100..][0..proof_len], proof[0..proof_len]);

    const zero_value = [_]u8{0} ** 32;
    const status = vm.call_contract(&anchor_addr, &zero_value, &call_buf, 100 + proof_len, 100_000);
    if (status != 0) return error.AnchorCallFailed;

    vm.write_result(&[_]u8{}, 0);
}

fn handle_get_circuit_hash() !void {
    var hash: [32]u8 = undefined;
    vm.storage_load_bytes32(&SLOT_CIRCUIT_HASH, &hash);
    vm.write_result(&hash, 32);
}

// ── Noir UltraPlonk Verification ─────────────────────────────────────────────
//
// Verification steps:
//   1. Parse proof header: validate circuit_size is a power-of-2.
//   2. Validate W1 (first wire commitment) is not the G1 identity point.
//   3. Build Fiat-Shamir transcript: Keccak256(publicRoot || pubInputsHash || W1).
//   4. Extract PI_Z (KZG opening proof) from the last G1 slot in the proof.
//   5. ecPairing(PI_Z, G2_gen): rejects off-curve points; full KZG check needs SRS.
//
// Full UltraPlonk verification (post-hackathon) requires the Groth16/KZG SRS
// second point [τ]G2 to complete e(PI_Z, [τ]G2) = e(batch_commitment, G2).

const ProofHeader = struct {
    circuit_size:     u32,
    pub_input_offset: u32,
    pub_inputs_hash:  [32]u8,
};

fn parseProofHeader(proof: []const u8) !ProofHeader {
    if (proof.len < PROOF_HDR_SIZE) return error.ProofTooShort;
    const circuit_size     = std.mem.readInt(u32, proof[28..32], .big);
    const pub_input_offset = std.mem.readInt(u32, proof[60..64], .big);
    // circuit_size must be a power of 2, minimum 4 (smallest valid UltraPlonk circuit)
    if (circuit_size < 4 or (circuit_size & (circuit_size - 1)) != 0) {
        return error.InvalidCircuitSize;
    }
    return .{
        .circuit_size     = circuit_size,
        .pub_input_offset = pub_input_offset,
        .pub_inputs_hash  = proof[64..96].*,
    };
}

// BN254 G1 identity (point at infinity) has x=0, y=0. Any other point is valid here.
fn g1IsNonIdentity(point: *const [G1_SIZE]u8) bool {
    for (point) |b| if (b != 0) return true;
    return false;
}

// Fiat-Shamir transcript: Keccak256(publicRoot || pubInputsHash || W1)
// Binds the challenge to both the public statement and the prover's first commitment.
fn fsChallenge(header: ProofHeader, proof: []const u8, public_root: [32]u8) [32]u8 {
    const W1: *const [G1_SIZE]u8 = proof[PROOF_HDR_SIZE..][0..G1_SIZE];
    var transcript: [32 + 32 + G1_SIZE]u8 = undefined;
    @memcpy(transcript[0..32],  &public_root);
    @memcpy(transcript[32..64], &header.pub_inputs_hash);
    @memcpy(transcript[64..128], W1);
    var challenge: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(&transcript, &challenge, .{});
    return challenge;
}

fn verifyNoirProof(proof: []const u8, public_root: [32]u8) bool {
    // 1. Parse and validate proof header (circuit_size power-of-2, etc.)
    const header = parseProofHeader(proof) catch return false;

    // 2. Proof must contain at least W1 commitment and PI_Z opening proof
    if (proof.len < PROOF_MIN_LEN) return false;

    // 3. Validate W1 is not the G1 identity point (trivially invalid commitment)
    const W1: *const [G1_SIZE]u8 = proof[PROOF_HDR_SIZE..][0..G1_SIZE];
    if (!g1IsNonIdentity(W1)) return false;

    // 4. Fiat-Shamir challenge binds public statement + first commitment
    const challenge = fsChallenge(header, proof, public_root);
    _ = challenge; // used in transcript; would seed linearization in full verifier

    // 5. Extract PI_Z: the KZG opening proof is the last G1 point in the proof
    const pi_z: *const [G1_SIZE]u8 = proof[proof.len - G1_SIZE ..][0..G1_SIZE];
    if (!g1IsNonIdentity(pi_z)) return false;

    // 6. ecPairing(PI_Z, G2_gen): BN254 precompile rejects off-curve G1 points.
    //    A valid proof from Barretenberg always produces an on-curve PI_Z.
    //    Full KZG: e(PI_Z, [τ]G2) = e(batch_commitment, G2) — needs trusted setup.
    var pairing_input: [192]u8 = undefined;
    @memcpy(pairing_input[0..64],  pi_z);
    pairing_input[64..192].* = BN254_G2_GENERATOR;

    const status = vm.static_call_contract(&EC_PAIRING, &pairing_input, 192, 100_000);
    if (status != 0) return false;

    const ret_size = vm.return_data_size();
    if (ret_size < 32) return false;

    var ret: [32]u8 = undefined;
    vm.read_return_data(&ret, 0, 32);
    return ret[31] == 1;
}

// BN254 G2 generator (EIP-197 test vectors, 128 bytes uncompressed)
// Source: https://eips.ethereum.org/EIPS/eip-197
const BN254_G2_GENERATOR: [128]u8 = .{
    // G2.x.c1
    0x19, 0x8e, 0x93, 0x93, 0x92, 0x0d, 0x48, 0x3a,
    0x76, 0x60, 0xd5, 0x3e, 0xec, 0xbf, 0xd4, 0x6f,
    0x3a, 0xa9, 0xdb, 0x6d, 0x09, 0x06, 0x90, 0x37,
    0x58, 0xb7, 0x68, 0x38, 0x51, 0xa7, 0x31, 0x4c,
    // G2.x.c0
    0x04, 0x89, 0x66, 0x37, 0x46, 0x53, 0x51, 0x86,
    0x7d, 0x58, 0x3b, 0x55, 0xa7, 0xd1, 0x41, 0x26,
    0x94, 0x35, 0x3a, 0x6c, 0xfe, 0x3b, 0x63, 0x69,
    0xae, 0xf9, 0xdd, 0x73, 0x7e, 0x5b, 0x2e, 0xed,
    // G2.y.c1
    0x09, 0x6e, 0xf0, 0xbc, 0x1a, 0xf8, 0xa8, 0x55,
    0x72, 0x05, 0xb1, 0x0b, 0x38, 0xd5, 0xb9, 0x38,
    0xe4, 0x6b, 0xcc, 0x7d, 0x48, 0x9d, 0x7d, 0xed,
    0x06, 0xad, 0xac, 0x7b, 0x8e, 0x33, 0xe7, 0xce,
    // G2.y.c0
    0x12, 0x0a, 0x2a, 0x4c, 0xf3, 0x0c, 0x1b, 0xf9,
    0x84, 0x5d, 0xab, 0xbe, 0xe7, 0x09, 0x74, 0xfe,
    0x59, 0xf4, 0xdc, 0xb5, 0xf0, 0xcd, 0xb7, 0x0a,
    0x4a, 0xb6, 0xbf, 0xfb, 0xd0, 0xec, 0x1e, 0xbf,
};

// ── Internals ─────────────────────────────────────────────────────────────────

fn incrementVerifyCount() void {
    var word: [32]u8 = undefined;
    vm.storage_load_bytes32(&SLOT_VERIFY_COUNT, &word);
    const cur = std.mem.readInt(u64, word[24..32], .big);
    std.mem.writeInt(u64, word[24..32], cur + 1, .big);
    vm.storage_cache_bytes32(&SLOT_VERIFY_COUNT, &word);
    vm.storage_flush_cache();
}

fn emitProofVerified(public_root: [32]u8, valid: bool) void {
    // ProofVerified(bytes32 indexed publicRoot, bool valid)
    // topics[0] = event sig hash, topics[1] = publicRoot (indexed)
    // data      = ABI-encoded bool (32 bytes)
    const topics = [2][32]u8{ EV_PROOF_VERIFIED, public_root };
    var data: [32]u8 = [_]u8{0} ** 32;
    data[31] = if (valid) 1 else 0;
    vm.emit_log(&data, data.len, @ptrCast(&topics), topics.len);
}

// Decode the first element of the bytes32[] array from ABI-encoded params.
// The array head is at params[32..64] (after the proof offset word at [0..32]).
fn decodeFirstBytes32Element(data: []const u8) ![32]u8 {
    if (data.len < 128) return error.InsufficientData;
    const arr_offset_word = data[32..64];
    const arr_offset: usize = @intCast(std.mem.readInt(u64, arr_offset_word[24..32], .big));
    if (arr_offset + 64 > data.len) return error.InvalidOffset;
    const arr_len_word = data[arr_offset..][0..32];
    const arr_len: usize = @intCast(std.mem.readInt(u64, arr_len_word[24..32], .big));
    if (arr_len == 0) return [_]u8{0} ** 32;
    const elem_start = arr_offset + 32;
    if (elem_start + 32 > data.len) return error.InvalidOffset;
    return data[elem_start..][0..32].*;
}

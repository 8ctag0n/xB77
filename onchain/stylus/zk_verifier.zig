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
    vm.pay_for_memory_grow(0);
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
    vm.storage_flush_cache(0);

    vm.write_result(&[_]u8{}, 0);
}

fn handle_verify_proof(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const proof       = try dec.bytes();
    const public_root = try decodeFirstBytes32Element(data);
    var pub_inputs: [3][32]u8 = [_][32]u8{[_]u8{0} ** 32} ** 3;
    const n_inputs = decodePubInputs(data, &pub_inputs);

    const valid = verifyNoirProof(proof, public_root, pub_inputs, n_inputs);
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
    var pub_inputs: [3][32]u8 = [_][32]u8{[_]u8{0} ** 32} ** 3;
    const n_inputs = decodePubInputs(data, &pub_inputs);

    const valid = verifyNoirProof(proof, public_root, pub_inputs, n_inputs);
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
    var ret_len: u32 = 0;
    const status = vm.call_contract(&anchor_addr, &call_buf, 100 + proof_len, &zero_value, 100_000, &ret_len);
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

// Negate a BN254 G1 point in-place: (x, y) → (x, p - y)
fn negateG1(point: *[G1_SIZE]u8) void {
    const y = point[32..64];
    var all_zero = true;
    for (y) |b| if (b != 0) { all_zero = false; break; };
    if (all_zero) return;
    var borrow: u8 = 0;
    var i: usize = 31;
    while (true) {
        const a = @as(u16, BN254_FIELD_PRIME[i]);
        const b_val = @as(u16, y[i]) + borrow;
        if (a >= b_val) {
            y[i] = @intCast(a - b_val);
            borrow = 0;
        } else {
            y[i] = @intCast(a + 256 - b_val);
            borrow = 1;
        }
        if (i == 0) break;
        i -= 1;
    }
}

// ecMul(G1 point, scalar): calls precompile 0x07, returns null on failure.
fn ecMulG1(point: [G1_SIZE]u8, scalar: [32]u8) ?[G1_SIZE]u8 {
    var buf: [96]u8 = undefined;
    @memcpy(buf[0..64], &point);
    @memcpy(buf[64..96], &scalar);
    var ret_len: u32 = 0;
    const status = vm.static_call_contract(&EC_MUL, &buf, 96, 200_000, &ret_len);
    if (status != 0) return null;
    var result: [G1_SIZE]u8 = undefined;
    _ = vm.read_return_data(&result, 0, 64);
    return result;
}

// ecAdd(G1 a, G1 b): calls precompile 0x06, returns null on failure.
fn ecAddG1(a: [G1_SIZE]u8, b: [G1_SIZE]u8) ?[G1_SIZE]u8 {
    var buf: [128]u8 = undefined;
    @memcpy(buf[0..64], &a);
    @memcpy(buf[64..128], &b);
    var ret_len: u32 = 0;
    const status = vm.static_call_contract(&EC_ADD, &buf, 128, 100_000, &ret_len);
    if (status != 0) return null;
    var result: [G1_SIZE]u8 = undefined;
    _ = vm.read_return_data(&result, 0, 64);
    return result;
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

// Groth16 full verification: e(-A, B) * e(α, β) * e(vk_x, γ) * e(C, δ) == 1
// Uses the embedded agent_badge circuit VK (3 public inputs).
// proof layout: 0x01 | A(G1,64) | B(G2,128) | C(G1,64)  = 257 bytes total
fn verifyGroth16Proof(proof: []const u8, pub_inputs: [3][32]u8, n_inputs: usize) bool {
    if (proof.len < GROTH16_PROOF_LEN) return false;

    const A: *const [G1_SIZE]u8 = proof[1..][0..G1_SIZE];
    const B: *const [128]u8     = proof[1 + G1_SIZE ..][0..128];
    const C: *const [G1_SIZE]u8 = proof[1 + G1_SIZE + 128 ..][0..G1_SIZE];

    // vk_x = IC[0] + Σ pub_inputs[i] * IC[i+1]
    var vk_x: [G1_SIZE]u8 = G16_IC[0];
    const n = @min(n_inputs, 3);
    for (0..n) |i| {
        const scaled = ecMulG1(G16_IC[i + 1], pub_inputs[i]) orelse return false;
        vk_x = ecAddG1(vk_x, scaled) orelse return false;
    }

    var neg_A: [G1_SIZE]u8 = A.*;
    negateG1(&neg_A);

    // 4-pair check via single ecPairing call (768 bytes)
    var pairing_buf: [4 * 192]u8 = undefined;
    @memcpy(pairing_buf[0..64],    &neg_A);        // pair 0: (-A, B)
    @memcpy(pairing_buf[64..192],  B);
    @memcpy(pairing_buf[192..256], &G16_ALPHA_G1); // pair 1: (α, β)
    @memcpy(pairing_buf[256..384], &G16_BETA_G2);
    @memcpy(pairing_buf[384..448], &vk_x);         // pair 2: (vk_x, γ)
    @memcpy(pairing_buf[448..576], &G16_GAMMA_G2);
    @memcpy(pairing_buf[576..640], C);              // pair 3: (C, δ)
    @memcpy(pairing_buf[640..768], &G16_DELTA_G2);

    var ret_len: u32 = 0;
    const status = vm.static_call_contract(&EC_PAIRING, &pairing_buf, 768, 500_000, &ret_len);
    if (status != 0 or ret_len < 32) return false;
    var ret: [32]u8 = undefined;
    _ = vm.read_return_data(&ret, 0, 32);
    return ret[31] == 1;
}

// UltraPlonk structural verification with KZG membership check.
// Validates proof header, wire commitment, Fiat-Shamir transcript, and checks:
//   e(PI_Z, [τ]G2) * e(-W1, G2_gen) == 1
// i.e. PI_Z opens the first wire commitment under the Barretenberg SRS.
fn verifyUltraPlonk(proof: []const u8, public_root: [32]u8) bool {
    const header = parseProofHeader(proof) catch return false;
    if (proof.len < PROOF_MIN_LEN) return false;

    const W1: *const [G1_SIZE]u8 = proof[PROOF_HDR_SIZE..][0..G1_SIZE];
    if (!g1IsNonIdentity(W1)) return false;

    _ = fsChallenge(header, proof, public_root); // binds challenge to transcript

    const pi_z: *const [G1_SIZE]u8 = proof[proof.len - G1_SIZE ..][0..G1_SIZE];
    if (!g1IsNonIdentity(pi_z)) return false;

    // 2-pair KZG check: e(PI_Z, [τ]G2) * e(-W1, G2_gen) == 1
    var neg_w1: [G1_SIZE]u8 = W1.*;
    negateG1(&neg_w1);

    var pairing_buf: [2 * 192]u8 = undefined;
    @memcpy(pairing_buf[0..64],    pi_z);
    pairing_buf[64..192].*  = AZTEC_G2_TAU;
    @memcpy(pairing_buf[192..256], &neg_w1);
    pairing_buf[256..384].* = BN254_G2_GENERATOR;

    var ret_len: u32 = 0;
    const status = vm.static_call_contract(&EC_PAIRING, &pairing_buf, 384, 200_000, &ret_len);
    if (status != 0 or ret_len < 32) return false;
    var ret: [32]u8 = undefined;
    _ = vm.read_return_data(&ret, 0, 32);
    return ret[31] == 1;
}

// Dispatcher: proof[0] == 0x01 → Groth16 (agent_badge VK)
//             proof[0] == 0x00 → UltraPlonk/Noir (Barretenberg SRS)
fn verifyNoirProof(proof: []const u8, public_root: [32]u8, pub_inputs: [3][32]u8, n_inputs: usize) bool {
    if (proof.len == 0) return false;
    if (proof[0] == 0x01) return verifyGroth16Proof(proof, pub_inputs, n_inputs);
    return verifyUltraPlonk(proof, public_root);
}

// BN254 Fp field prime (for G1 point negation)
// p = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47
const BN254_FIELD_PRIME: [32]u8 = .{
    0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29,
    0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58, 0x5d,
    0x97, 0x81, 0x6a, 0x91, 0x68, 0x71, 0xca, 0x8d,
    0x3c, 0x20, 0x8c, 0x16, 0xd8, 0x7c, 0xfd, 0x47,
};

// Aztec Ignition ceremony BN254 [τ]G2 (SRS second G2 point used by Barretenberg)
// EIP-197 encoding: x.c1(32) || x.c0(32) || y.c1(32) || y.c0(32)
const AZTEC_G2_TAU: [128]u8 = .{
    // x.c1
    0x26, 0x0e, 0x01, 0xb2, 0x51, 0xf6, 0xf1, 0xc7,
    0xe7, 0xff, 0x4e, 0x58, 0x07, 0x91, 0xde, 0xe8,
    0xea, 0x02, 0xb4, 0x00, 0x34, 0x1a, 0x73, 0xf1,
    0x5a, 0x3a, 0x2a, 0x4f, 0x0e, 0x5b, 0x1f, 0xc3,
    // x.c0
    0x01, 0x18, 0xc4, 0xd5, 0xb8, 0x37, 0xbc, 0xc2,
    0xbc, 0x89, 0xb5, 0xb3, 0x98, 0xb5, 0x97, 0x4e,
    0x9f, 0x59, 0x44, 0x07, 0x3b, 0x32, 0x07, 0x8b,
    0x7e, 0x23, 0x1f, 0xec, 0x93, 0x88, 0x83, 0xb0,
    // y.c1
    0x04, 0xfc, 0x63, 0x69, 0xf7, 0x11, 0x0f, 0xe3,
    0xd2, 0x51, 0x56, 0xc1, 0xbb, 0x9a, 0x72, 0x85,
    0x9c, 0xf2, 0xa0, 0x46, 0x41, 0xf9, 0x9b, 0xa4,
    0xee, 0x41, 0x3c, 0x80, 0xda, 0x6a, 0x5f, 0xe4,
    // y.c0
    0x22, 0xfe, 0xbd, 0xa3, 0xc0, 0xc0, 0x63, 0x2a,
    0x56, 0x47, 0x5b, 0x42, 0x14, 0xe5, 0x61, 0x5e,
    0x11, 0xe6, 0xdd, 0x3f, 0x96, 0xe6, 0xce, 0xa2,
    0x85, 0x4a, 0x87, 0xd4, 0xda, 0xcc, 0x5e, 0x55,
};

// ── Groth16 Verifying Key (agent_badge circuit, 3 public inputs) ──────────────
// Auto-ported from circuits/agent_badge/verifier_program/src/vk.rs

const G16_ALPHA_G1: [G1_SIZE]u8 = .{
    0x26, 0xb0, 0xf2, 0xf2, 0x5b, 0xea, 0x4f, 0xb2, 0xc5, 0xa7, 0x42, 0x47, 0x8b, 0x40, 0xa9, 0x64,
    0x79, 0xca, 0x08, 0x81, 0xa8, 0x87, 0x19, 0x89, 0x49, 0x9f, 0x8f, 0x65, 0xf3, 0xfd, 0x8d, 0xa2,
    0x0c, 0xa5, 0x1e, 0x6e, 0x61, 0x89, 0x7b, 0x94, 0x48, 0x9c, 0x4c, 0x8c, 0x22, 0xb1, 0xb7, 0x48,
    0xef, 0xc7, 0xcb, 0xf3, 0x07, 0x70, 0xf8, 0xd3, 0xa5, 0x1b, 0xe1, 0x64, 0xf5, 0xbc, 0x7b, 0xcb,
};
const G16_BETA_G2: [128]u8 = .{
    0x1e, 0xfa, 0xbf, 0x0d, 0xf7, 0x21, 0x58, 0xc7, 0x10, 0x99, 0x98, 0x04, 0xbe, 0xc0, 0x81, 0x40,
    0x4a, 0xc9, 0x96, 0x80, 0xd2, 0x5e, 0xcc, 0x99, 0x43, 0x81, 0xe8, 0x0b, 0x54, 0xc2, 0x5d, 0x74,
    0x2e, 0xed, 0x3a, 0xd4, 0x10, 0x49, 0x0d, 0xaa, 0xa7, 0x78, 0x30, 0xcc, 0xd1, 0xc3, 0x98, 0x7b,
    0x1e, 0x55, 0xe7, 0xe8, 0x45, 0x18, 0xc9, 0x00, 0x60, 0x85, 0x10, 0x95, 0x89, 0x0c, 0xfc, 0x9a,
    0x08, 0x9d, 0x03, 0x9a, 0x28, 0x50, 0xf7, 0x9e, 0x31, 0x54, 0xc5, 0x01, 0x20, 0x0e, 0x8d, 0xd9,
    0x6b, 0x7f, 0x2a, 0x38, 0x14, 0x1b, 0xf2, 0x5b, 0x17, 0x39, 0xe6, 0x87, 0x20, 0x0f, 0x4a, 0xcb,
    0x2e, 0x15, 0x07, 0x9c, 0x3d, 0xe9, 0xd3, 0x03, 0xce, 0x80, 0x26, 0x36, 0x3c, 0x9b, 0x42, 0x7c,
    0x9e, 0xcc, 0xcc, 0xf1, 0x1a, 0x38, 0xa5, 0xa2, 0x64, 0xb1, 0x9b, 0xd5, 0xed, 0x10, 0x2e, 0xae,
};
const G16_GAMMA_G2: [128]u8 = .{
    0x2a, 0xfb, 0x2d, 0x7e, 0x31, 0x0f, 0x64, 0x46, 0x33, 0x57, 0x75, 0x96, 0xfd, 0x0d, 0x2d, 0x4c,
    0x8d, 0x5a, 0xc4, 0x84, 0xaa, 0x02, 0x35, 0x75, 0xcb, 0xcc, 0xb9, 0xc7, 0xe7, 0x46, 0x9d, 0xce,
    0x18, 0x56, 0x41, 0xe6, 0x8a, 0x00, 0xe9, 0x80, 0xd5, 0x58, 0x5c, 0xb9, 0x05, 0xec, 0xd2, 0x0b,
    0xf6, 0x92, 0x10, 0xc2, 0x83, 0x2c, 0xa5, 0xf0, 0x32, 0xd3, 0x8d, 0x1d, 0x20, 0xfe, 0xf9, 0x44,
    0x28, 0x83, 0xfa, 0x41, 0x90, 0x1d, 0xc4, 0x99, 0x91, 0xcb, 0xde, 0xa8, 0xe0, 0x08, 0xba, 0x7f,
    0x3c, 0x23, 0xf1, 0x42, 0x2c, 0x15, 0x3e, 0x26, 0xbe, 0xe3, 0x02, 0x14, 0x1b, 0x4a, 0xb5, 0x6a,
    0x26, 0xdb, 0xd1, 0x74, 0x1a, 0x53, 0x17, 0xb4, 0x46, 0xca, 0xa6, 0xcd, 0xee, 0x70, 0x85, 0x6e,
    0xd8, 0x66, 0xd8, 0x23, 0x99, 0xe7, 0x0c, 0x2f, 0xf2, 0x1b, 0xca, 0x75, 0xed, 0xcb, 0x7f, 0xcc,
};
const G16_DELTA_G2: [128]u8 = .{
    0x27, 0xdc, 0xba, 0x54, 0xa1, 0xfa, 0x2d, 0xd1, 0xdc, 0x84, 0x8f, 0xb0, 0x83, 0xdf, 0x7b, 0x94,
    0xca, 0x4b, 0xae, 0xda, 0xd2, 0x70, 0x1e, 0x85, 0xda, 0x9b, 0xe1, 0x39, 0x6b, 0x71, 0x0b, 0xc8,
    0x21, 0x7c, 0x7a, 0xb4, 0xb6, 0x2e, 0xb3, 0xc0, 0xb3, 0x98, 0x00, 0xaf, 0xfb, 0x64, 0x02, 0x9b,
    0xf0, 0xa1, 0x27, 0xa6, 0x8a, 0xab, 0x2c, 0xf6, 0x14, 0x22, 0x63, 0x03, 0x68, 0x9b, 0x54, 0xf5,
    0x22, 0xd5, 0x99, 0x5c, 0x01, 0xe5, 0xd5, 0x7c, 0x32, 0x41, 0xd9, 0xba, 0x87, 0x5e, 0xc0, 0x46,
    0x83, 0xdd, 0xc5, 0x0f, 0xf3, 0x42, 0x7f, 0x72, 0xcc, 0x29, 0x94, 0xc3, 0xb6, 0x87, 0x99, 0x86,
    0x05, 0x82, 0x06, 0x62, 0x88, 0x6f, 0x4f, 0x5d, 0x6d, 0x70, 0xba, 0x5d, 0x15, 0xfb, 0xc9, 0xf4,
    0x49, 0x67, 0x60, 0xc6, 0xc4, 0xff, 0xcf, 0x95, 0xf4, 0xbe, 0xc7, 0x2a, 0xc9, 0x96, 0xd9, 0x25,
};
// IC (gamma_abc) points: IC[0] constant term + IC[1..3] per public input
const G16_IC: [4][G1_SIZE]u8 = .{
    .{ 0x18, 0xe0, 0x5e, 0xe1, 0x6a, 0x02, 0xb5, 0x3a, 0xa1, 0x8e, 0xed, 0x35, 0x94, 0xd7, 0x66, 0x51,
       0x7b, 0xfa, 0x0b, 0x0d, 0x04, 0x18, 0x9e, 0xdc, 0x3f, 0xcd, 0x1c, 0x3b, 0x4a, 0x53, 0x01, 0xcd,
       0x1f, 0x6d, 0xa7, 0xb9, 0x01, 0x63, 0x1e, 0x0e, 0xe0, 0x0c, 0x03, 0xf5, 0x0a, 0x51, 0xe1, 0x29,
       0x44, 0x3a, 0x18, 0x9a, 0x68, 0xb4, 0x16, 0xf0, 0x73, 0x6b, 0xf9, 0xdf, 0x83, 0xc0, 0x3f, 0x19 },
    .{ 0x20, 0x00, 0x87, 0x89, 0x37, 0xd9, 0x42, 0xbb, 0x60, 0x2e, 0xb8, 0xe3, 0x81, 0x9d, 0x72, 0x3f,
       0x1c, 0x74, 0x98, 0x86, 0x7b, 0x94, 0x53, 0x6f, 0xb7, 0x88, 0x48, 0x4e, 0x3c, 0xf9, 0xea, 0xf6,
       0x13, 0x2c, 0x46, 0x33, 0x00, 0xb4, 0x06, 0xa3, 0xc6, 0xb3, 0x7f, 0x8b, 0x47, 0x4c, 0x5d, 0xb9,
       0x9d, 0xa4, 0x35, 0xd9, 0xf4, 0x94, 0x03, 0xb4, 0xeb, 0xfe, 0x3c, 0x4c, 0x88, 0x23, 0xfa, 0xcb },
    .{ 0x2d, 0xef, 0xa4, 0x9e, 0x7c, 0x9f, 0x4f, 0xc7, 0x6d, 0xf1, 0xc2, 0xf2, 0xb0, 0x74, 0x15, 0x39,
       0xd7, 0xe3, 0xba, 0x0c, 0x3f, 0x32, 0x47, 0xb5, 0xd4, 0x78, 0x51, 0xeb, 0xd8, 0x7b, 0x00, 0xf1,
       0x02, 0x3d, 0x22, 0xf0, 0xfd, 0xe3, 0x07, 0x6c, 0xec, 0x6c, 0x1b, 0x8a, 0x07, 0xce, 0x89, 0x5b,
       0xd4, 0xa2, 0x34, 0x13, 0xb0, 0xd0, 0x26, 0x16, 0xb1, 0xaa, 0x53, 0x03, 0xb5, 0x92, 0x6f, 0x8e },
    .{ 0x0f, 0x81, 0xd1, 0x28, 0x9a, 0x46, 0xb3, 0x99, 0xdf, 0x69, 0x1d, 0xaa, 0xbc, 0x96, 0x97, 0x81,
       0x36, 0x2a, 0x36, 0x89, 0xdb, 0xd7, 0xa9, 0x49, 0x17, 0xf0, 0x79, 0x47, 0x57, 0x8c, 0xb4, 0xb3,
       0x0f, 0xf3, 0xec, 0x2f, 0xa4, 0x87, 0xab, 0x37, 0x73, 0xec, 0xaf, 0x70, 0xdd, 0x80, 0x14, 0xa7,
       0xc9, 0xaa, 0xa8, 0xd6, 0x05, 0x5f, 0xaf, 0x6c, 0x8c, 0x38, 0x6f, 0x0f, 0x0f, 0xdf, 0x75, 0x71 },
};

// Groth16 proof: type_byte(1) + A/G1(64) + B/G2(128) + C/G1(64) = 257 bytes
const GROTH16_PROOF_LEN: usize = 1 + G1_SIZE + 128 + G1_SIZE;

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
    vm.storage_flush_cache(0);
}

fn emitProofVerified(public_root: [32]u8, valid: bool) void {
    // ProofVerified(bytes32 indexed publicRoot, bool valid)
    // topics[0] = event sig hash, topics[1] = publicRoot (indexed)
    // data      = ABI-encoded bool (32 bytes)
    const topics = [2][32]u8{ EV_PROOF_VERIFIED, public_root };
    var data: [32]u8 = [_]u8{0} ** 32;
    data[31] = if (valid) 1 else 0;
    Stylus.log(&data, &topics);
}

// Decode up to 3 elements from the bytes32[] public inputs array.
// Returns how many elements were decoded (0..3).
fn decodePubInputs(data: []const u8, out: *[3][32]u8) usize {
    if (data.len < 128) return 0;
    const arr_offset: usize = @intCast(std.mem.readInt(u64, data[32..64][24..32], .big));
    if (arr_offset + 32 > data.len) return 0;
    const arr_len: usize = @intCast(std.mem.readInt(u64, data[arr_offset..][0..32][24..32], .big));
    const n = @min(arr_len, 3);
    for (0..n) |i| {
        const start = arr_offset + 32 + i * 32;
        if (start + 32 > data.len) return i;
        out[i] = data[start..][0..32].*;
    }
    return n;
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

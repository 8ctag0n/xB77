//! xB77 VerifierRegistry — Stylus WASM contract (Zig)
//!
//! Multi-circuit ZK proof registry with EigenLayer AVS hooks.
//! Routes verification to the registered verifier contract per circuit,
//! emitting protocol-compatible events for EigenLayer operators.
//!
//! Architecture: each proof type maps to a deployed verifier contract address.
//! The registry calls verifier.verifyProof(proof, publicInputs) via static_call,
//! then emits events for AVS monitoring without holding verification logic itself.
//!
//! ABI:
//!   initialize(address owner, address groth16Verifier, address ultraplonkVerifier)
//!   registerCircuit(bytes32 circuitId, uint8 proofType, bytes32 vkHash)
//!   setVerifierAddress(uint8 proofType, address verifier)
//!   verify(bytes32 circuitId, bytes proof, bytes32[] publicInputs) returns (bool)
//!   verifyForAVS(bytes32 circuitId, bytes proof, bytes32[] publicInputs, bytes32 taskId) returns (bool)
//!   getCircuit(bytes32 circuitId) returns (uint8 proofType, bytes32 vkHash, bool registered)
//!   getVerifier(uint8 proofType) returns (address)
//!
//! Proof types:
//!   0x01 — Groth16  (BN254, agent_badge VK embedded in xb77_zk_verifier)
//!   0x02 — UltraPlonk / Noir  (Barretenberg BN254 SRS)
//!   0x03 — SP1 (Succinct universal Groth16 wrapper)
//!
//! Events (EigenLayer-compatible):
//!   ProofVerified(bytes32 indexed circuitId, bytes32 indexed publicRoot, bool valid)
//!   AVSTaskCompleted(bytes32 indexed taskId, bytes32 indexed circuitId, address indexed operator, bool valid)
//!   CircuitRegistered(bytes32 indexed circuitId, uint8 proofType)
//!   VerifierSet(uint8 indexed proofType, address verifier)

const std = @import("std");
const sdk = @import("sdk.zig");
const abi = @import("abi.zig");

const vm     = sdk.vm_hooks;
const Stylus = sdk.Stylus;

// ── Selectors ────────────────────────────────────────────────────────────────

const SEL_INITIALIZE         = abi.selector("initialize(address,address,address)");
const SEL_REGISTER_CIRCUIT   = abi.selector("registerCircuit(bytes32,uint8,bytes32)");
const SEL_SET_VERIFIER        = abi.selector("setVerifierAddress(uint8,address)");
const SEL_VERIFY             = abi.selector("verify(bytes32,bytes,bytes32[])");
const SEL_VERIFY_FOR_AVS     = abi.selector("verifyForAVS(bytes32,bytes,bytes32[],bytes32)");
const SEL_GET_CIRCUIT        = abi.selector("getCircuit(bytes32)");
const SEL_GET_VERIFIER       = abi.selector("getVerifier(uint8)");

// Downstream verifier: verifyProof(bytes,bytes32[]) → bool
const SEL_VERIFY_PROOF = abi.selector("verifyProof(bytes,bytes32[])");

// ── Event topics ──────────────────────────────────────────────────────────────

const EV_PROOF_VERIFIED: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("ProofVerified(bytes32,bytes32,bool)", &h, .{});
    break :blk h;
};

const EV_AVS_TASK_COMPLETED: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("AVSTaskCompleted(bytes32,bytes32,address,bool)", &h, .{});
    break :blk h;
};

const EV_CIRCUIT_REGISTERED: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("CircuitRegistered(bytes32,uint8)", &h, .{});
    break :blk h;
};

const EV_VERIFIER_SET: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("VerifierSet(uint8,address)", &h, .{});
    break :blk h;
};

// ── Storage slots ─────────────────────────────────────────────────────────────

const SLOT_OWNER:           [32]u8 = fixedSlot(0);
const SLOT_INIT:            [32]u8 = fixedSlot(1);
// Verifier addresses by proof type: slot 0x10 + proof_type
fn verifierSlot(proof_type: u8) [32]u8 {
    var s = [_]u8{0} ** 32;
    s[30] = 0x10;
    s[31] = proof_type;
    return s;
}
// Per-circuit: deterministic slots from circuit_id XOR namespace
fn circuitTypeSlot(cid: [32]u8) [32]u8 { return circuitSlot(cid, 0xA0); }
fn circuitVkSlot(cid: [32]u8)   [32]u8 { return circuitSlot(cid, 0xA1); }
fn circuitRegSlot(cid: [32]u8)  [32]u8 { return circuitSlot(cid, 0xA2); }

fn circuitSlot(cid: [32]u8, ns: u8) [32]u8 {
    var pre: [33]u8 = undefined;
    @memcpy(pre[0..32], &cid);
    pre[32] = ns;
    var h: [32]u8 = undefined;
    vm.native_keccak256(&pre, 33, &h);
    return h;
}

fn fixedSlot(n: u8) [32]u8 {
    var s = [_]u8{0} ** 32;
    s[31] = n;
    return s;
}

// ── Proof type constants ──────────────────────────────────────────────────────

const PT_GROTH16:    u8 = 0x01;
const PT_ULTRAPLONK: u8 = 0x02;
const PT_SP1:        u8 = 0x03;

// ── Pre-registered xB77 circuit IDs (keccak256 of canonical name) ────────────

const CID_AGENT_BADGE: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("xb77.circuit.agent_badge", &h, .{});
    break :blk h;
};
const CID_STATE_ANCHOR: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("xb77.circuit.state_anchor", &h, .{});
    break :blk h;
};
const CID_ZK_RECEIPT: [32]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var h: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash("xb77.circuit.zk_receipt", &h, .{});
    break :blk h;
};

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

    if (std.mem.eql(u8, &sel, &SEL_INITIALIZE))       return handleInitialize(params);
    if (std.mem.eql(u8, &sel, &SEL_REGISTER_CIRCUIT)) return handleRegisterCircuit(params);
    if (std.mem.eql(u8, &sel, &SEL_SET_VERIFIER))     return handleSetVerifier(params);
    if (std.mem.eql(u8, &sel, &SEL_VERIFY))           return handleVerify(params);
    if (std.mem.eql(u8, &sel, &SEL_VERIFY_FOR_AVS))   return handleVerifyForAVS(params);
    if (std.mem.eql(u8, &sel, &SEL_GET_CIRCUIT))      return handleGetCircuit(params);
    if (std.mem.eql(u8, &sel, &SEL_GET_VERIFIER))     return handleGetVerifier(params);

    return error.UnknownSelector;
}

// ── Handlers ──────────────────────────────────────────────────────────────────

fn handleInitialize(data: []const u8) !void {
    var init_flag: [32]u8 = undefined;
    vm.storage_load_bytes32(&SLOT_INIT, &init_flag);
    if (init_flag[31] != 0) return error.AlreadyInitialized;
    if (data.len < 96) return error.InvalidCalldata;

    // owner, groth16Verifier, ultraplonkVerifier — each packed in 32-byte word
    var owner_word = [_]u8{0} ** 32;
    @memcpy(owner_word[12..32], data[12..32]);
    vm.storage_cache_bytes32(&SLOT_OWNER, &owner_word);

    storeVerifier(PT_GROTH16,    data[32..52].*);
    storeVerifier(PT_ULTRAPLONK, data[64..84].*);
    // SP1 shares the Groth16 verifier (same proof format, different VK via circuit_id)
    storeVerifier(PT_SP1, data[32..52].*);

    var flag: [32]u8 = [_]u8{0} ** 32;
    flag[31] = 1;
    vm.storage_cache_bytes32(&SLOT_INIT, &flag);
    vm.storage_flush_cache(0);

    // Pre-register xB77 circuits
    saveCircuit(CID_AGENT_BADGE,  PT_GROTH16,    [_]u8{0xA1} ** 32);
    saveCircuit(CID_STATE_ANCHOR, PT_ULTRAPLONK, [_]u8{0xA2} ** 32);
    saveCircuit(CID_ZK_RECEIPT,   PT_ULTRAPLONK, [_]u8{0xA3} ** 32);

    vm.write_result(&[_]u8{}, 0);
}

fn handleSetVerifier(data: []const u8) !void {
    try requireOwner();
    if (data.len < 64) return error.InvalidCalldata;
    const proof_type: u8 = data[31]; // last byte of uint8 word
    const verifier_addr  = data[44..64].*;  // address packed in second 32-byte word

    storeVerifier(proof_type, verifier_addr);

    var event_data: [64]u8 = [_]u8{0} ** 64;
    event_data[31] = proof_type;
    @memcpy(event_data[44..64], &verifier_addr);
    var type_word: [32]u8 = [_]u8{0} ** 32;
    type_word[31] = proof_type;
    const topics = [2][32]u8{ EV_VERIFIER_SET, type_word };
    Stylus.log(&event_data, &topics);
    vm.write_result(&[_]u8{}, 0);
}

fn handleRegisterCircuit(data: []const u8) !void {
    try requireOwner();
    if (data.len < 96) return error.InvalidCalldata;
    const circuit_id = data[0..32].*;
    const proof_type: u8 = data[63];
    const vk_hash    = data[64..96].*;
    saveCircuit(circuit_id, proof_type, vk_hash);

    var event_data: [32]u8 = [_]u8{0} ** 32;
    event_data[31] = proof_type;
    const topics = [2][32]u8{ EV_CIRCUIT_REGISTERED, circuit_id };
    Stylus.log(&event_data, &topics);
    vm.write_result(&[_]u8{}, 0);
}

fn handleVerify(data: []const u8) !void {
    const result = try doVerify(data, null);
    var ret = [_]u8{0} ** 32;
    ret[31] = if (result.valid) 1 else 0;
    vm.write_result(&ret, 32);
}

fn handleVerifyForAVS(data: []const u8) !void {
    // Last 32 bytes of params = taskId (appended after the standard verify args)
    if (data.len < 32) return error.InvalidCalldata;
    const task_id = data[data.len - 32 ..][0..32].*;

    const result = try doVerify(data, &task_id);

    // AVSTaskCompleted(bytes32 indexed taskId, bytes32 indexed circuitId, address indexed operator, bool valid)
    var sender: [20]u8 = undefined;
    vm.msg_sender(&sender);
    var operator_word: [32]u8 = [_]u8{0} ** 32;
    @memcpy(operator_word[12..32], &sender);
    var event_data: [64]u8 = [_]u8{0} ** 64;
    @memcpy(event_data[0..32], &operator_word);
    event_data[63] = if (result.valid) 1 else 0;
    const topics = [3][32]u8{ EV_AVS_TASK_COMPLETED, task_id, result.circuit_id };
    Stylus.log(&event_data, &topics);

    var ret = [_]u8{0} ** 32;
    ret[31] = if (result.valid) 1 else 0;
    vm.write_result(&ret, 32);
}

fn handleGetCircuit(data: []const u8) !void {
    if (data.len < 32) return error.InvalidCalldata;
    const cid = data[0..32].*;
    var tw: [32]u8 = undefined;
    var vk: [32]u8 = undefined;
    var rw: [32]u8 = undefined;
    vm.storage_load_bytes32(&circuitTypeSlot(cid), &tw);
    vm.storage_load_bytes32(&circuitVkSlot(cid),   &vk);
    vm.storage_load_bytes32(&circuitRegSlot(cid),  &rw);
    var ret: [96]u8 = [_]u8{0} ** 96;
    ret[31] = tw[0];
    @memcpy(ret[32..64], &vk);
    ret[95] = rw[31];
    vm.write_result(&ret, 96);
}

fn handleGetVerifier(data: []const u8) !void {
    if (data.len < 32) return error.InvalidCalldata;
    const proof_type: u8 = data[31];
    var addr: [20]u8 = loadVerifier(proof_type);
    var ret: [32]u8 = [_]u8{0} ** 32;
    @memcpy(ret[12..32], &addr);
    vm.write_result(&ret, 32);
}

// ── Core verification via cross-contract call ─────────────────────────────────

const VerifyResult = struct { valid: bool, circuit_id: [32]u8, public_root: [32]u8 };

fn doVerify(data: []const u8, task_id: ?*const [32]u8) !VerifyResult {
    _ = task_id; // task_id logged by caller after this returns
    if (data.len < 96) return error.InvalidCalldata;

    const circuit_id = data[0..32].*;

    // Check registered
    var rw: [32]u8 = undefined;
    vm.storage_load_bytes32(&circuitRegSlot(circuit_id), &rw);
    if (rw[31] == 0) return .{ .valid = false, .circuit_id = circuit_id, .public_root = [_]u8{0} ** 32 };

    // Load proof type → verifier address
    var tw: [32]u8 = undefined;
    vm.storage_load_bytes32(&circuitTypeSlot(circuit_id), &tw);
    const proof_type = tw[0];
    const verifier_addr = loadVerifier(proof_type);

    // Decode proof bytes from ABI params (head at data[32..64])
    const proof_offset: usize = @intCast(std.mem.readInt(u64, data[32..64][24..32], .big));
    if (proof_offset + 32 > data.len) return error.InvalidCalldata;
    const proof_len: usize = @intCast(std.mem.readInt(u64, data[proof_offset..][0..32][24..32], .big));
    if (proof_offset + 32 + proof_len > data.len) return error.InvalidCalldata;
    const proof = data[proof_offset + 32 ..][0..proof_len];

    // Extract first public input as the public_root for event
    var public_root = [_]u8{0} ** 32;
    const arr_offset: usize = @intCast(std.mem.readInt(u64, data[64..96][24..32], .big));
    if (arr_offset + 64 <= data.len) {
        const arr_len: usize = @intCast(std.mem.readInt(u64, data[arr_offset..][0..32][24..32], .big));
        if (arr_len > 0 and arr_offset + 64 <= data.len) {
            public_root = data[arr_offset + 32 ..][0..32].*;
        }
    }

    // Forward: verifyProof(bytes proof, bytes32[] publicInputs)
    // Re-encode the call: sel(4) + proof_offset(32) + arr_offset(32) + proof_tail + arr_tail
    var call_buf: [8192]u8 = undefined;
    @memcpy(call_buf[0..4], &SEL_VERIFY_PROOF);
    const call_len = buildVerifyProofCall(call_buf[4..], proof, data, arr_offset);

    var ret_len: u32 = 0;
    const status = vm.static_call_contract(&verifier_addr, &call_buf, 4 + call_len, 500_000, &ret_len);
    var valid = false;
    if (status == 0 and ret_len >= 32) {
        var ret: [32]u8 = undefined;
        _ = vm.read_return_data(&ret, 0, 32);
        valid = ret[31] == 1;
    }

    if (valid) {
        const topics = [2][32]u8{ EV_PROOF_VERIFIED, circuit_id };
        var event_data: [64]u8 = [_]u8{0} ** 64;
        @memcpy(event_data[0..32], &public_root);
        event_data[63] = 1;
        Stylus.log(&event_data, &topics);
    }

    return .{ .valid = valid, .circuit_id = circuit_id, .public_root = public_root };
}

// Re-encode verifyProof(bytes proof, bytes32[] publicInputs) calldata.
// Returns the byte length written into buf (selector is prepended by caller).
fn buildVerifyProofCall(buf: []u8, proof: []const u8, orig_data: []const u8, arr_offset: usize) usize {
    @memset(buf[0..@min(buf.len, 4096)], 0);

    const proof_padded = ((proof.len + 31) / 32) * 32;
    const head_proof_off: usize = 64;           // 2 head words
    const head_arr_off:   usize = 64 + 32 + proof_padded;

    std.mem.writeInt(u256, buf[0..32][0..32],  head_proof_off, .big);
    std.mem.writeInt(u256, buf[32..64][0..32], head_arr_off,   .big);
    std.mem.writeInt(u256, buf[64..96][0..32], proof.len,      .big);
    @memcpy(buf[96..][0..proof.len], proof);

    // Copy array section from original calldata
    const arr_data_start = arr_offset;
    const arr_data_end   = @min(orig_data.len, arr_offset + 32 + 3 * 32 + 32);
    const arr_copy_len   = if (arr_data_end > arr_data_start) arr_data_end - arr_data_start else 0;
    const out_arr = 64 + 32 + proof_padded;
    if (arr_copy_len > 0 and out_arr + arr_copy_len <= buf.len) {
        @memcpy(buf[out_arr..][0..arr_copy_len], orig_data[arr_data_start..arr_data_end]);
    }

    return out_arr + @max(arr_copy_len, 64); // at least one array word
}

// ── Storage helpers ───────────────────────────────────────────────────────────

fn storeVerifier(proof_type: u8, addr: [20]u8) void {
    const s = verifierSlot(proof_type);
    var w: [32]u8 = [_]u8{0} ** 32;
    @memcpy(w[12..32], &addr);
    vm.storage_cache_bytes32(&s, &w);
    vm.storage_flush_cache(0);
}

fn loadVerifier(proof_type: u8) [20]u8 {
    const s = verifierSlot(proof_type);
    var w: [32]u8 = undefined;
    vm.storage_load_bytes32(&s, &w);
    return w[12..32].*;
}

fn saveCircuit(cid: [32]u8, proof_type: u8, vk_hash: [32]u8) void {
    var tw: [32]u8 = [_]u8{0} ** 32;
    tw[0] = proof_type;
    var rw: [32]u8 = [_]u8{0} ** 32;
    rw[31] = 1;
    vm.storage_cache_bytes32(&circuitTypeSlot(cid), &tw);
    vm.storage_cache_bytes32(&circuitVkSlot(cid),   &vk_hash);
    vm.storage_cache_bytes32(&circuitRegSlot(cid),  &rw);
    vm.storage_flush_cache(0);
}

fn requireOwner() !void {
    var w: [32]u8 = undefined;
    vm.storage_load_bytes32(&SLOT_OWNER, &w);
    var sender: [20]u8 = undefined;
    vm.msg_sender(&sender);
    if (!std.mem.eql(u8, w[12..32], &sender)) return error.Unauthorized;
}

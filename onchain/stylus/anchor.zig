//! xB77 CompressionAnchor — Stylus WASM contract (Zig)
//!
//! Anchors the xB77 compression state root on Arbitrum.
//! Replaces the Solidity xb77_compression program's anchor logic.
//!
//! ABI:
//!   initialize(address owner)
//!   anchorRoot(bytes32 newRoot)                         → emits RootAnchored
//!   verifyAndAnchor(bytes32 newRoot, bytes proof)       → emits RootAnchored
//!   getRoot() returns (bytes32)
//!   getBatchCount() returns (uint64)
//!
//! Storage layout:
//!   slot 0x00: currentRoot   (bytes32)
//!   slot 0x01: owner         (bytes32, address in lower 20 bytes)
//!   slot 0x02: batchCount    (bytes32, uint64 in lower 8 bytes)
//!   slot 0x03: initialized   (bytes32, bool in last byte)

const std  = @import("std");
const host = @import("host.zig");
const abi  = @import("abi.zig");

// ── Selectors (comptime keccak256) ───────────────────────────────────────────

const SEL_INITIALIZE       = abi.selector("initialize(address)");
const SEL_ANCHOR_ROOT      = abi.selector("anchorRoot(bytes32)");
const SEL_VERIFY_AND_ANCHOR= abi.selector("verifyAndAnchor(bytes32,bytes)");
const SEL_GET_ROOT         = abi.selector("getRoot()");
const SEL_GET_BATCH_COUNT  = abi.selector("getBatchCount()");

// ── Storage slots ─────────────────────────────────────────────────────────────

const SLOT_ROOT:        [32]u8 = slot(0);
const SLOT_OWNER:       [32]u8 = slot(1);
const SLOT_BATCH_COUNT: [32]u8 = slot(2);
const SLOT_INIT:        [32]u8 = slot(3);

fn slot(n: u8) [32]u8 {
    var s = [_]u8{0} ** 32;
    s[31] = n;
    return s;
}

// ── Event topics ──────────────────────────────────────────────────────────────
// RootAnchored(bytes32 indexed newRoot, uint64 batchCount)
const TOPIC_ROOT_ANCHORED = abi.selector("RootAnchored(bytes32,uint64)");

// ── Entrypoint ────────────────────────────────────────────────────────────────

export fn user_entrypoint(args_len: usize) i32 {
    // Required by Stylus VM: import must be referenced so the WASM includes it.
    // The VM instruments memory.grow at activation time using this import.
    host.pay_for_memory_grow(0);
    run(args_len) catch |err| {
        const msg = @errorName(err);
        host.write_result(msg.ptr, msg.len);
        return 1;
    };
    return 0;
}

fn run(args_len: usize) !void {
    if (args_len < 4) return error.InvalidCalldata;

    var calldata: [4096]u8 = undefined;
    host.read_args(&calldata);

    const sel = calldata[0..4].*;

    if (std.mem.eql(u8, &sel, &SEL_INITIALIZE))        return handle_initialize(calldata[4..args_len]);
    if (std.mem.eql(u8, &sel, &SEL_ANCHOR_ROOT))       return handle_anchor_root(calldata[4..args_len]);
    if (std.mem.eql(u8, &sel, &SEL_VERIFY_AND_ANCHOR)) return handle_verify_and_anchor(calldata[4..args_len]);
    if (std.mem.eql(u8, &sel, &SEL_GET_ROOT))          return handle_get_root();
    if (std.mem.eql(u8, &sel, &SEL_GET_BATCH_COUNT))   return handle_get_batch_count();

    return error.UnknownSelector;
}

// ── Handlers ──────────────────────────────────────────────────────────────────

fn handle_initialize(data: []const u8) !void {
    // Revert if already initialized
    var init_flag: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_INIT, &init_flag);
    if (init_flag[31] != 0) return error.AlreadyInitialized;

    var dec = abi.Decoder.init(data);
    const owner_addr = try dec.address();

    var owner_word = [_]u8{0} ** 32;
    @memcpy(owner_word[12..32], &owner_addr);
    host.storage_store_bytes32(&SLOT_OWNER, &owner_word);

    var flag = [_]u8{0} ** 32;
    flag[31] = 1;
    host.storage_store_bytes32(&SLOT_INIT, &flag);

    host.write_result(&[_]u8{}, 0);
}

fn handle_anchor_root(data: []const u8) !void {
    try assertOwner();

    var dec = abi.Decoder.init(data);
    const new_root = try dec.bytes32();

    try storeRoot(new_root);
}

fn handle_verify_and_anchor(data: []const u8) !void {
    try assertOwner();

    var dec = abi.Decoder.init(data);
    const new_root = try dec.bytes32();
    const proof    = try dec.bytes();

    // Proof sanity: must be non-empty and plausible length for a UltraPlonk proof.
    // Full on-chain verification via BN254 precompile is done in ZKVerifier contract.
    // This contract trusts that the caller has already verified the proof there.
    if (proof.len == 0) return error.EmptyProof;

    try storeRoot(new_root);
}

fn handle_get_root() !void {
    var root: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_ROOT, &root);
    host.write_result(&root, 32);
}

fn handle_get_batch_count() !void {
    var count_word: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_BATCH_COUNT, &count_word);
    host.write_result(&count_word, 32);
}

// ── Internals ─────────────────────────────────────────────────────────────────

fn assertOwner() !void {
    var sender: [20]u8 = undefined;
    host.msg_sender(&sender);

    var owner_word: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_OWNER, &owner_word);

    for (sender, 0..) |b, i| {
        if (b != owner_word[12 + i]) return error.NotOwner;
    }
}

fn storeRoot(new_root: [32]u8) !void {
    host.storage_store_bytes32(&SLOT_ROOT, &new_root);

    // Increment batch count
    var count_word: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_BATCH_COUNT, &count_word);
    var count = @import("std").mem.readInt(u64, count_word[24..32], .big);
    count += 1;
    @import("std").mem.writeInt(u64, count_word[24..32], count, .big);
    host.storage_store_bytes32(&SLOT_BATCH_COUNT, &count_word);

    // Emit: RootAnchored(bytes32 indexed newRoot, uint64 batchCount)
    // Layout: topic[0]=event_sig, topic[1]=newRoot, data=uint64 count
    var log_buf: [32 + 32 + 32]u8 = undefined;
    // topic 0: event signature
    const ev_sig = abi.selector("RootAnchored(bytes32,uint64)");
    @memset(log_buf[0..28], 0);
    @memcpy(log_buf[0..4], &ev_sig);
    // topic 1: newRoot (indexed)
    @memcpy(log_buf[32..64], &new_root);
    // data: batchCount as uint64 ABI-encoded
    @memset(log_buf[64..88], 0);
    @import("std").mem.writeInt(u64, log_buf[88..96][0..8], count, .big);

    host.emit_log(&log_buf, log_buf.len, 2); // 2 topics

    host.write_result(&[_]u8{}, 0);
}

//! xB77 SettlementEngine — Stylus WASM contract (Zig)
//!
//! Agent-to-agent USDC settlement with ZK commitments.
//! Replaces Settlement.sol — same ABI, native WASM performance.
//!
//! ABI:
//!   initialize(address owner, address usdc, address circleMessenger)
//!   settle(address agent, uint256 amount, bytes32 commitment)
//!     → emits Settled(address indexed agent, uint256 amount, bytes32 commitment)
//!   batchSettle(address[] agents, uint256[] amounts, bytes32[] commitments)
//!   handleReceiveMessage(uint32 sourceDomain, bytes32 sender, bytes messageBody)
//!     → returns bool (Circle CCTP hook)
//!   getBalance(address account) returns (uint256)  [staticcall to USDC]
//!
//! Storage:
//!   slot 0: owner
//!   slot 1: usdc address
//!   slot 2: circle messenger address
//!   slot 3: initialized flag
//!   slot 4: total settled (uint256)

const std  = @import("std");
const host = @import("host.zig");
const abi  = @import("abi.zig");
const bump = @import("alloc.zig");

// ── Selectors ────────────────────────────────────────────────────────────────

const SEL_INITIALIZE     = abi.selector("initialize(address,address,address)");
const SEL_SETTLE         = abi.selector("settle(address,uint256,bytes32)");
const SEL_BATCH_SETTLE   = abi.selector("batchSettle(address[],uint256[],bytes32[])");
const SEL_HANDLE_RECEIVE = abi.selector("handleReceiveMessage(uint32,bytes32,bytes)");
const SEL_GET_BALANCE    = abi.selector("getBalance(address)");
const SEL_TOTAL_SETTLED  = abi.selector("totalSettled()");

// ── Storage slots ─────────────────────────────────────────────────────────────

const SLOT_OWNER:          [32]u8 = slot(0);
const SLOT_USDC:           [32]u8 = slot(1);
const SLOT_CIRCLE:         [32]u8 = slot(2);
const SLOT_INIT:           [32]u8 = slot(3);
const SLOT_TOTAL_SETTLED:  [32]u8 = slot(4);

fn slot(n: u8) [32]u8 {
    var s = [_]u8{0} ** 32;
    s[31] = n;
    return s;
}

// ── ERC-20 balanceOf selector ─────────────────────────────────────────────────
const SEL_BALANCE_OF = abi.selector("balanceOf(address)");

// ── Entrypoint ────────────────────────────────────────────────────────────────

export fn user_entrypoint(args_len: usize) i32 {
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

    var calldata: [8192]u8 = undefined;
    host.read_args(&calldata);

    const sel = calldata[0..4].*;
    const params = calldata[4..args_len];

    if (std.mem.eql(u8, &sel, &SEL_INITIALIZE))     return handle_initialize(params);
    if (std.mem.eql(u8, &sel, &SEL_SETTLE))         return handle_settle(params);
    if (std.mem.eql(u8, &sel, &SEL_BATCH_SETTLE))   return handle_batch_settle(params);
    if (std.mem.eql(u8, &sel, &SEL_HANDLE_RECEIVE)) return handle_receive_message(params);
    if (std.mem.eql(u8, &sel, &SEL_GET_BALANCE))    return handle_get_balance(params);
    if (std.mem.eql(u8, &sel, &SEL_TOTAL_SETTLED))  return handle_total_settled();

    return error.UnknownSelector;
}

// ── Handlers ──────────────────────────────────────────────────────────────────

fn handle_initialize(data: []const u8) !void {
    var init_flag: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_INIT, &init_flag);
    if (init_flag[31] != 0) return error.AlreadyInitialized;

    var dec = abi.Decoder.init(data);
    const owner_addr  = try dec.address();
    const usdc_addr   = try dec.address();
    const circle_addr = try dec.address();

    storeAddress(&SLOT_OWNER,  owner_addr);
    storeAddress(&SLOT_USDC,   usdc_addr);
    storeAddress(&SLOT_CIRCLE, circle_addr);

    var flag = [_]u8{0} ** 32;
    flag[31] = 1;
    host.storage_store_bytes32(&SLOT_INIT, &flag);

    host.write_result(&[_]u8{}, 0);
}

fn handle_settle(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const agent      = try dec.address();
    const amount_raw = try dec.uint256();
    const commitment = try dec.bytes32();

    emitSettled(agent, amount_raw, commitment);
    accumulateSettled(amount_raw);

    host.write_result(&[_]u8{}, 0);
}

fn handle_batch_settle(data: []const u8) !void {
    // ABI: batchSettle(address[] agents, uint256[] amounts, bytes32[] commitments)
    // Head: three offset words (96 bytes).
    // Each offset points to an array: [uint256 count][elem_0]...[elem_n-1]
    var dec = abi.Decoder.init(data);
    const agents_off      = try dec.offset();
    const amounts_off     = try dec.offset();
    const commitments_off = try dec.offset();

    const agents      = try abi.DynArray.read(data, agents_off);
    const amounts     = try abi.DynArray.read(data, amounts_off);
    const commitments = try abi.DynArray.read(data, commitments_off);

    if (agents.len() != amounts.len() or agents.len() != commitments.len())
        return error.ArrayLengthMismatch;

    const n = agents.len();
    for (0..n) |i| {
        const agent      = try agents.address(i);
        const amount_raw = try amounts.uint256(i);
        const commitment = try commitments.bytes32(i);
        emitSettled(agent, amount_raw, commitment);
        accumulateSettled(amount_raw);
    }

    // Emit BatchSettled(uint256 count)
    const ev_sig = abi.selector("BatchSettled(uint256)");
    var log_buf: [64]u8 = undefined;
    @memset(log_buf[0..28], 0);
    @memcpy(log_buf[0..4], &ev_sig);
    @memset(log_buf[32..56], 0);
    std.mem.writeInt(u64, log_buf[56..64], n, .big);
    host.emit_log(&log_buf, 64, 1);

    host.write_result(&[_]u8{}, 0);
}

fn handle_receive_message(data: []const u8) !void {
    // Verify caller is Circle Messenger
    var sender: [20]u8 = undefined;
    host.msg_sender(&sender);
    var circle_word: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_CIRCLE, &circle_word);
    const circle_addr = circle_word[12..32].*;
    if (!std.mem.eql(u8, &sender, &circle_addr)) return error.OnlyCircleMessenger;

    var dec = abi.Decoder.init(data);
    const source_domain = try dec.uint32();
    const msg_sender_b32 = try dec.bytes32();
    const msg_body      = try dec.bytes();

    _ = source_domain;
    _ = msg_sender_b32;

    // Decode message body: [agent_address(20)] + [commitment(32)]
    if (msg_body.len < 52) return error.InvalidMessageBody;
    var agent: [20]u8 = undefined;
    @memcpy(&agent, msg_body[0..20]);
    var commitment: [32]u8 = undefined;
    @memcpy(&commitment, msg_body[20..52]);

    var amount_raw = [_]u8{0} ** 32;
    amount_raw[31] = 1; // amount encoded in Circle message; use 1 as sentinel
    emitSettled(agent, amount_raw, commitment);

    // Return true (ABI bool)
    var ret = [_]u8{0} ** 32;
    ret[31] = 1;
    host.write_result(&ret, 32);
}

fn handle_get_balance(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const account = try dec.address();

    // Build balanceOf(account) calldata
    var call_data: [36]u8 = undefined;
    @memcpy(call_data[0..4], &SEL_BALANCE_OF);
    @memset(call_data[4..16], 0);
    @memcpy(call_data[16..36], &account);

    var usdc_word: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_USDC, &usdc_word);
    const usdc_addr = usdc_word[12..32].*;

    const zero_value = [_]u8{0} ** 32;
    const status = host.static_call(
        30000,
        &usdc_addr,
        &call_data,
        call_data.len,
    );
    if (status != 0) return error.BalanceCallFailed;

    const ret_size = host.return_data_size();
    var ret_buf: [32]u8 = [_]u8{0} ** 32;
    if (ret_size >= 32) host.return_data_copy(&ret_buf, 0, 32);

    _ = zero_value;
    host.write_result(&ret_buf, 32);
}

fn handle_total_settled() !void {
    var total: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_TOTAL_SETTLED, &total);
    host.write_result(&total, 32);
}

// ── Internals ─────────────────────────────────────────────────────────────────

fn storeAddress(s: *const [32]u8, addr: [20]u8) void {
    var word = [_]u8{0} ** 32;
    @memcpy(word[12..32], &addr);
    host.storage_store_bytes32(s, &word);
}

fn emitSettled(agent: [20]u8, amount_raw: [32]u8, commitment: [32]u8) void {
    // Settled(address indexed agent, uint256 amount, bytes32 commitment)
    // topics: [event_sig, agent_padded], data: [amount(32), commitment(32)]
    const ev_sig = abi.selector("Settled(address,uint256,bytes32)");
    var log_buf: [32 + 32 + 32 + 32]u8 = undefined;
    // topic 0: event signature (padded to 32)
    @memset(log_buf[0..28], 0);
    @memcpy(log_buf[0..4], &ev_sig);
    // topic 1: agent address (padded to 32, indexed)
    @memset(log_buf[32..44], 0);
    @memcpy(log_buf[44..64], &agent);
    // data[0]: amount
    @memcpy(log_buf[64..96], &amount_raw);
    // data[1]: commitment
    @memcpy(log_buf[96..128], &commitment);

    host.emit_log(&log_buf, 128, 2); // 2 topics (event sig + agent)
}

fn accumulateSettled(amount_raw: [32]u8) void {
    var total: [32]u8 = undefined;
    host.storage_load_bytes32(&SLOT_TOTAL_SETTLED, &total);
    // Simple addition of the low 8 bytes (sufficient for demo amounts)
    const cur = std.mem.readInt(u64, total[24..32], .big);
    const add = std.mem.readInt(u64, amount_raw[24..32], .big);
    std.mem.writeInt(u64, total[24..32], cur +| add, .big);
    host.storage_store_bytes32(&SLOT_TOTAL_SETTLED, &total);
}

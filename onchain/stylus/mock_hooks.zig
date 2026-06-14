/// xB77 Stylus Mock VM Hooks — Local Test Harness
///
/// Provides in-memory implementations of every Arbitrum Stylus vm_hook,
/// allowing Stylus contracts to be unit-tested natively with `zig build test-stylus`
/// without any blockchain node.
///
/// Usage:
///   sdk.zig selects this module automatically when the build target is native
///   (not wasm32). Tests just call contract functions normally.
///
/// Features:
///   - In-memory EVM storage (HashMap, 32-byte keys/values)
///   - Event log capture (inspect emitted logs in tests)
///   - Configurable msg.sender, block.number, block.timestamp
///   - Configurable call responses (mock external contract calls)
///   - Call stack for nested contract simulation

const std = @import("std");
const g1      = @import("bn254/g1.zig");
const g2      = @import("bn254/g2.zig");
const pairing = @import("bn254/pairing.zig");
const fp12    = @import("bn254/fp12.zig");

// ── Global test state ───────────────────────────────────────────────────────

var gpa = std.heap.DebugAllocator(.{}){};
const allocator = gpa.allocator();

/// Simulated EVM storage: slot[32] → value[32]
var storage: std.AutoHashMap([32]u8, [32]u8) = undefined;

/// Captured event logs for test assertions
pub const Log = struct {
    data: []u8,
    topics: [][32]u8,
};
var logs: std.ArrayListUnmanaged(Log) = .{ .items = &.{}, .capacity = 0 };

/// Mock responses for external contract calls: address+calldata_hash → response
var call_responses: std.AutoHashMap(u64, []u8) = undefined;

/// Current call context
var ctx_sender:    [20]u8 = [_]u8{0xDE} ** 20;
var ctx_value:     [32]u8 = [_]u8{0} ** 32;
var ctx_timestamp: i64    = 1_700_000_000;
var ctx_block:     i64    = 1_000_000;
var ctx_chainid:   i64    = 421_614; // Arbitrum Sepolia

/// Input args for the current entrypoint call
var input_buf: [4096]u8 = undefined;
var input_len: usize    = 0;

/// Output result buffer
var output_buf: [4096]u8 = undefined;
var output_len: usize    = 0;

/// Return data from the last call
var return_data_buf: [4096]u8 = undefined;
var return_data_len: usize    = 0;

var initialized = false;

/// When set, ecPairing precompile returns this fixed value instead of running real crypto.
/// null = run real BN254 pairing (default). Set via forceEcPairingResult().
var ec_pairing_override: ?bool = null;

// ── Test harness control API ────────────────────────────────────────────────

pub fn init() void {
    if (initialized) return;
    storage = std.AutoHashMap([32]u8, [32]u8).init(allocator);
    logs = .{ .items = &.{}, .capacity = 0 };
    call_responses = std.AutoHashMap(u64, []u8).init(allocator);
    initialized = true;
}

/// Override the ecPairing precompile result for tests that need synthetic inputs.
/// Call reset() to clear.
pub fn forceEcPairingResult(result: bool) void { ec_pairing_override = result; }

pub fn reset() void {
    if (!initialized) { init(); return; }
    ec_pairing_override = null;
    storage.clearRetainingCapacity();
    for (logs.items) |log| {
        allocator.free(log.data);
        for (log.topics) |_| {}
        allocator.free(log.topics);
    }
    logs.clearRetainingCapacity();
    call_responses.clearRetainingCapacity();
    output_len = 0;
    return_data_len = 0;
}

pub fn setSender(addr: [20]u8) void { ctx_sender = addr; }
pub fn setTimestamp(ts: i64) void   { ctx_timestamp = ts; }
pub fn setBlock(n: i64) void        { ctx_block = n; }

pub fn setInput(data: []const u8) void {
    const n = @min(data.len, input_buf.len);
    @memcpy(input_buf[0..n], data[0..n]);
    input_len = n;
}

pub fn getOutput() []const u8 {
    return output_buf[0..output_len];
}

pub fn getLogs() []const Log {
    return logs.items;
}

/// Register a mock response for a call to `addr` with `calldata`.
/// The harness matches on addr[0..8] XOR'd with calldata[0..4] as a quick key.
pub fn mockCall(addr: [20]u8, calldata_selector: [4]u8, response: []const u8) void {
    var key: u64 = 0;
    for (addr[0..8]) |b| key = (key << 8) | b;
    key ^= @as(u64, std.mem.readInt(u32, &calldata_selector, .big));
    const owned = allocator.dupe(u8, response) catch return;
    call_responses.put(key, owned) catch {};
}

// ── vm_hooks implementations ────────────────────────────────────────────────

pub fn pay_for_memory_grow(_: u16) void {}

pub fn read_args(dest: [*]u8) void {
    @memcpy(dest[0..input_len], input_buf[0..input_len]);
}

pub fn write_result(data: [*]const u8, len: usize) void {
    const n = @min(len, output_buf.len);
    @memcpy(output_buf[0..n], data[0..n]);
    output_len = n;
}

pub fn exit_early(status: i32) noreturn {
    std.debug.print("[mock_hooks] exit_early({})\n", .{status});
    std.process.exit(@intCast(if (status == 0) 0 else 1));
}

pub fn storage_load_bytes32(key: [*]const u8, dest: [*]u8) void {
    var k: [32]u8 = undefined;
    @memcpy(&k, key[0..32]);
    const val = storage.get(k) orelse [_]u8{0} ** 32;
    @memcpy(dest[0..32], &val);
}

pub fn storage_cache_bytes32(key: [*]const u8, value: [*]const u8) void {
    var k: [32]u8 = undefined;
    var v: [32]u8 = undefined;
    @memcpy(&k, key[0..32]);
    @memcpy(&v, value[0..32]);
    storage.put(k, v) catch {};
}

pub fn storage_flush_cache(_: u32) void {
    // In the mock, cache == persistent storage — nothing to flush.
}

pub fn msg_sender(dest: [*]u8) void {
    @memcpy(dest[0..20], &ctx_sender);
}

pub fn msg_value(dest: [*]u8) void {
    @memcpy(dest[0..32], &ctx_value);
}

pub fn block_timestamp() i64 { return ctx_timestamp; }
pub fn block_number() i64    { return ctx_block; }
pub fn chainid() i64         { return ctx_chainid; }

pub fn native_keccak256(data: [*]const u8, len: usize, dest: [*]u8) void {
    // Use Zig's built-in keccak256 for native tests
    var hasher = std.crypto.hash.sha3.Keccak256.init(.{});
    hasher.update(data[0..len]);
    var hash: [32]u8 = undefined;
    hasher.final(&hash);
    @memcpy(dest[0..32], &hash);
}

// data layout: [topic_0][topic_1]...[topic_N][unindexed bytes], topics = count of leading topics
pub fn emit_log(data: [*]const u8, len: u32, topics: u32) void {
    const n: usize = len;
    const t: usize = topics;
    const topics_bytes = t * 32;
    const data_copy = allocator.dupe(u8, data[0..n]) catch return;
    const topics_copy = allocator.alloc([32]u8, t) catch {
        allocator.free(data_copy);
        return;
    };
    for (0..t) |i| {
        @memcpy(&topics_copy[i], data[i * 32 ..][0..32]);
    }
    _ = topics_bytes;
    logs.append(allocator, .{ .data = data_copy, .topics = topics_copy }) catch {};
}

pub fn static_call_contract(
    address: [*]const u8,
    data: [*]const u8,
    data_len: u32,
    _gas: u64,
    out_ret_len: *u32,
) u8 {
    _ = _gas;

    // EIP-197: ecPairing precompile at address 0x08
    // Input: N * 192 bytes (64-byte G1 affine + 128-byte G2 affine per pair)
    // Output: 32 bytes, [31]=1 if ∏ate(Pᵢ,Qᵢ)==1, else 0
    if (address[19] == 0x08 and data_len % 192 == 0) {
        return_data_buf = [_]u8{0} ** 4096;
        if (ec_pairing_override) |forced| {
            return_data_buf[31] = if (forced) 1 else 0;
        } else {
            const n_pairs = data_len / 192;
            var acc = fp12.Fp12.ONE;
            var i: u32 = 0;
            while (i < n_pairs) : (i += 1) {
                const base = i * 192;
                const g1_bytes = data[base..][0..64];
                const g2_bytes = data[base + 64..][0..128];
                const p = g1.G1.fromAffineBytes(g1_bytes);
                const q = g2.G2.fromAffineBytes(g2_bytes);
                acc = fp12.Fp12.mul(acc, pairing.ate(p, q));
            }
            return_data_buf[31] = if (fp12.Fp12.eql(acc, fp12.Fp12.ONE)) 1 else 0;
        }
        return_data_len = 32;
        out_ret_len.* = 32;
        return 0;
    }

    var key: u64 = 0;
    for (address[0..8]) |b| key = (key << 8) | b;
    if (data_len >= 4) {
        key ^= @as(u64, std.mem.readInt(u32, data[0..4], .big));
    }
    if (call_responses.get(key)) |resp| {
        const n = @min(resp.len, return_data_buf.len);
        @memcpy(return_data_buf[0..n], resp[0..n]);
        return_data_len = n;
        out_ret_len.* = @intCast(n);
        return 0;
    }
    // Default: truthy 32-byte response
    return_data_buf = [_]u8{0} ** 4096;
    return_data_buf[31] = 1;
    return_data_len = 32;
    out_ret_len.* = 32;
    return 0;
}

pub fn call_contract(
    address: [*]const u8,
    data: [*]const u8,
    data_len: u32,
    _: [*]const u8,
    gas: u64,
    out_ret_len: *u32,
) u8 {
    return static_call_contract(address, data, data_len, gas, out_ret_len);
}

pub fn return_data_size() u32 {
    return @intCast(return_data_len);
}

pub fn read_return_data(dest: [*]u8, offset: u32, len: u32) u32 {
    const off: usize = offset;
    const n: usize = len;
    if (off >= return_data_len) return 0;
    const end = @min(off + n, return_data_len);
    const copied = end - off;
    @memcpy(dest[0..copied], return_data_buf[off..end]);
    return @intCast(copied);
}

pub fn contract_address(dest: [*]u8) void {
    // In tests, the contract's own address is 0xCC...CC
    const self_addr = [_]u8{0xCC} ** 20;
    @memcpy(dest[0..20], &self_addr);
}

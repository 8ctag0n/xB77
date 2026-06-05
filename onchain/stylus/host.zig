//! Stylus host imports — all functions exposed by the Arbitrum WasmVM.
//! Import module: "vm_hooks" (required by cargo stylus check).
//!
//! Rules:
//!   - All pointers are u32 (WASM linear memory offsets).
//!   - `write_result` must be called before returning from user_entrypoint.
//!   - Memory pages are charged via pay_for_memory_grow (VM instruments this).
//!   - Storage writes go through cache; VM flushes on return unless you call
//!     storage_flush_cache explicitly (e.g. before an external call).

pub extern "vm_hooks" fn read_args(dest: [*]u8) void;
pub extern "vm_hooks" fn write_result(data: [*]const u8, len: u32) void;
pub extern "vm_hooks" fn return_data_size() u32;

pub extern "vm_hooks" fn storage_load_bytes32(key: *const [32]u8, out: *[32]u8) void;

// Stylus 0.10+: storage writes are cached; flush to commit.
pub extern "vm_hooks" fn storage_cache_bytes32(key: *const [32]u8, val: *const [32]u8) void;
pub extern "vm_hooks" fn storage_flush_cache(clear: u32) void;

// Convenience: write-through (cache + immediate flush). Use for contracts that don't
// batch writes — simpler than calling cache/flush separately.
pub fn storage_store_bytes32(key: *const [32]u8, val: *const [32]u8) void {
    storage_cache_bytes32(key, val);
    storage_flush_cache(0);
}

pub extern "vm_hooks" fn msg_sender(out: *[20]u8) void;
pub extern "vm_hooks" fn msg_value(out: *[32]u8) void;
pub extern "vm_hooks" fn msg_reentrant() u32;

pub extern "vm_hooks" fn block_number() u64;
pub extern "vm_hooks" fn block_timestamp() u64;
pub extern "vm_hooks" fn tx_gas_price(out: *[32]u8) void;
pub extern "vm_hooks" fn tx_origin(out: *[20]u8) void;

// topics: number of leading 32-byte topic slots in data (max 4)
pub extern "vm_hooks" fn emit_log(data: [*]const u8, len: u32, topics: u32) void;

// Stylus 0.10+: call functions renamed + param order changed.
// Raw API:
pub extern "vm_hooks" fn call_contract(
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: u32,
    value: *const [32]u8,
    gas: u64,
    return_data_len: *u32,
) u8;

pub extern "vm_hooks" fn static_call_contract(
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: u32,
    gas: u64,
    return_data_len: *u32,
) u8;

pub extern "vm_hooks" fn delegate_call_contract(
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: u32,
    gas: u64,
    return_data_len: *u32,
) u8;

// Compat wrappers matching the pre-0.10 signatures used in our contracts.
pub fn call(
    gas: u64,
    contract: *const [20]u8,
    value: *const [32]u8,
    data: [*]const u8,
    data_len: usize,
) i32 {
    var ret_len: u32 = 0;
    return @as(i32, @intCast(call_contract(contract, data, @intCast(data_len), value, gas, &ret_len)));
}

pub fn static_call(
    gas: u64,
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: usize,
) i32 {
    var ret_len: u32 = 0;
    return @as(i32, @intCast(static_call_contract(contract, data, @intCast(data_len), gas, &ret_len)));
}

pub fn delegate_call(
    gas: u64,
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: usize,
) i32 {
    var ret_len: u32 = 0;
    return @as(i32, @intCast(delegate_call_contract(contract, data, @intCast(data_len), gas, &ret_len)));
}

// Stylus 0.10+: return_data_copy → read_return_data (returns bytes copied).
pub extern "vm_hooks" fn read_return_data(dest: [*]u8, offset: u32, size: u32) u32;

// Compat wrapper matching pre-0.10 return_data_copy signature.
pub fn return_data_copy(dest: [*]u8, offset: usize, size: usize) void {
    _ = read_return_data(dest, @intCast(offset), @intCast(size));
}

// Required by Stylus VM: must be imported if the contract's WASM memory grows.
// The VM instruments memory.grow to call this automatically at activation time.
pub extern "vm_hooks" fn pay_for_memory_grow(pages: u16) void;

// ── Helpers ──────────────────────────────────────────────────────────────────

pub fn revert(data: []const u8) noreturn {
    write_result(data.ptr, @intCast(data.len));
    @panic("revert");
}

pub fn revertStr(comptime msg: []const u8) noreturn {
    // ABI-encode as Error(string): selector 0x08c379a0 + ABI string
    var buf: [4 + 32 + 32 + 256]u8 = undefined;
    buf[0] = 0x08; buf[1] = 0xc3; buf[2] = 0x79; buf[3] = 0xa0;
    @memset(buf[4..36], 0);
    buf[35] = 0x20;
    @memset(buf[36..68], 0);
    const len: u8 = @intCast(@min(msg.len, 255));
    buf[67] = len;
    const data_start = 68;
    @memcpy(buf[data_start..][0..len], msg[0..len]);
    @memset(buf[data_start + len ..][0 .. 32 - (len % 32)], 0);
    const total = data_start + 32 * ((len + 31) / 32);
    write_result(&buf, @intCast(total));
    @panic("revert");
}

//! Stylus host imports — all functions exposed by the Arbitrum WasmVM.
//! Import module: "vm_hooks" (required by cargo stylus check).
//!
//! Rules:
//!   - All pointers are u32 (WASM linear memory offsets).
//!   - `write_result` must be called before returning from user_entrypoint.
//!   - Memory pages must be paid for via pay_for_memory_grow before use.

pub extern "vm_hooks" fn read_args(dest: [*]u8) void;
pub extern "vm_hooks" fn write_result(data: [*]const u8, len: usize) void;
pub extern "vm_hooks" fn return_data_size() usize;

pub extern "vm_hooks" fn storage_load_bytes32(key: *const [32]u8, out: *[32]u8) void;
pub extern "vm_hooks" fn storage_store_bytes32(key: *const [32]u8, val: *const [32]u8) void;

pub extern "vm_hooks" fn msg_sender(out: *[20]u8) void;
pub extern "vm_hooks" fn msg_value(out: *[32]u8) void;
pub extern "vm_hooks" fn msg_reentrant() u32;

pub extern "vm_hooks" fn block_number() u64;
pub extern "vm_hooks" fn block_timestamp() u64;
pub extern "vm_hooks" fn tx_gas_price(out: *[32]u8) void;
pub extern "vm_hooks" fn tx_origin(out: *[20]u8) void;

// topics: number of leading 32-byte topic slots in data (max 4)
pub extern "vm_hooks" fn emit_log(data: [*]const u8, len: usize, topics: usize) void;

// Returns 0 on success. Destination contract address is 20 bytes at contract_ptr.
pub extern "vm_hooks" fn call(
    gas: u64,
    contract: *const [20]u8,
    value: *const [32]u8,
    data: [*]const u8,
    data_len: usize,
) i32;

pub extern "vm_hooks" fn static_call(
    gas: u64,
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: usize,
) i32;

pub extern "vm_hooks" fn delegate_call(
    gas: u64,
    contract: *const [20]u8,
    data: [*]const u8,
    data_len: usize,
) i32;

pub extern "vm_hooks" fn return_data_copy(dest: [*]u8, offset: usize, size: usize) void;

pub extern "vm_hooks" fn pay_for_memory_grow(pages: u32) void;

// ── Helpers ──────────────────────────────────────────────────────────────────

pub fn revert(data: []const u8) noreturn {
    write_result(data.ptr, data.len);
    // Signal revert by writing a sentinel we check in user_entrypoint's error path.
    // In practice, we panic so the WASM trap propagates as a revert.
    @panic("revert");
}

pub fn revertStr(comptime msg: []const u8) noreturn {
    // ABI-encode as Error(string): selector 0x08c379a0 + ABI string
    var buf: [4 + 32 + 32 + 256]u8 = undefined;
    // selector
    buf[0] = 0x08; buf[1] = 0xc3; buf[2] = 0x79; buf[3] = 0xa0;
    // offset to string = 0x20
    @memset(buf[4..36], 0);
    buf[35] = 0x20;
    // length
    @memset(buf[36..68], 0);
    const len: u8 = @intCast(@min(msg.len, 255));
    buf[67] = len;
    // data (padded to 32-byte boundary)
    const data_start = 68;
    @memcpy(buf[data_start..][0..len], msg[0..len]);
    @memset(buf[data_start + len ..][0 .. 32 - (len % 32)], 0);
    const total = data_start + 32 * ((len + 31) / 32);
    write_result(&buf, total);
    @panic("revert");
}

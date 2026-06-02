/// xB77 Stylus SDK — VM hooks + high-level wrappers
///
/// Comptime-switchable: in wasm32 production builds uses real Arbitrum Stylus
/// vm_hooks (extern imports). In native test builds uses mock_hooks.zig for
/// fully local testing with `zig build test-stylus`.

const std = @import("std");
const builtin = @import("builtin");

const IS_WASM = builtin.cpu.arch == .wasm32;

// ── VM hooks backend (comptime selected) ───────────────────────────────────

/// Real Arbitrum Stylus host imports (used in production WASM builds)
const real_hooks = struct {
    pub extern "vm_hooks" fn read_args(dest: [*]u8) void;
    pub extern "vm_hooks" fn write_result(data: [*]const u8, len: usize) void;
    pub extern "vm_hooks" fn exit_early(status: i32) noreturn;

    pub extern "vm_hooks" fn storage_load_bytes32(key: [*]const u8, dest: [*]u8) void;
    pub extern "vm_hooks" fn storage_cache_bytes32(key: [*]const u8, value: [*]const u8) void;
    pub extern "vm_hooks" fn storage_flush_cache() void;

    pub extern "vm_hooks" fn msg_sender(dest: [*]u8) void;
    pub extern "vm_hooks" fn msg_value(dest: [*]u8) void;
    pub extern "vm_hooks" fn block_timestamp() i64;
    pub extern "vm_hooks" fn block_number() i64;
    pub extern "vm_hooks" fn chainid() i64;

    pub extern "vm_hooks" fn native_keccak256(data: [*]const u8, len: usize, dest: [*]u8) void;
    pub extern "vm_hooks" fn emit_log(data: [*]const u8, len: usize, topics: [*]const u8, topics_len: usize) void;

    pub extern "vm_hooks" fn static_call_contract(address: [*]const u8, data: [*]const u8, data_len: usize, gas: i64) i32;
    pub extern "vm_hooks" fn call_contract(address: [*]const u8, value: [*]const u8, data: [*]const u8, data_len: usize, gas: i64) i32;
    pub extern "vm_hooks" fn return_data_size() usize;
    pub extern "vm_hooks" fn read_return_data(dest: [*]u8, offset: usize, len: usize) void;
    pub extern "vm_hooks" fn contract_address(dest: [*]u8) void;
};

/// Select backend at comptime
pub const vm_hooks = if (IS_WASM) real_hooks else @import("mock_hooks.zig");

// ── High-level SDK wrappers ────────────────────────────────────────────────

pub const Stylus = struct {
    // EVM precompile addresses
    pub const ADDR_ECADD:     [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x06};
    pub const ADDR_ECMUL:     [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x07};
    pub const ADDR_ECPAIRING: [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x08};

    pub fn getArgs(alloc: std.mem.Allocator, len: usize) ![]u8 {
        const buf = try alloc.alloc(u8, len);
        vm_hooks.read_args(buf.ptr);
        return buf;
    }

    pub fn output(data: []const u8) void {
        vm_hooks.write_result(data.ptr, data.len);
    }

    pub fn revert() noreturn {
        vm_hooks.exit_early(1);
    }

    pub fn getSender() [20]u8 {
        var addr: [20]u8 = undefined;
        vm_hooks.msg_sender(&addr);
        return addr;
    }

    pub fn getSelf() [20]u8 {
        var addr: [20]u8 = undefined;
        vm_hooks.contract_address(&addr);
        return addr;
    }

    pub fn keccak256(data: []const u8) [32]u8 {
        var hash: [32]u8 = undefined;
        vm_hooks.native_keccak256(data.ptr, data.len, &hash);
        return hash;
    }

    pub fn sload(key: [32]u8) [32]u8 {
        var val: [32]u8 = undefined;
        vm_hooks.storage_load_bytes32(&key, &val);
        return val;
    }

    pub fn sstore(key: [32]u8, value: [32]u8) void {
        vm_hooks.storage_cache_bytes32(&key, &value);
    }

    pub fn log(data: []const u8, topics: []const [32]u8) void {
        vm_hooks.emit_log(data.ptr, data.len, @ptrCast(topics.ptr), topics.len);
    }

    // ── External calls ─────────────────────────────────────────────────────

    /// Static call to an EVM precompile or contract. Returns output bytes.
    pub fn callPrecompile(alloc: std.mem.Allocator, address: [20]u8, input: []const u8) ![]u8 {
        const success = vm_hooks.static_call_contract(&address, input.ptr, input.len, 1_000_000);
        if (success != 0) return error.CallFailed;
        const size = vm_hooks.return_data_size();
        const out = try alloc.alloc(u8, size);
        vm_hooks.read_return_data(out.ptr, 0, size);
        return out;
    }

    /// Static call to any external contract.
    pub fn staticCall(alloc: std.mem.Allocator, address: [20]u8, input: []const u8) ![]u8 {
        const success = vm_hooks.static_call_contract(&address, input.ptr, input.len, 500_000);
        if (success != 0) return error.StaticCallFailed;
        const size = vm_hooks.return_data_size();
        const out = try alloc.alloc(u8, size);
        vm_hooks.read_return_data(out.ptr, 0, size);
        return out;
    }

    /// Mutable call to an external contract (can transfer ETH, change state).
    pub fn callContract(alloc: std.mem.Allocator, address: [20]u8, value_wei: u256, input: []const u8) ![]u8 {
        var value_bytes: [32]u8 = undefined;
        std.mem.writeInt(u256, &value_bytes, value_wei, .big);
        const success = vm_hooks.call_contract(&address, &value_bytes, input.ptr, input.len, 500_000);
        if (success != 0) return error.CallFailed;
        const size = vm_hooks.return_data_size();
        const out = try alloc.alloc(u8, size);
        vm_hooks.read_return_data(out.ptr, 0, size);
        return out;
    }

    // ── ERC-20 helpers ─────────────────────────────────────────────────────

    /// ERC-20 transferFrom(from, to, amount). Returns true on success.
    pub fn erc20TransferFrom(
        alloc: std.mem.Allocator,
        token: [20]u8,
        from: [20]u8,
        to: [20]u8,
        amount: u256,
    ) !bool {
        // transferFrom(address,address,uint256) = 0x23b872dd
        var cd: [4 + 32 + 32 + 32]u8 = undefined;
        cd[0] = 0x23; cd[1] = 0xb8; cd[2] = 0x72; cd[3] = 0xdd;
        @memset(cd[4..16], 0);  @memcpy(cd[16..36], &from);
        @memset(cd[36..48], 0); @memcpy(cd[48..68], &to);
        std.mem.writeInt(u256, cd[68..100][0..32], amount, .big);
        const out = try callContract(alloc, token, 0, &cd);
        return out.len >= 32 and out[31] != 0;
    }

    /// ERC-20 transfer(to, amount). Returns true on success.
    pub fn erc20Transfer(
        alloc: std.mem.Allocator,
        token: [20]u8,
        to: [20]u8,
        amount: u256,
    ) !bool {
        // transfer(address,uint256) = 0xa9059cbb
        var cd: [4 + 32 + 32]u8 = undefined;
        cd[0] = 0xa9; cd[1] = 0x05; cd[2] = 0x9c; cd[3] = 0xbb;
        @memset(cd[4..16], 0); @memcpy(cd[16..36], &to);
        std.mem.writeInt(u256, cd[36..68][0..32], amount, .big);
        const out = try callContract(alloc, token, 0, &cd);
        return out.len >= 32 and out[31] != 0;
    }

    /// ERC-20 balanceOf(account). Returns balance as u256.
    pub fn erc20BalanceOf(alloc: std.mem.Allocator, token: [20]u8, account: [20]u8) !u256 {
        // balanceOf(address) = 0x70a08231
        var cd: [4 + 32]u8 = undefined;
        cd[0] = 0x70; cd[1] = 0xa0; cd[2] = 0x82; cd[3] = 0x31;
        @memset(cd[4..16], 0); @memcpy(cd[16..36], &account);
        const out = try staticCall(alloc, token, &cd);
        if (out.len < 32) return 0;
        return std.mem.readInt(u256, out[0..32][0..32], .big);
    }

    /// ERC-20 approve(spender, amount). Returns true on success.
    pub fn erc20Approve(
        alloc: std.mem.Allocator,
        token: [20]u8,
        spender: [20]u8,
        amount: u256,
    ) !bool {
        // approve(address,uint256) = 0x095ea7b3
        var cd: [4 + 32 + 32]u8 = undefined;
        cd[0] = 0x09; cd[1] = 0x5e; cd[2] = 0xa7; cd[3] = 0xb3;
        @memset(cd[4..16], 0); @memcpy(cd[16..36], &spender);
        std.mem.writeInt(u256, cd[36..68][0..32], amount, .big);
        const out = try callContract(alloc, token, 0, &cd);
        return out.len >= 32 and out[31] != 0;
    }
};

/// Simple fixed-buffer allocator for contract use (32KB, reset per call)
pub const ContractAllocator = struct {
    var buffer: [1024 * 32]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    pub fn get() std.mem.Allocator {
        return fba.allocator();
    }

    pub fn reset() void {
        fba.reset();
    }
};

/// EVM ABI selector helper
pub const abi = struct {
    pub fn selector(signature: []const u8) u32 {
        var hash: [32]u8 = undefined;
        vm_hooks.native_keccak256(signature.ptr, signature.len, &hash);
        return std.mem.readInt(u32, hash[0..4], .big);
    }
};

const std = @import("std");

/// Arbitrum Stylus VM Hooks (Host I/Os)
pub const vm_hooks = struct {
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
    pub extern "vm_hooks" fn return_data_size() usize;
    pub extern "vm_hooks" fn read_return_data(dest: [*]u8, offset: usize, len: usize) void;
};

/// High-level SDK wrappers
pub const Stylus = struct {
    pub const ADDR_ECADD: [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x06};
    pub const ADDR_ECMUL: [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x07};
    pub const ADDR_ECPAIRING: [20]u8 = [_]u8{0} ** 19 ++ [_]u8{0x08};

    pub fn getArgs(allocator: std.mem.Allocator, len: usize) ![]u8 {
        const buf = try allocator.alloc(u8, len);
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

    /// Calls an EVM precompile (static) and returns output
    pub fn callPrecompile(allocator: std.mem.Allocator, address: [20]u8, input: []const u8) ![]u8 {
        const gas_limit: i64 = 1_000_000;
        const success = vm_hooks.static_call_contract(&address, input.ptr, input.len, gas_limit);
        if (success != 0) return error.PrecompileFailed;
        
        const size = vm_hooks.return_data_size();
        const out = try allocator.alloc(u8, size);
        vm_hooks.read_return_data(out.ptr, 0, size);
        return out;
    }
};

/// Simple allocator for contract use
pub const ContractAllocator = struct {
    var buffer: [1024 * 32]u8 = undefined; // 32KB buffer
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    
    pub fn get() std.mem.Allocator {
        return fba.allocator();
    }

    pub fn reset() void {
        fba.reset();
    }
};

/// EVM ABI helpers
pub const abi = struct {
    pub fn selector(signature: []const u8) u32 {
        var hash: [32]u8 = undefined;
        vm_hooks.native_keccak256(signature.ptr, signature.len, &hash);
        return std.mem.readInt(u32, hash[0..4], .big);
    }
};

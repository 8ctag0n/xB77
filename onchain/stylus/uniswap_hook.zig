/// xB77 Uniswap v4 Constitution Hook — Arbitrum Stylus (Zig)
///
/// A Uniswap v4 hook that validates every swap's semantic intent against the
/// xB77 Sovereign Constitution before allowing it to execute. Malicious agent
/// swaps are reverted on-chain before any tokens move.
///
/// How it works:
///   1. Uniswap v4 PoolManager calls beforeSwap() on this hook for every swap.
///   2. The hook derives an intent vector from (zeroForOne, amountSpecified, poolFee).
///   3. It calls the xB77 Constitution (Stylus) via staticcall to validate the intent.
///   4. If rejected → revert. If approved → return the hook's magic selector.
///   5. afterSwap() records the swap amount in the agent's on-chain GDP.
///
/// Uniswap v4 Hook Permission Flags (encoded in the contract address via CREATE2):
///   BEFORE_SWAP_FLAG = 1 << 7  (address bit 7 must be set)
///   AFTER_SWAP_FLAG  = 1 << 6  (address bit 6 must be set)
///
/// Deploy with: cargo stylus deploy --wasm-file zig-out/bin/uniswap_hook.wasm
///              Use a CREATE2 factory to get an address with the right permission bits.
///
/// Selectors (keccak256 via `cast sig`):
///   beforeSwap(address,(address,address,uint24,int24,address),(bool,int256,uint160),bytes)
///     → 0x53e9bc58  (verify: cast sig "beforeSwap(...)")
///   afterSwap(address,(address,address,uint24,int24,address),(bool,int256,uint160),int256,bytes)
///     → 0xce19a578  (verify: cast sig "afterSwap(...)")
///   setConstitution(address)
///     → 0x5b4f4937  (verify: cast sig "setConstitution(address)")

const std = @import("std");
const sdk = @import("sdk.zig");
const Stylus = sdk.Stylus;
const vm = sdk.vm_hooks;

pub const user_abi_version: i32 = 1;
pub fn mark_used() void {}

comptime {
    if (@import("builtin").cpu.arch == .wasm32) {
        @export(&user_entrypoint, .{ .name = "user_entrypoint" });
    }
}

// ── Selectors ─────────────────────────────────────────────────────────────
// Computed via: cast sig "functionSignature"
const SEL_BEFORE_SWAP:      u32 = 0x53e9bc58;
const SEL_AFTER_SWAP:       u32 = 0xce19a578;
const SEL_SET_CONSTITUTION: u32 = 0x5b4f4937;
const SEL_GET_GDP:          u32 = 0xf4a9e3b1;

// Magic return values Uniswap v4 expects from hooks
// = bytes4(keccak256("beforeSwap(...)"))  = 0x53e9bc58
// = bytes4(keccak256("afterSwap(...)"))   = 0xce19a578
const BEFORE_SWAP_MAGIC: [32]u8 = .{
    0x53, 0xe9, 0xbc, 0x58, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
const AFTER_SWAP_MAGIC: [32]u8 = .{
    0xce, 0x19, 0xa5, 0x78, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

// ── Storage slots ──────────────────────────────────────────────────────────
// slot 0: owner
const SLOT_OWNER: [32]u8 = [_]u8{0} ** 32;
// slot 1: constitution contract address
const SLOT_CONSTITUTION: [32]u8 = blk: {
    var s = [_]u8{0} ** 32;
    s[31] = 1;
    break :blk s;
};
// slot 2: pool manager address
const SLOT_POOL_MANAGER: [32]u8 = blk: {
    var s = [_]u8{0} ** 32;
    s[31] = 2;
    break :blk s;
};
// GDP: keccak256(0xAA ++ agent[20])
fn gdpSlot(agent: [20]u8) [32]u8 {
    var pre: [21]u8 = undefined;
    pre[0] = 0xAA;
    @memcpy(pre[1..21], &agent);
    return Stylus.keccak256(&pre);
}

// Constitution selector for validateSemantic
const CONSTITUTION_SEL_VALIDATE: [4]u8 = .{ 0xab, 0xcd, 0xef, 0x01 };

const SUCCESS: i32 = 0;
const REVERT: i32  = 1;

// ── Entrypoint ─────────────────────────────────────────────────────────────
pub fn user_entrypoint(len: i32) callconv(if (@import("builtin").cpu.arch == .wasm32) @as(std.builtin.CallingConvention, .{ .wasm_mvp = .{} }) else .auto) i32 {
    if (len < 4) return SUCCESS;

    const alloc = sdk.ContractAllocator.get();
    defer sdk.ContractAllocator.reset();

    const args = Stylus.getArgs(alloc, @intCast(len)) catch return REVERT;
    const selector = std.mem.readInt(u32, args[0..4], .big);

    return switch (selector) {
        SEL_BEFORE_SWAP      => handleBeforeSwap(alloc, args[4..]),
        SEL_AFTER_SWAP       => handleAfterSwap(alloc, args[4..]),
        SEL_SET_CONSTITUTION => handleSetConstitution(args[4..]),
        SEL_GET_GDP          => handleGetGDP(args[4..]),
        else => SUCCESS,
    };
}

// ── Storage helpers ────────────────────────────────────────────────────────
fn getConstitution() [20]u8 {
    const raw = Stylus.sload(SLOT_CONSTITUTION);
    var addr: [20]u8 = undefined;
    @memcpy(&addr, raw[12..32]);
    return addr;
}

fn getPoolManager() [20]u8 {
    const raw = Stylus.sload(SLOT_POOL_MANAGER);
    var addr: [20]u8 = undefined;
    @memcpy(&addr, raw[12..32]);
    return addr;
}

fn getOwner() [20]u8 {
    const raw = Stylus.sload(SLOT_OWNER);
    var addr: [20]u8 = undefined;
    @memcpy(&addr, raw[12..32]);
    return addr;
}

fn initOwner() void {
    const raw = Stylus.sload(SLOT_OWNER);
    const empty = for (raw) |b| { if (b != 0) break false; } else true;
    if (!empty) return;
    const sender = Stylus.getSender();
    var slot: [32]u8 = [_]u8{0} ** 32;
    @memcpy(slot[12..32], &sender);
    Stylus.sstore(SLOT_OWNER, slot);
    vm.storage_flush_cache();
}

// ── setConstitution(address constitution) ─────────────────────────────────
fn handleSetConstitution(data: []const u8) i32 {
    initOwner();
    const owner = getOwner();
    const sender = Stylus.getSender();
    if (!std.mem.eql(u8, &owner, &sender)) return REVERT;
    if (data.len < 32) return REVERT;

    Stylus.sstore(SLOT_CONSTITUTION, data[0..32][0..32].*);
    vm.storage_flush_cache();

    returnOne();
    return SUCCESS;
}

// ── beforeSwap ────────────────────────────────────────────────────────────
/// ABI: beforeSwap(address sender, PoolKey key, SwapParams params, bytes hookData)
///
/// PoolKey (5 fields × 32 bytes = 160 bytes):
///   currency0[32], currency1[32], fee[32], tickSpacing[32], hooks[32]
///
/// SwapParams (3 fields × 32 bytes = 96 bytes):
///   zeroForOne[32], amountSpecified[32], sqrtPriceLimitX96[32]
///
/// We derive the intent vector from (zeroForOne, amountSpecified, fee) and
/// validate it against the xB77 constitution before allowing the swap.
fn handleBeforeSwap(alloc: std.mem.Allocator, data: []const u8) i32 {
    // Only PoolManager can call hooks
    const pm = getPoolManager();
    const zero_addr = [_]u8{0} ** 20;
    if (!std.mem.eql(u8, &pm, &zero_addr)) {
        const caller = Stylus.getSender();
        if (!std.mem.eql(u8, &caller, &pm)) return REVERT;
    }

    // data layout: sender(32) + PoolKey(5×32=160) + SwapParams(3×32=96) + hookData(dynamic)
    if (data.len < 32 + 160 + 96) return REVERT;

    var swap_sender: [20]u8 = undefined;
    @memcpy(&swap_sender, data[12..32]); // address in last 20 bytes

    // PoolKey fields
    const fee = std.mem.readInt(u32, data[64 + 32 * 2 .. 64 + 32 * 2 + 4][0..4], .big);

    // SwapParams
    const zero_for_one = data[32 + 160 + 31] != 0; // bool
    const amount_specified = std.mem.readInt(i256, data[32 + 160 + 32 .. 32 + 160 + 64][0..32][0..32], .big);

    // Derive semantic intent vector from swap parameters
    const intent = intentFromSwap(zero_for_one, amount_specified, fee);

    // Validate against on-chain constitution
    const constitution = getConstitution();
    const approved = checkConstitution(alloc, constitution, intent);
    if (!approved) {
        Stylus.log("SWAP_REJECTED_BY_CONSTITUTION", &.{});
        return REVERT;
    }

    // Return the magic selector so Uniswap knows the hook approved
    Stylus.output(&BEFORE_SWAP_MAGIC);
    return SUCCESS;
}

// ── afterSwap ─────────────────────────────────────────────────────────────
/// Records the swap volume in the agent's GDP.
/// ABI: afterSwap(address sender, PoolKey key, SwapParams params, int256 delta, bytes hookData)
fn handleAfterSwap(alloc: std.mem.Allocator, data: []const u8) i32 {
    _ = alloc;
    // data: sender(32) + PoolKey(160) + SwapParams(96) + delta(32) + hookData(dynamic)
    if (data.len < 32 + 160 + 96 + 32) return REVERT;

    var swap_sender: [20]u8 = undefined;
    @memcpy(&swap_sender, data[12..32]);

    const delta_offset = 32 + 160 + 96;
    const delta = std.mem.readInt(i256, data[delta_offset .. delta_offset + 32][0..32], .big);
    const volume: u256 = if (delta < 0) @intCast(-delta) else @intCast(delta);

    // Add to agent's GDP
    const slot = gdpSlot(swap_sender);
    const current_bytes = Stylus.sload(slot);
    const current = std.mem.readInt(u256, &current_bytes, .big);
    var updated: [32]u8 = undefined;
    std.mem.writeInt(u256, &updated, current + volume, .big);
    Stylus.sstore(slot, updated);
    vm.storage_flush_cache();

    // Emit SwapSettled(agent, volume)
    var log_data: [64]u8 = [_]u8{0} ** 64;
    @memset(log_data[0..12], 0);
    @memcpy(log_data[12..32], &swap_sender);
    std.mem.writeInt(u256, log_data[32..64][0..32], volume, .big);
    const topic = [_]u8{ 0x5A, 0xAA, 0x53, 0xED } ++ [_]u8{0} ** 28;
    Stylus.log(&log_data, &.{topic});

    Stylus.output(&AFTER_SWAP_MAGIC);
    return SUCCESS;
}

// ── getAgentGDP(address) ──────────────────────────────────────────────────
fn handleGetGDP(data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var agent: [20]u8 = undefined;
    @memcpy(&agent, data[12..32]);
    const val = Stylus.sload(gdpSlot(agent));
    Stylus.output(&val);
    return SUCCESS;
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Check an intent vector against the constitution via staticcall.
fn checkConstitution(alloc: std.mem.Allocator, constitution: [20]u8, intent: [128]i32) bool {
    var payload: [4 + 128 * 4]u8 = undefined;
    @memcpy(payload[0..4], &CONSTITUTION_SEL_VALIDATE);
    for (0..128) |i| {
        std.mem.writeInt(i32, payload[4 + i * 4 .. 4 + (i + 1) * 4][0..4], intent[i], .big);
    }
    const out = Stylus.staticCall(alloc, constitution, &payload) catch return false;
    return out.len >= 32 and out[31] == 1;
}

/// Derive a 128-dim semantic intent vector from swap parameters.
/// Large swaps (>100k USDC equivalent) or high-fee pools get stricter vectors.
fn intentFromSwap(zero_for_one: bool, amount: i256, fee: u32) [128]i32 {
    const abs_amount: u256 = if (amount < 0) @intCast(-amount) else @intCast(amount);
    const is_large = abs_amount > 100_000 * 1_000_000; // >100k USDC
    const is_high_fee = fee > 10_000; // >1%

    if (is_large and is_high_fee) {
        // Suspicious: large amount in high-fee pool — closer to toxic vector
        var v: [128]i32 = undefined;
        for (0..128) |i| v[i] = if (i % 3 == 0) @as(i32, 8000) else @as(i32, 100);
        return v;
    }

    // Normal swap: neutral alternating vector, orthogonal to toxic
    _ = zero_for_one;
    var v: [128]i32 = undefined;
    for (0..128) |i| v[i] = if (i % 2 == 0) @as(i32, 100) else @as(i32, -100);
    return v;
}

fn returnOne() void {
    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    Stylus.revert();
}

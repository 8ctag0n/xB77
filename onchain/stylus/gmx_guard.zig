/// xB77 GMX v2 Sovereign Guard — Arbitrum Stylus (Zig)
///
/// Wraps GMX v2 position creation with semantic constitution validation.
/// Prevents agents from opening leveraged positions without passing the
/// on-chain Stylus constitution check.
///
/// Architecture:
///   Agent → GMXGuard.createOrder() → Constitution check (leverage + size)
///         → GMX ExchangeRouter.createOrder()
///
/// Key insight: GMX v2 uses an order-based system. All position changes
/// go through createOrder(). The guard validates BEFORE the order is placed.
///
/// Deployed addresses (Arbitrum Sepolia):
///   GMX ExchangeRouter:  0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8
///   GMX OrderVault:      0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5
///   USDC (collateral):   0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
///
/// Selectors:
///   0x2e84a0d6 → createLong(address,uint256,uint256,bytes32)   [xB77 wrapper]
///   0x8f4c3a91 → createShort(address,uint256,uint256,bytes32)  [xB77 wrapper]
///   0x4e2e7a05 → cancelOrder(bytes32)                          [passthrough]
///   0x5b4f4937 → setConstitution(address)
///   0xf4a9e3b1 → getAgentGDP(address)
///   0x9c1a2b3d → getMaxLeverage()

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

// ── Deployed addresses ─────────────────────────────────────────────────────
const GMX_ROUTER: [20]u8 = .{
    0x7C, 0x68, 0xC7, 0x86, 0x6A, 0x64, 0xFA, 0x21, 0x60, 0xF7,
    0x8E, 0xEa, 0xE1, 0x22, 0x17, 0xFF, 0xbf, 0x87, 0x1f, 0xa8,
};

// ── GMX v2 ExchangeRouter selector ────────────────────────────────────────
// cast sig "createOrder((address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,bool,uint256))"
// Simplified for demo — real GMX CreateOrderParams is a large struct
const GMX_SEL_CREATE_ORDER: [4]u8 = .{ 0x2e, 0x84, 0xa0, 0xd6 };
const GMX_SEL_CANCEL_ORDER: [4]u8 = .{ 0x4e, 0x2e, 0x7a, 0x05 };

// ── xB77 Guard selectors ───────────────────────────────────────────────────
const SEL_CREATE_LONG:      u32 = 0x2e84a0d6;
const SEL_CREATE_SHORT:     u32 = 0x8f4c3a91;
const SEL_CANCEL_ORDER:     u32 = 0x4e2e7a05;
const SEL_SET_CONSTITUTION: u32 = 0x5b4f4937;
const SEL_GET_GDP:          u32 = 0xf4a9e3b1;
const SEL_GET_MAX_LEVERAGE: u32 = 0x9c1a2b3d;

// ── Sovereign risk limits ─────────────────────────────────────────────────
/// Maximum leverage the constitution allows (in basis points, 100 = 1x)
const MAX_LEVERAGE_BPS: u32  = 2000; // 20x default — agents can override via setConstitution
const MAX_POSITION_USDC: u256 = 1_000_000 * 1_000_000; // 1M USDC max

// ── Storage layout ────────────────────────────────────────────────────────
const SLOT_OWNER: [32]u8        = [_]u8{0} ** 32;
const SLOT_CONSTITUTION: [32]u8 = blk: { var s = [_]u8{0} ** 32; s[31] = 1; break :blk s; };
const SLOT_MAX_LEVERAGE: [32]u8 = blk: { var s = [_]u8{0} ** 32; s[31] = 2; break :blk s; };

fn gdpSlot(agent: [20]u8) [32]u8 {
    var pre: [21]u8 = undefined; pre[0] = 0xBB;
    @memcpy(pre[1..21], &agent);
    return Stylus.keccak256(&pre);
}

// Open positions tracking: keccak256(0xBB ++ agent ++ order_key)
fn positionSlot(agent: [20]u8, order_key: [32]u8) [32]u8 {
    var pre: [53]u8 = undefined;
    pre[0] = 0xBC;
    @memcpy(pre[1..21], &agent);
    @memcpy(pre[21..53], &order_key);
    return Stylus.keccak256(&pre);
}

const CONSTITUTION_SEL: [4]u8  = .{ 0xab, 0xcd, 0xef, 0x01 };
const TOPIC_POSITION:   [32]u8 = .{ 0xB0, 0x51, 0x71, 0x00 } ++ [_]u8{0} ** 28;
const TOPIC_REJECTED:   [32]u8 = .{ 0x4E, 0xA1, 0x11, 0x04 } ++ [_]u8{0} ** 28;

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
        SEL_CREATE_LONG      => handleCreatePosition(alloc, args[4..], true),
        SEL_CREATE_SHORT     => handleCreatePosition(alloc, args[4..], false),
        SEL_CANCEL_ORDER     => handleCancelOrder(alloc, args[4..]),
        SEL_SET_CONSTITUTION => handleSetConstitution(args[4..]),
        SEL_GET_GDP          => handleGetGDP(args[4..]),
        SEL_GET_MAX_LEVERAGE => handleGetMaxLeverage(),
        else => SUCCESS,
    };
}

// ── Helpers ────────────────────────────────────────────────────────────────
fn getOwner() [20]u8 {
    const raw = Stylus.sload(SLOT_OWNER);
    var a: [20]u8 = undefined; @memcpy(&a, raw[12..32]); return a;
}
fn getConstitution() [20]u8 {
    const raw = Stylus.sload(SLOT_CONSTITUTION);
    var a: [20]u8 = undefined; @memcpy(&a, raw[12..32]); return a;
}
fn getMaxLeverage() u32 {
    const raw = Stylus.sload(SLOT_MAX_LEVERAGE);
    const val = std.mem.readInt(u256, &raw, .big);
    return if (val == 0) MAX_LEVERAGE_BPS else @intCast(val & 0xFFFFFFFF);
}
fn initOwner() void {
    const raw = Stylus.sload(SLOT_OWNER);
    const empty = for (raw) |b| { if (b != 0) break false; } else true;
    if (!empty) return;
    const sender = Stylus.getSender();
    var slot: [32]u8 = [_]u8{0} ** 32;
    @memcpy(slot[12..32], &sender);
    Stylus.sstore(SLOT_OWNER, slot);
    vm.storage_flush_cache(0);
}

fn handleSetConstitution(data: []const u8) i32 {
    initOwner();
    if (!std.mem.eql(u8, &getOwner(), &Stylus.getSender())) return REVERT;
    if (data.len < 32) return REVERT;
    Stylus.sstore(SLOT_CONSTITUTION, data[0..32][0..32].*);
    vm.storage_flush_cache(0);
    returnOne(); return SUCCESS;
}

fn checkConstitution(alloc: std.mem.Allocator, intent: [128]i32) bool {
    const constitution = getConstitution();
    const zero = [_]u8{0} ** 20;
    if (std.mem.eql(u8, &constitution, &zero)) return true;

    var payload: [4 + 512]u8 = undefined;
    @memcpy(payload[0..4], &CONSTITUTION_SEL);
    for (0..128) |i| {
        std.mem.writeInt(i32, payload[4 + i * 4 .. 4 + i * 4 + 4][0..4], intent[i], .big);
    }
    const out = Stylus.staticCall(alloc, constitution, &payload) catch return false;
    return out.len >= 32 and out[31] == 1;
}

/// Derive intent vector from a position: large leverage = riskier vector
fn positionIntent(size_usdc: u256, leverage_bps: u32, is_long: bool) [128]i32 {
    var v: [128]i32 = undefined;
    for (0..128) |i| v[i] = if (i % 2 == 0) @as(i32, 100) else @as(i32, -100);

    const leverage_factor: i32 = @intCast(@min(leverage_bps / 100, 100));
    const size_factor: i32 = if (size_usdc > 100_000 * 1_000_000) 50 else 10;

    // Higher leverage → vector closer to the risky quadrant (not necessarily toxic)
    for (0..32) |i| {
        v[i] = 100 + leverage_factor * size_factor;
        if (!is_long) v[i] = -v[i]; // shorts in the opposite quadrant
    }
    return v;
}

fn addGDP(agent: [20]u8, amount: u256) void {
    const slot = gdpSlot(agent);
    const current = std.mem.readInt(u256, &Stylus.sload(slot), .big);
    var updated: [32]u8 = undefined;
    std.mem.writeInt(u256, &updated, current + amount, .big);
    Stylus.sstore(slot, updated);
}

// ── createLong/Short(address market, uint256 sizeUSD, uint256 leverageBps, bytes32 nonce) ──
fn handleCreatePosition(alloc: std.mem.Allocator, data: []const u8, is_long: bool) i32 {
    // data: market(32) + sizeUSD(32) + leverageBps(32) + nonce(32)
    if (data.len < 128) return REVERT;

    const size_usd     = std.mem.readInt(u256, data[32..64][0..32], .big);
    const leverage_bps = @as(u32, @intCast(std.mem.readInt(u256, data[64..96][0..32], .big) & 0xFFFFFFFF));
    var nonce: [32]u8  = undefined; @memcpy(&nonce, data[96..128]);

    // 1. Sovereign risk check: leverage must be within constitution limits
    const max_lev = getMaxLeverage();
    if (leverage_bps > max_lev) {
        Stylus.log("LEVERAGE_EXCEEDS_CONSTITUTION_LIMIT", &.{TOPIC_REJECTED});
        return REVERT;
    }

    // 2. Position size check
    if (size_usd > MAX_POSITION_USDC) {
        Stylus.log("POSITION_SIZE_EXCEEDS_LIMIT", &.{TOPIC_REJECTED});
        return REVERT;
    }

    // 3. Semantic intent check
    const intent = positionIntent(size_usd, leverage_bps, is_long);
    if (!checkConstitution(alloc, intent)) {
        Stylus.log("POSITION_REJECTED_BY_CONSTITUTION", &.{TOPIC_REJECTED});
        return REVERT;
    }

    // 4. Forward to GMX ExchangeRouter
    // Build a simplified CreateOrderParams (real GMX has a complex struct)
    var market: [20]u8 = undefined; @memcpy(&market, data[12..32]);
    const agent = Stylus.getSender();

    var cd: [4 + 6 * 32]u8 = undefined;
    @memcpy(cd[0..4], &GMX_SEL_CREATE_ORDER);
    @memset(cd[4..16], 0);    @memcpy(cd[16..36], &agent);  // account
    @memset(cd[36..48], 0);   @memcpy(cd[48..68], &market); // market
    @memcpy(cd[68..100], data[32..64]);  // sizeUSD
    @memcpy(cd[100..132], data[64..96]); // leverageBps
    cd[163] = if (is_long) 1 else 0;    // isLong
    @memcpy(cd[164..196], &nonce);       // nonce / referenceKey

    _ = Stylus.callContract(alloc, GMX_ROUTER, 0, &cd) catch return REVERT;

    // Record in GDP and emit event
    addGDP(agent, size_usd / leverage_bps * 100); // notional collateral
    vm.storage_flush_cache(0);

    var log: [96]u8 = [_]u8{0} ** 96;
    @memset(log[0..12], 0); @memcpy(log[12..32], &agent);
    std.mem.writeInt(u256, log[32..64][0..32], size_usd, .big);
    log[95] = if (is_long) 1 else 0;
    Stylus.log(&log, &.{TOPIC_POSITION});

    returnOne();
    return SUCCESS;
}

// ── cancelOrder(bytes32 key) ───────────────────────────────────────────────
fn handleCancelOrder(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var cd: [4 + 32]u8 = undefined;
    @memcpy(cd[0..4], &GMX_SEL_CANCEL_ORDER);
    @memcpy(cd[4..36], data[0..32]);
    _ = Stylus.callContract(alloc, GMX_ROUTER, 0, &cd) catch return REVERT;
    returnOne(); return SUCCESS;
}

fn handleGetGDP(data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var agent: [20]u8 = undefined; @memcpy(&agent, data[12..32]);
    Stylus.output(&Stylus.sload(gdpSlot(agent)));
    return SUCCESS;
}

fn handleGetMaxLeverage() i32 {
    var out: [32]u8 = undefined;
    std.mem.writeInt(u256, &out, getMaxLeverage(), .big);
    Stylus.output(&out);
    return SUCCESS;
}

fn returnOne() void {
    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg; Stylus.revert();
}

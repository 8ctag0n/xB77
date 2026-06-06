/// xB77 Aave v3 Sovereign Guard — Arbitrum Stylus (Zig)
///
/// Wraps Aave v3 supply/borrow/flash loan actions with semantic constitution
/// validation. Agents can only interact with Aave if their intent vector
/// passes the on-chain Stylus constitution check.
///
/// Architecture:
///   Agent → AaveGuard.supply() → Constitution check → Aave Pool.supply()
///   Agent → AaveGuard.borrow() → Constitution check → Aave Pool.borrow()
///   Agent → AaveGuard.flashLoan() → Constitution check → Aave Pool.flashLoanSimple()
///
/// Deployed addresses (Arbitrum Sepolia):
///   Aave v3 Pool:      0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff
///   USDC:              0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
///   WETH:              0x980B62Da83eFf3D4576C647993b0c1D7faf17c73
///
/// Selectors:
///   0xa415bcad → supply(address,uint256,address,uint16)
///   0x573ade81 → repay(address,uint256,uint256,address)
///   0x69328dec → withdraw(address,uint256,address)
///   0xd65b7976 → borrow(address,uint256,uint256,uint16,address)
///   0x42b0b77c → flashLoan(address,uint256,bytes)      [xB77 wrapper]
///   0x5b4f4937 → setConstitution(address)
///   0xf4a9e3b1 → getAgentGDP(address)

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
// Aave v3 Pool on Arbitrum Sepolia
const AAVE_POOL: [20]u8 = .{
    0xBf, 0xC9, 0x1D, 0x59, 0xfd, 0xAA, 0x13, 0x4A, 0x4E, 0xD4,
    0x5f, 0x7B, 0x58, 0x4c, 0xAf, 0x96, 0xD7, 0x79, 0x2E, 0xFF,
};

// ── Aave v3 Pool function selectors ───────────────────────────────────────
// cast sig "supply(address,uint256,address,uint16)"
const AAVE_SEL_SUPPLY:      [4]u8 = .{ 0xa4, 0x15, 0xbc, 0xad };
// cast sig "borrow(address,uint256,uint256,uint16,address)"
const AAVE_SEL_BORROW:      [4]u8 = .{ 0xd6, 0x5b, 0x79, 0x76 };
// cast sig "repay(address,uint256,uint256,address)"
const AAVE_SEL_REPAY:       [4]u8 = .{ 0x57, 0x3a, 0xde, 0x81 };
// cast sig "withdraw(address,uint256,address)"
const AAVE_SEL_WITHDRAW:    [4]u8 = .{ 0x69, 0x32, 0x8d, 0xec };
// cast sig "flashLoanSimple(address,address,uint256,bytes,uint16)"
const AAVE_SEL_FLASH:       [4]u8 = .{ 0x42, 0xb0, 0xb7, 0x7c };

// ── xB77 Guard selectors ───────────────────────────────────────────────────
const SEL_SUPPLY:           u32 = 0xa415bcad;
const SEL_BORROW:           u32 = 0xd65b7976;
const SEL_REPAY:            u32 = 0x573ade81;
const SEL_WITHDRAW:         u32 = 0x69328dec;
const SEL_FLASH_LOAN:       u32 = 0x42b0b77c;
const SEL_SET_CONSTITUTION: u32 = 0x5b4f4937;
const SEL_GET_GDP:          u32 = 0xf4a9e3b1;

// ── Storage layout ────────────────────────────────────────────────────────
const SLOT_OWNER: [32]u8        = [_]u8{0} ** 32;
const SLOT_CONSTITUTION: [32]u8 = blk: { var s = [_]u8{0} ** 32; s[31] = 1; break :blk s; };

fn gdpSlot(agent: [20]u8) [32]u8 {
    var pre: [21]u8 = undefined; pre[0] = 0xAA;
    @memcpy(pre[1..21], &agent);
    return Stylus.keccak256(&pre);
}

// Constitution validate selector
const CONSTITUTION_SEL: [4]u8 = .{ 0xab, 0xcd, 0xef, 0x01 };

// Log topics
const TOPIC_SUPPLY:    [32]u8 = .{ 0xA5, 0xAA, 0x50, 0x01 } ++ [_]u8{0} ** 28;
const TOPIC_BORROW:    [32]u8 = .{ 0xB0, 0x4B, 0x01, 0x02 } ++ [_]u8{0} ** 28;
const TOPIC_FLASH:     [32]u8 = .{ 0xF1, 0xA5, 0x40, 0x03 } ++ [_]u8{0} ** 28;
const TOPIC_REJECTED:  [32]u8 = .{ 0x4E, 0xA1, 0x11, 0x04 } ++ [_]u8{0} ** 28;

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
        SEL_SUPPLY           => handleSupply(alloc, args[4..]),
        SEL_BORROW           => handleBorrow(alloc, args[4..]),
        SEL_REPAY            => handleRepay(alloc, args[4..]),
        SEL_WITHDRAW         => handleWithdraw(alloc, args[4..]),
        SEL_FLASH_LOAN       => handleFlashLoan(alloc, args[4..]),
        SEL_SET_CONSTITUTION => handleSetConstitution(args[4..]),
        SEL_GET_GDP          => handleGetGDP(args[4..]),
        else => SUCCESS,
    };
}

// ── Owner / constitution ───────────────────────────────────────────────────
fn getOwner() [20]u8 {
    const raw = Stylus.sload(SLOT_OWNER);
    var a: [20]u8 = undefined; @memcpy(&a, raw[12..32]); return a;
}
fn getConstitution() [20]u8 {
    const raw = Stylus.sload(SLOT_CONSTITUTION);
    var a: [20]u8 = undefined; @memcpy(&a, raw[12..32]); return a;
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
    returnOne();
    return SUCCESS;
}

// ── Constitution check ─────────────────────────────────────────────────────
fn checkConstitution(alloc: std.mem.Allocator, intent: [128]i32) bool {
    const constitution = getConstitution();
    const zero = [_]u8{0} ** 20;
    if (std.mem.eql(u8, &constitution, &zero)) return true; // no constitution = open

    var payload: [4 + 512]u8 = undefined;
    @memcpy(payload[0..4], &CONSTITUTION_SEL);
    for (0..128) |i| {
        std.mem.writeInt(i32, payload[4 + i * 4 .. 4 + i * 4 + 4][0..4], intent[i], .big);
    }
    const out = Stylus.staticCall(alloc, constitution, &payload) catch return false;
    return out.len >= 32 and out[31] == 1;
}

fn neutralIntent() [128]i32 {
    var v: [128]i32 = undefined;
    for (0..128) |i| v[i] = if (i % 2 == 0) @as(i32, 100) else @as(i32, -100);
    return v;
}

fn borrowIntent(amount: u256, rate_mode: u256) [128]i32 {
    // High leverage borrow (variable rate, large amount) → higher risk vector
    const is_large    = amount > 500_000 * 1_000_000; // >500k USDC
    const is_variable = rate_mode == 2;
    var v: [128]i32 = neutralIntent();
    if (is_large and is_variable) {
        // Shift toward riskier quadrant (but not toxic)
        for (0..32) |i| v[i] = 4000;
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

// ── supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) ──
fn handleSupply(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 128) return REVERT;
    const amount = std.mem.readInt(u256, data[32..64][0..32], .big);

    const intent = neutralIntent();
    if (!checkConstitution(alloc, intent)) {
        Stylus.log("SUPPLY_REJECTED", &.{TOPIC_REJECTED});
        return REVERT;
    }

    // Forward to Aave Pool
    var cd: [4 + 128]u8 = undefined;
    @memcpy(cd[0..4], &AAVE_SEL_SUPPLY);
    @memcpy(cd[4..132], data[0..128]);
    _ = Stylus.callContract(alloc, AAVE_POOL, 0, &cd) catch return REVERT;

    const agent = Stylus.getSender();
    addGDP(agent, amount);
    vm.storage_flush_cache(0);

    var log: [64]u8 = [_]u8{0} ** 64;
    @memset(log[0..12], 0); @memcpy(log[12..32], &agent);
    std.mem.writeInt(u256, log[32..64][0..32], amount, .big);
    Stylus.log(&log, &.{TOPIC_SUPPLY});

    returnOne();
    return SUCCESS;
}

// ── borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referral, address onBehalfOf) ──
fn handleBorrow(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 160) return REVERT;
    const amount    = std.mem.readInt(u256, data[32..64][0..32], .big);
    const rate_mode = std.mem.readInt(u256, data[64..96][0..32], .big);

    const intent = borrowIntent(amount, rate_mode);
    if (!checkConstitution(alloc, intent)) {
        Stylus.log("BORROW_REJECTED", &.{TOPIC_REJECTED});
        return REVERT;
    }

    var cd: [4 + 160]u8 = undefined;
    @memcpy(cd[0..4], &AAVE_SEL_BORROW);
    @memcpy(cd[4..164], data[0..160]);
    _ = Stylus.callContract(alloc, AAVE_POOL, 0, &cd) catch return REVERT;

    const agent = Stylus.getSender();
    addGDP(agent, amount);
    vm.storage_flush_cache(0);

    var log: [64]u8 = [_]u8{0} ** 64;
    @memset(log[0..12], 0); @memcpy(log[12..32], &agent);
    std.mem.writeInt(u256, log[32..64][0..32], amount, .big);
    Stylus.log(&log, &.{TOPIC_BORROW});

    returnOne();
    return SUCCESS;
}

// ── repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) ──
fn handleRepay(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 128) return REVERT;

    // Repaying is always safe — no constitution check needed
    var cd: [4 + 128]u8 = undefined;
    @memcpy(cd[0..4], &AAVE_SEL_REPAY);
    @memcpy(cd[4..132], data[0..128]);
    _ = Stylus.callContract(alloc, AAVE_POOL, 0, &cd) catch return REVERT;

    returnOne();
    return SUCCESS;
}

// ── withdraw(address asset, uint256 amount, address to) ─────────────────────
fn handleWithdraw(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 96) return REVERT;

    const intent = neutralIntent();
    if (!checkConstitution(alloc, intent)) return REVERT;

    var cd: [4 + 96]u8 = undefined;
    @memcpy(cd[0..4], &AAVE_SEL_WITHDRAW);
    @memcpy(cd[4..100], data[0..96]);
    _ = Stylus.callContract(alloc, AAVE_POOL, 0, &cd) catch return REVERT;

    returnOne();
    return SUCCESS;
}

// ── flashLoan(address asset, uint256 amount, bytes params) ──────────────────
/// Sovereign flash loan: constitution validates BEFORE Aave releases funds.
/// This prevents agents from using flash loans for sandwich attacks or manipulation.
fn handleFlashLoan(alloc: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 96) return REVERT;

    const amount = std.mem.readInt(u256, data[32..64][0..32], .big);

    // Flash loans get a stricter intent check — large capital, risky action
    const is_massive = amount > 10_000_000 * 1_000_000; // >10M USDC
    var intent = neutralIntent();
    if (is_massive) {
        // Shift toward suspicious quadrant for massive flash loans
        for (0..64) |i| intent[i] = 5000;
    }

    if (!checkConstitution(alloc, intent)) {
        Stylus.log("FLASH_LOAN_REJECTED", &.{TOPIC_REJECTED});
        return REVERT;
    }

    // flashLoanSimple(receiverAddress, asset, amount, params, referralCode)
    const self = Stylus.getSelf();
    var asset: [20]u8 = undefined;
    @memcpy(&asset, data[12..32]);

    var cd: [4 + 5 * 32]u8 = undefined;
    @memcpy(cd[0..4], &AAVE_SEL_FLASH);
    // receiverAddress = this contract (callback comes back here)
    @memset(cd[4..16], 0); @memcpy(cd[16..36], &self);
    @memcpy(cd[36..68], data[0..32]); // asset
    @memcpy(cd[68..100], data[32..64]); // amount
    @memset(cd[100..164], 0); // params offset + referralCode

    _ = Stylus.callContract(alloc, AAVE_POOL, 0, &cd) catch return REVERT;

    const agent = Stylus.getSender();
    addGDP(agent, amount);
    vm.storage_flush_cache(0);

    var log: [64]u8 = [_]u8{0} ** 64;
    @memset(log[0..12], 0); @memcpy(log[12..32], &agent);
    std.mem.writeInt(u256, log[32..64][0..32], amount, .big);
    Stylus.log(&log, &.{TOPIC_FLASH});

    returnOne();
    return SUCCESS;
}

// ── getAgentGDP(address) ──────────────────────────────────────────────────
fn handleGetGDP(data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var agent: [20]u8 = undefined; @memcpy(&agent, data[12..32]);
    Stylus.output(&Stylus.sload(gdpSlot(agent)));
    return SUCCESS;
}

fn returnOne() void {
    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg; Stylus.revert();
}

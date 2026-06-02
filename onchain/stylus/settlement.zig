const std = @import("std");
const sdk = @import("sdk.zig");
const Stylus = sdk.Stylus;
const vm = sdk.vm_hooks;

/// xB77 Sovereign Settlement — Arbitrum Stylus (Zig)
///
/// Settles autonomous agent missions in USDC on Arbitrum.
/// Full Stylus implementation: gas-optimized, native ERC-20 calls,
/// Circle CCTP V2 hook, and xB77 cross-chain settlement (Solana/Sui/Arc).
///
/// Storage layout:
///   slot keccak(0xA0 ++ agent[20])          : total USDC settled by agent (uint256)
///   slot keccak(0xCC ++ chainId ++ agentId) : cross-chain GDP (chain, agentId)
///   slot SLOT_OWNER                          : owner address (bytes20 in bytes32)
///
/// Selectors:
///   0xd8bff5a5 → settle(uint256,bytes32)
///   0x12345678 → batchSettle(uint256[],bytes32[])
///   0xabcd1234 → settleFromChain(uint8,bytes32,address,uint256,bytes32)
///   0x98765432 → handleReceiveMessage(uint32,bytes32,bytes)   [CCTP V2]
///   0xf4a9e3b1 → getAgentGDP(address)
///   0xe5b8d2c3 → getCrossChainGDP(uint8,bytes32)
///   0xc7f3a8d4 → withdrawTreasury(uint256)
///   0x9b2e4f67 → fastBalanceOf(address)

pub const user_abi_version: i32 = 1;
pub fn mark_used() void {}

comptime {
    if (@import("builtin").cpu.arch == .wasm32) {
        @export(&user_entrypoint, .{ .name = "user_entrypoint" });
    }
}

// ── Token addresses (Arbitrum Sepolia) ────────────────────────────────────
// USDC: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
const USDC: [20]u8 = .{
    0x75, 0xfa, 0xf1, 0x14, 0xea, 0xfb, 0x1b, 0xdb, 0xe2, 0xf0,
    0x31, 0x6d, 0xf8, 0x93, 0xfd, 0x58, 0xce, 0x46, 0xaa, 0x4d,
};
// Circle TokenMessenger: 0xaCF1ceeF35caAc005e15888dDb8A3515C41B4872
const CIRCLE_TOKEN_MESSENGER: [20]u8 = .{
    0xac, 0xf1, 0xce, 0xef, 0x35, 0xca, 0xac, 0x00, 0x5e, 0x15,
    0x88, 0x8d, 0xdb, 0x8a, 0x35, 0x15, 0xc4, 0x1b, 0x48, 0x72,
};

// ── Selectors ─────────────────────────────────────────────────────────────
const SEL_SETTLE: u32            = 0xd8bff5a5;
const SEL_BATCH_SETTLE: u32      = 0x12345678;
const SEL_SETTLE_FROM_CHAIN: u32 = 0xabcd1234;
const SEL_HANDLE_CCTP: u32       = 0x98765432;
const SEL_GET_AGENT_GDP: u32     = 0xf4a9e3b1;
const SEL_GET_XCHAIN_GDP: u32    = 0xe5b8d2c3;
const SEL_WITHDRAW_TREASURY: u32 = 0xc7f3a8d4;
const SEL_FAST_BALANCE: u32      = 0x9b2e4f67;

// ── Log topics ────────────────────────────────────────────────────────────
const TOPIC_SETTLED: [32]u8 = .{
    0xE1, 0xD7, 0x71, 0xED, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
const TOPIC_CROSS_CHAIN: [32]u8 = .{
    0xCC, 0x7E, 0x83, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
const TOPIC_BATCH: [32]u8 = .{
    0xBA, 0x7C, 0x43, 0x21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
const TOPIC_CCTP: [32]u8 = .{
    0xCB, 0xCC, 0x42, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,    0,    0,    0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const SLOT_OWNER: [32]u8 = .{
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
};

const SUCCESS: i32 = 0;
const REVERT: i32  = 1;

// ── Entrypoint ─────────────────────────────────────────────────────────────
pub fn user_entrypoint(len: i32) callconv(if (@import("builtin").cpu.arch == .wasm32) @as(std.builtin.CallingConvention, .{ .wasm_mvp = .{} }) else .auto) i32 {
    if (len < 4) return SUCCESS;

    const allocator = sdk.ContractAllocator.get();
    defer sdk.ContractAllocator.reset();

    const args = Stylus.getArgs(allocator, @intCast(len)) catch return REVERT;
    const selector = std.mem.readInt(u32, args[0..4], .big);

    return switch (selector) {
        SEL_SETTLE            => handleSettle(allocator, args[4..]),
        SEL_BATCH_SETTLE      => handleBatchSettle(allocator, args[4..]),
        SEL_SETTLE_FROM_CHAIN => handleSettleFromChain(allocator, args[4..]),
        SEL_HANDLE_CCTP       => handleCCTP(args[4..]),
        SEL_GET_AGENT_GDP     => handleGetAgentGDP(args[4..]),
        SEL_GET_XCHAIN_GDP    => handleGetCrossChainGDP(args[4..]),
        SEL_WITHDRAW_TREASURY => handleWithdrawTreasury(allocator, args[4..]),
        SEL_FAST_BALANCE      => handleFastBalance(allocator, args[4..]),
        else => SUCCESS,
    };
}

// ── Owner ──────────────────────────────────────────────────────────────────
fn getOwner() [20]u8 {
    const raw = Stylus.sload(SLOT_OWNER);
    var addr: [20]u8 = undefined;
    @memcpy(&addr, raw[12..32]);
    return addr;
}

fn initOwner() void {
    const raw = Stylus.sload(SLOT_OWNER);
    const is_zero = for (raw) |b| { if (b != 0) break false; } else true;
    if (!is_zero) return;
    const sender = Stylus.getSender();
    var slot: [32]u8 = [_]u8{0} ** 32;
    @memcpy(slot[12..32], &sender);
    Stylus.sstore(SLOT_OWNER, slot);
    vm.storage_flush_cache();
}

fn isOwner() bool {
    return std.mem.eql(u8, &getOwner(), &Stylus.getSender());
}

// ── GDP accounting ──────────────────────────────────────────────────────────
fn agentSlot(agent: [20]u8) [32]u8 {
    var pre: [21]u8 = undefined;
    pre[0] = 0xA0;
    @memcpy(pre[1..21], &agent);
    return Stylus.keccak256(&pre);
}

fn crossChainSlot(chain_id: u8, agent_id: [32]u8) [32]u8 {
    var pre: [34]u8 = undefined;
    pre[0] = 0xCC;
    pre[1] = chain_id;
    @memcpy(pre[2..34], &agent_id);
    return Stylus.keccak256(&pre);
}

fn addGDP(slot: [32]u8, amount: u256) void {
    const raw = Stylus.sload(slot);
    const current = std.mem.readInt(u256, &raw, .big);
    var updated: [32]u8 = undefined;
    std.mem.writeInt(u256, &updated, current + amount, .big);
    Stylus.sstore(slot, updated);
}

// ── settle(uint256 amount, bytes32 commitment) ─────────────────────────────
fn handleSettle(allocator: std.mem.Allocator, data: []const u8) i32 {
    initOwner();
    if (data.len < 64) return REVERT;

    const amount = std.mem.readInt(u256, data[0..32][0..32], .big);
    if (amount == 0) return REVERT;
    var commitment: [32]u8 = undefined;
    @memcpy(&commitment, data[32..64]);

    const sender = Stylus.getSender();
    const ok = Stylus.erc20TransferFrom(allocator, USDC, sender, sender, amount) catch return REVERT;
    if (!ok) return REVERT;

    addGDP(agentSlot(sender), amount);
    vm.storage_flush_cache();

    emitSettled(sender, amount, commitment);
    returnOne();
    return SUCCESS;
}

// ── batchSettle(uint256[] amounts, bytes32[] commitments) ──────────────────
fn handleBatchSettle(allocator: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 64) return REVERT;

    // ABI dynamic arrays: two offsets then the arrays
    const off_a: usize = @intCast(std.mem.readInt(u256, data[0..32][0..32], .big));
    const off_c: usize = @intCast(std.mem.readInt(u256, data[32..64][0..32], .big));
    if (data.len < off_a + 32 or data.len < off_c + 32) return REVERT;

    const count: usize = @intCast(std.mem.readInt(u256, data[off_a..][0..32][0..32], .big));
    const count_c: usize = @intCast(std.mem.readInt(u256, data[off_c..][0..32][0..32], .big));
    if (count != count_c or count == 0) return REVERT;

    const base_a = off_a + 32;
    const base_c = off_c + 32;
    if (data.len < base_a + count * 32 or data.len < base_c + count * 32) return REVERT;

    var total: u256 = 0;
    for (0..count) |i| {
        const amt = std.mem.readInt(u256, data[base_a + i * 32 ..][0..32][0..32], .big);
        if (amt == 0) return REVERT;
        total += amt;
    }

    const sender = Stylus.getSender();
    const ok = Stylus.erc20TransferFrom(allocator, USDC, sender, sender, total) catch return REVERT;
    if (!ok) return REVERT;

    addGDP(agentSlot(sender), total);

    for (0..count) |i| {
        const amt = std.mem.readInt(u256, data[base_a + i * 32 ..][0..32][0..32], .big);
        var com: [32]u8 = undefined;
        @memcpy(&com, data[base_c + i * 32 ..][0..32]);
        emitSettled(sender, amt, com);
    }

    // BatchSettled(sender, count, total)
    var log: [96]u8 = [_]u8{0} ** 96;
    @memset(log[0..12], 0);
    @memcpy(log[12..32], &sender);
    std.mem.writeInt(u256, log[32..64][0..32], @intCast(count), .big);
    std.mem.writeInt(u256, log[64..96][0..32], total, .big);
    Stylus.log(&log, &.{TOPIC_BATCH});

    vm.storage_flush_cache();
    returnOne();
    return SUCCESS;
}

// ── settleFromChain(uint8,bytes32,address,uint256,bytes32) ─────────────────
fn handleSettleFromChain(allocator: std.mem.Allocator, data: []const u8) i32 {
    // ABI layout: uint8(32) + bytes32(32) + address(32) + uint256(32) + bytes32(32)
    if (data.len < 160) return REVERT;

    const chain_id: u8    = data[31];
    var agent_id: [32]u8  = undefined; @memcpy(&agent_id,      data[32..64]);
    var arb_agent: [20]u8 = undefined; @memcpy(&arb_agent,     data[76..96]); // last 20 of padded address
    const amount           = std.mem.readInt(u256, data[96..128][0..32],  .big);
    var commitment: [32]u8 = undefined; @memcpy(&commitment,   data[128..160]);

    if (amount == 0) return REVERT;

    const sender = Stylus.getSender();
    const ok = Stylus.erc20TransferFrom(allocator, USDC, sender, sender, amount) catch return REVERT;
    if (!ok) return REVERT;

    addGDP(agentSlot(arb_agent),                 amount);
    addGDP(crossChainSlot(chain_id, agent_id),   amount);
    vm.storage_flush_cache();

    // CrossChainSettlement(sourceChain, agentId, arbitrumAgent, amount)
    var xlog: [128]u8 = [_]u8{0} ** 128;
    xlog[31] = chain_id;
    @memcpy(xlog[32..64],  &agent_id);
    @memset(xlog[64..76],  0); @memcpy(xlog[76..96], &arb_agent);
    std.mem.writeInt(u256, xlog[96..128][0..32], amount, .big);
    Stylus.log(&xlog, &.{TOPIC_CROSS_CHAIN});

    emitSettled(arb_agent, amount, commitment);
    returnOne();
    return SUCCESS;
}

// ── handleReceiveMessage(uint32,bytes32,bytes) — CCTP V2 hook ──────────────
fn handleCCTP(data: []const u8) i32 {
    // Only Circle TokenMessenger can call this
    if (!std.mem.eql(u8, &Stylus.getSender(), &CIRCLE_TOKEN_MESSENGER)) return REVERT;
    if (data.len < 96) return REVERT;

    // Skip sourceDomain[0..32] and cctp_sender[32..64]; body at dynamic offset
    const body_off: usize = @intCast(std.mem.readInt(u256, data[64..96][0..32], .big));
    if (data.len < body_off + 84) return REVERT;

    // messageBody: agent(20) + commitment(32) + amount(32)
    var agent: [20]u8 = undefined; @memcpy(&agent,      data[body_off .. body_off + 20]);
    var com: [32]u8   = undefined; @memcpy(&com,        data[body_off + 20 .. body_off + 52]);
    const amount = std.mem.readInt(u256, data[body_off + 52 .. body_off + 84][0..32], .big);

    addGDP(agentSlot(agent), amount);
    vm.storage_flush_cache();

    emitSettled(agent, amount, com);

    // CCTPSettlement topic
    var clog: [32]u8 = [_]u8{0} ** 32;
    std.mem.writeInt(u256, &clog, amount, .big);
    Stylus.log(&clog, &.{ TOPIC_CCTP, TOPIC_SETTLED });

    returnOne();
    return SUCCESS;
}

// ── getAgentGDP(address) returns (uint256) ─────────────────────────────────
fn handleGetAgentGDP(data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var agent: [20]u8 = undefined;
    @memcpy(&agent, data[12..32]);
    const val = Stylus.sload(agentSlot(agent));
    Stylus.output(&val);
    return SUCCESS;
}

// ── getCrossChainGDP(uint8,bytes32) returns (uint256) ──────────────────────
fn handleGetCrossChainGDP(data: []const u8) i32 {
    if (data.len < 64) return REVERT;
    const chain_id: u8 = data[31];
    var agent_id: [32]u8 = undefined;
    @memcpy(&agent_id, data[32..64]);
    const val = Stylus.sload(crossChainSlot(chain_id, agent_id));
    Stylus.output(&val);
    return SUCCESS;
}

// ── withdrawTreasury(uint256) — owner only ─────────────────────────────────
fn handleWithdrawTreasury(allocator: std.mem.Allocator, data: []const u8) i32 {
    initOwner();
    if (!isOwner()) return REVERT;
    if (data.len < 32) return REVERT;

    const amount = std.mem.readInt(u256, data[0..32][0..32], .big);
    const owner  = getOwner();
    const ok = Stylus.erc20Transfer(allocator, USDC, owner, amount) catch return REVERT;
    if (!ok) return REVERT;

    returnOne();
    return SUCCESS;
}

// ── fastBalanceOf(address) — static USDC balanceOf ─────────────────────────
fn handleFastBalance(allocator: std.mem.Allocator, data: []const u8) i32 {
    if (data.len < 32) return REVERT;
    var account: [20]u8 = undefined;
    @memcpy(&account, data[12..32]);

    // balanceOf(address) = 0x70a08231
    var cd: [36]u8 = undefined;
    cd[0] = 0x70; cd[1] = 0xa0; cd[2] = 0x82; cd[3] = 0x31;
    @memset(cd[4..16], 0);
    @memcpy(cd[16..36], &account);

    const out = Stylus.callPrecompile(allocator, USDC, &cd) catch return REVERT;
    Stylus.output(out);
    return SUCCESS;
}

// ── Emit helpers ───────────────────────────────────────────────────────────
fn emitSettled(agent: [20]u8, amount: u256, commitment: [32]u8) void {
    var log: [96]u8 = [_]u8{0} ** 96;
    @memset(log[0..12], 0);
    @memcpy(log[12..32], &agent);
    std.mem.writeInt(u256, log[32..64][0..32], amount, .big);
    @memcpy(log[64..96], &commitment);
    Stylus.log(&log, &.{TOPIC_SETTLED});
}

fn returnOne() void {
    const result = [_]u8{0} ** 31 ++ [_]u8{1};
    Stylus.output(&result);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    Stylus.revert();
}

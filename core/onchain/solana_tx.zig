//! Solana legacy transaction builder.
//!
//! Mirrors solana-tx.js (apps/web/assets/src/lib/solana-tx.js).
//!
//! Wire format (legacy tx):
//!   tx       = signatures || message
//!   signatures = compact-u16 N || N × 64-byte Ed25519 sigs
//!   message  = header(3) || accountKeys(compact+N×32) ||
//!              recentBlockhash(32) || instructions
//!     header = numRequiredSigs(u8) || numReadonlySigned(u8) || numReadonlyUnsigned(u8)
//!     instructions = compact-u16 N || N × {
//!       programIdIndex(u8) || accounts(compact+N×u8) || data(compact+N×u8)
//!     }
//!
//! Compact-u16 (short-vec): 1–3 bytes, 7 bits per byte, MSB = continuation.

const std = @import("std");
const crypto_mod = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");

pub const Pubkey = [32]u8;
pub const Blockhash = [32]u8;

pub const AccountMeta = struct {
    pubkey: Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub const Instruction = struct {
    program_id: Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

pub const Header = struct {
    num_required_sigs: u8,
    num_readonly_signed: u8,
    num_readonly_unsigned: u8,
};

pub const CompiledInstruction = struct {
    program_id_index: u8,
    account_indexes: []const u8,
    data: []const u8,
};

// ── Compact-U16 (short-vec) ───────────────────────────────────────────────

pub fn writeCompactU16(writer: anytype, value: usize) !void {
    var val: usize = value;
    while (true) {
        var byte: u8 = @intCast(val & 0x7F);
        val >>= 7;
        if (val > 0) byte |= 0x80;
        try writer.writeByte(byte);
        if (val == 0) break;
    }
}

pub fn decodeCompactU16(buf: []const u8, off: usize) struct { value: usize, consumed: usize } {
    var n: usize = 0;
    var shift: u6 = 0;
    var consumed: usize = 0;
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const b = buf[off + i];
        consumed += 1;
        n |= (@as(usize, b & 0x7F)) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
    }
    return .{ .value = n, .consumed = consumed };
}

// ── Account classification ────────────────────────────────────────────────

const AccountEntry = struct {
    pubkey: Pubkey,
    is_signer: bool,
    is_writable: bool,
};

fn pubkeyEq(a: *const Pubkey, b: *const Pubkey) bool {
    return std.mem.eql(u8, a, b);
}

/// Classify and sort accounts for a Solana legacy tx.
/// Order: writable-signers → readonly-signers → writable-nonsigners → readonly-nonsigners.
/// Payer is forced to index 0.
pub fn classifyAccounts(
    allocator: std.mem.Allocator,
    payer: *const Pubkey,
    instructions: []const Instruction,
) !struct { header: Header, keys: []Pubkey } {
    var entries = std.ArrayListUnmanaged(AccountEntry){};
    defer entries.deinit(allocator);

    // Helper: find or insert an entry, upgrading flags.
    const findOrInsert = struct {
        fn call(list: *std.ArrayListUnmanaged(AccountEntry), alloc: std.mem.Allocator, pk: *const Pubkey, signer: bool, writable: bool) !void {
            for (list.items) |*e| {
                if (pubkeyEq(&e.pubkey, pk)) {
                    if (signer) e.is_signer = true;
                    if (writable) e.is_writable = true;
                    return;
                }
            }
            try list.append(alloc, .{ .pubkey = pk.*, .is_signer = signer, .is_writable = writable });
        }
    }.call;

    // Payer: always writable signer, always index 0.
    try findOrInsert(&entries, allocator, payer, true, true);

    for (instructions) |ix| {
        // Program ID: readonly non-signer.
        try findOrInsert(&entries, allocator, &ix.program_id, false, false);
        // Instruction accounts.
        for (ix.accounts) |a| {
            try findOrInsert(&entries, allocator, &a.pubkey, a.is_signer, a.is_writable);
        }
    }

    // Sort: payer first, then (signer desc, writable desc).
    std.mem.sort(AccountEntry, entries.items, payer, struct {
        fn lessThan(pay: *const Pubkey, a: AccountEntry, b: AccountEntry) bool {
            const a_is_payer = pubkeyEq(&a.pubkey, pay);
            const b_is_payer = pubkeyEq(&b.pubkey, pay);
            if (a_is_payer != b_is_payer) return a_is_payer;
            // Signer > non-signer
            if (a.is_signer != b.is_signer) return a.is_signer;
            // Writable > readonly
            if (a.is_writable != b.is_writable) return a.is_writable;
            return false;
        }
    }.lessThan);

    // Compute header counters.
    var num_required_sigs: u8 = 0;
    var num_readonly_signed: u8 = 0;
    var num_readonly_unsigned: u8 = 0;
    for (entries.items) |e| {
        if (e.is_signer) {
            num_required_sigs += 1;
            if (!e.is_writable) num_readonly_signed += 1;
        } else if (!e.is_writable) {
            num_readonly_unsigned += 1;
        }
    }

    // Build final key list.
    const keys = try allocator.alloc(Pubkey, entries.items.len);
    for (entries.items, 0..) |e, i| keys[i] = e.pubkey;

    return .{
        .header = .{
            .num_required_sigs = num_required_sigs,
            .num_readonly_signed = num_readonly_signed,
            .num_readonly_unsigned = num_readonly_unsigned,
        },
        .keys = keys,
    };
}

fn findKey(keys: []const Pubkey, pk: *const Pubkey) ?u8 {
    for (keys, 0..) |k, i| {
        if (pubkeyEq(&k, pk)) return @intCast(i);
    }
    return null;
}

// ── Transaction builder ───────────────────────────────────────────────────

/// Build a serialized Solana legacy transaction (unsigned — signature bytes zeroed).
/// Returns owned byte slice. Caller should call signTx() afterwards.
pub fn buildLegacyTx(
    allocator: std.mem.Allocator,
    payer: *const Pubkey,
    blockhash: *const Blockhash,
    instructions: []const Instruction,
) ![]u8 {
    const classified = try classifyAccounts(allocator, payer, instructions);
    defer allocator.free(classified.keys);

    const keys = classified.keys;
    const header = classified.header;
    const num_sigs = header.num_required_sigs;

    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // Signatures placeholder.
    try writeCompactU16(writer, num_sigs);
    try buf.appendNTimes(allocator, 0, @as(usize, num_sigs) * 64);

    // Message header.
    try writer.writeByte(header.num_required_sigs);
    try writer.writeByte(header.num_readonly_signed);
    try writer.writeByte(header.num_readonly_unsigned);

    // Account keys.
    try writeCompactU16(writer, keys.len);
    for (keys) |k| try writer.writeAll(&k);

    // Recent blockhash.
    try writer.writeAll(blockhash);

    // Instructions.
    try writeCompactU16(writer, instructions.len);
    for (instructions) |ix| {
        const prog_idx = findKey(keys, &ix.program_id) orelse return error.ProgramNotInKeys;
        try writer.writeByte(prog_idx);

        try writeCompactU16(writer, ix.accounts.len);
        for (ix.accounts) |a| {
            const acc_idx = findKey(keys, &a.pubkey) orelse return error.AccountNotInKeys;
            try writer.writeByte(acc_idx);
        }

        try writeCompactU16(writer, ix.data.len);
        try writer.writeAll(ix.data);
    }

    return buf.toOwnedSlice(allocator);
}

/// Sign a serialized legacy tx in-place. The message starts at byte 65
/// (1 byte compact-u16 for sig count + 64 bytes for the sig placeholder).
/// Works for single-signer txs (the common case for CLI commands).
pub fn signTx(tx_buf: []u8, keypair: *const types.Keypair) void {
    // Message: everything after the 1-byte compact-u16 sig count (=0x01) and 64-byte sig slot.
    const message = tx_buf[65..];
    const sig = crypto_mod.sign(message, keypair);
    @memcpy(tx_buf[1..65], &sig);
}

// ── Tests ────────────────────────────────────────────────────────────────

test "encodeCompactU16" {
    const allocator = std.testing.allocator;

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    // 0 → 0x00
    try writeCompactU16(buf.writer(allocator), 0);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, buf.items);
    buf.clearRetainingCapacity();

    // 127 → 0x7F
    try writeCompactU16(buf.writer(allocator), 127);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x7F}, buf.items);
    buf.clearRetainingCapacity();

    // 128 → 0x80 0x01
    try writeCompactU16(buf.writer(allocator), 128);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x80, 0x01}, buf.items);
    buf.clearRetainingCapacity();

    // 125 (instruction data length in fixture) → single byte 0x7D
    try writeCompactU16(buf.writer(allocator), 125);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x7D}, buf.items);
}

test "buildLegacyTx: single instruction, single signer" {
    const allocator = std.testing.allocator;

    var payer: Pubkey = undefined;
    std.crypto.random.bytes(&payer);
    var prog: Pubkey = undefined;
    std.crypto.random.bytes(&prog);
    var bh: Blockhash = undefined;
    std.crypto.random.bytes(&bh);

    const data = [_]u8{ 1, 2, 3 };
    const ix = Instruction{
        .program_id = prog,
        .accounts = &.{},
        .data = &data,
    };

    const tx = try buildLegacyTx(allocator, &payer, &bh, &[_]Instruction{ix});
    defer allocator.free(tx);

    // Must start with compact-u16(1) = 0x01 then 64 zero bytes.
    try std.testing.expectEqual(@as(u8, 0x01), tx[0]);
    var i: usize = 1;
    while (i < 65) : (i += 1) try std.testing.expectEqual(@as(u8, 0), tx[i]);
}

//! Ethereum ABI encoder / decoder for Stylus contracts.
//!
//! Encoding rules (Solidity ABI spec):
//!   Static  (uint*, bool, bytes<N>, address): 32-byte big-endian padded, in-place.
//!   Dynamic (bytes, string, T[]): head = uint256 offset into tail; tail = uint256 len + data.
//!
//! Function call layout:  selector(4) || head(32*N) || tail(dynamic data)

const std = @import("std");

// ── Selector ──────────────────────────────────────────────────────────────────

pub fn selector(comptime sig: []const u8) [4]u8 {
    @setEvalBranchQuota(100_000);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(sig, &hash, .{});
    return hash[0..4].*;
}

// ── Decoder ───────────────────────────────────────────────────────────────────

pub const Decoder = struct {
    data: []const u8, // full calldata (without 4-byte selector)
    pos: usize,

    pub fn init(data: []const u8) Decoder {
        return .{ .data = data, .pos = 0 };
    }

    fn word(self: *Decoder) ![32]u8 {
        if (self.pos + 32 > self.data.len) return error.UnexpectedEof;
        const w = self.data[self.pos..][0..32].*;
        self.pos += 32;
        return w;
    }

    pub fn uint256(self: *Decoder) ![32]u8 {
        return self.word();
    }

    pub fn uint64(self: *Decoder) !u64 {
        const w = try self.word();
        return std.mem.readInt(u64, w[24..32], .big);
    }

    pub fn uint32(self: *Decoder) !u32 {
        const w = try self.word();
        return std.mem.readInt(u32, w[28..32], .big);
    }

    pub fn boolean(self: *Decoder) !bool {
        const w = try self.word();
        return w[31] != 0;
    }

    pub fn address(self: *Decoder) ![20]u8 {
        const w = try self.word();
        return w[12..32].*;
    }

    pub fn bytes32(self: *Decoder) ![32]u8 {
        return self.word();
    }

    // Read current word as a usize offset (for dynamic array heads).
    // Bounds checking happens at the callsite (e.g. DynArray.read).
    pub fn offset(self: *Decoder) !usize {
        const w = try self.word();
        const v = std.mem.readInt(u256, &w, .big);
        if (v > std.math.maxInt(usize)) return error.InvalidOffset;
        return @intCast(v);
    }

    // Dynamic bytes: head is offset, tail has uint256 len + padded data.
    pub fn bytes(self: *Decoder) ![]const u8 {
        const off_word = try self.word();
        const raw_off = std.mem.readInt(u256, &off_word, .big);
        if (raw_off > self.data.len) return error.InvalidOffset;
        const off: usize = @intCast(raw_off);

        if (off + 32 > self.data.len) return error.UnexpectedEof;
        const len_word = self.data[off..][0..32];
        const len = std.mem.readInt(u256, len_word, .big);
        if (len > 65536) return error.TooLarge;
        const n: usize = @intCast(len);

        if (off + 32 + n > self.data.len) return error.UnexpectedEof;
        return self.data[off + 32 ..][0..n];
    }
};

// ── DynArray ─────────────────────────────────────────────────────────────────
//
// Represents an ABI-encoded dynamic array of fixed-size elements (address,
// uint256, bytes32) located at `array_offset` within the full calldata slice.
// Layout: [uint256 length][element_0][element_1]...
//
// Usage:
//   var dec = Decoder.init(params);
//   const agents = try DynArray.read(params, try dec.offset());
//   const amounts = try DynArray.read(params, try dec.offset());
//   for (0..agents.len()) |i| { const a = try agents.address(i); ... }

pub const DynArray = struct {
    data: []const u8,
    base: usize,  // byte offset to the length word within data
    count: usize,

    pub fn read(data: []const u8, array_offset: usize) !DynArray {
        if (array_offset + 32 > data.len) return error.UnexpectedEof;
        const len_word = data[array_offset..][0..32];
        const count = std.mem.readInt(u256, len_word, .big);
        if (count > 256) return error.TooLarge;
        const n: usize = @intCast(count);
        if (array_offset + 32 + n * 32 > data.len) return error.UnexpectedEof;
        return .{ .data = data, .base = array_offset, .count = n };
    }

    pub fn len(self: DynArray) usize { return self.count; }

    fn elemWord(self: DynArray, i: usize) ![32]u8 {
        if (i >= self.count) return error.IndexOutOfBounds;
        const elem_off = self.base + 32 + i * 32;
        return self.data[elem_off..][0..32].*;
    }

    pub fn address(self: DynArray, i: usize) ![20]u8 {
        const w = try self.elemWord(i);
        return w[12..32].*;
    }

    pub fn uint256(self: DynArray, i: usize) ![32]u8 {
        return self.elemWord(i);
    }

    pub fn bytes32(self: DynArray, i: usize) ![32]u8 {
        return self.elemWord(i);
    }
};

// ── Encoder ───────────────────────────────────────────────────────────────────

pub const Encoder = struct {
    buf: []u8,
    head_pos: usize, // cursor in head section
    tail_pos: usize, // cursor in tail section
    head_size: usize,

    pub fn init(buf: []u8, static_word_count: usize) Encoder {
        return .{
            .buf = buf,
            .head_pos = 0,
            .head_size = static_word_count * 32,
            .tail_pos = static_word_count * 32,
        };
    }

    pub fn uint256Raw(self: *Encoder, val: [32]u8) void {
        @memcpy(self.buf[self.head_pos..][0..32], &val);
        self.head_pos += 32;
    }

    pub fn uint64(self: *Encoder, val: u64) void {
        @memset(self.buf[self.head_pos..][0..24], 0);
        std.mem.writeInt(u64, self.buf[self.head_pos + 24 ..][0..8], val, .big);
        self.head_pos += 32;
    }

    pub fn uint32(self: *Encoder, val: u32) void {
        @memset(self.buf[self.head_pos..][0..28], 0);
        std.mem.writeInt(u32, self.buf[self.head_pos + 28 ..][0..4], val, .big);
        self.head_pos += 32;
    }

    pub fn boolean(self: *Encoder, val: bool) void {
        @memset(self.buf[self.head_pos..][0..31], 0);
        self.buf[self.head_pos + 31] = if (val) 1 else 0;
        self.head_pos += 32;
    }

    pub fn address(self: *Encoder, addr: [20]u8) void {
        @memset(self.buf[self.head_pos..][0..12], 0);
        @memcpy(self.buf[self.head_pos + 12 ..][0..20], &addr);
        self.head_pos += 32;
    }

    pub fn bytes32(self: *Encoder, val: [32]u8) void {
        @memcpy(self.buf[self.head_pos..][0..32], &val);
        self.head_pos += 32;
    }

    // Dynamic bytes: write offset in head, length + padded data in tail.
    pub fn bytes(self: *Encoder, data: []const u8) void {
        // Head: offset to tail entry
        const offset = self.tail_pos;
        @memset(self.buf[self.head_pos..][0..24], 0);
        std.mem.writeInt(u64, self.buf[self.head_pos + 24 ..][0..8], @intCast(offset), .big);
        self.head_pos += 32;

        // Tail: uint256 length
        @memset(self.buf[self.tail_pos..][0..24], 0);
        std.mem.writeInt(u64, self.buf[self.tail_pos + 24 ..][0..8], @intCast(data.len), .big);
        self.tail_pos += 32;

        // Tail: data padded to 32-byte boundary
        @memcpy(self.buf[self.tail_pos..][0..data.len], data);
        const padded = ((data.len + 31) / 32) * 32;
        if (padded > data.len) @memset(self.buf[self.tail_pos + data.len ..][0 .. padded - data.len], 0);
        self.tail_pos += padded;
    }

    pub fn totalLen(self: *const Encoder) usize {
        return self.tail_pos;
    }
};

// ── Event log ─────────────────────────────────────────────────────────────────

// Emit a log with up to 4 indexed topics (bytes32 each) + optional data.
// topics_data: concatenated 32-byte topics followed by unindexed data.
// n_topics: number of leading topics.
pub fn emitLog(
    topics_and_data: []const u8,
    n_topics: usize,
) void {
    const h = @import("host.zig");
    h.emit_log(topics_and_data.ptr, topics_and_data.len, n_topics);
}

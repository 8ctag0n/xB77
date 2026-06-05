//! Wincode — Solana-flavored bincode codec.
//!
//! Layout (mirrors wincode.js and tests/wincode_layout.rs):
//!   u8/i8             → 1 byte LE
//!   u16..u64 / i16..i64 → little-endian fixed widths
//!   bool              → u8 (0 = false, 1 = true)
//!   [u8; N]           → N bytes inline, no prefix
//!   Vec<T> / []T      → u64 LE length prefix + body
//!   Option<T>         → u8 tag (0 = None, 1 = Some) + body if Some
//!   enum variant      → u32 LE discriminant

const std = @import("std");

pub const Writer = struct {
    buf: std.ArrayListUnmanaged(u8),

    pub fn init() Writer {
        return .{ .buf = .empty };
    }

    pub fn deinit(self: *Writer, allocator: std.mem.Allocator) void {
        self.buf.deinit(allocator);
    }

    /// Return the encoded bytes. Caller does NOT own the slice — it points into
    /// the writer's internal buffer. Call toOwnedSlice() to transfer ownership.
    pub fn bytes(self: *const Writer) []const u8 {
        return self.buf.items;
    }

    pub fn toOwnedSlice(self: *Writer, allocator: std.mem.Allocator) ![]u8 {
        return self.buf.toOwnedSlice(allocator);
    }

    // --- primitives ---

    pub fn u8W(self: *Writer, allocator: std.mem.Allocator, v: u8) !void {
        try self.buf.append(allocator, v);
    }

    pub fn i8W(self: *Writer, allocator: std.mem.Allocator, v: i8) !void {
        try self.buf.append(allocator, @bitCast(v));
    }

    pub fn u16W(self: *Writer, allocator: std.mem.Allocator, v: u16) !void {
        var _b: [2]u8 = undefined;
        std.mem.writeInt(u16, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn i16W(self: *Writer, allocator: std.mem.Allocator, v: i16) !void {
        var _b: [2]u8 = undefined;
        std.mem.writeInt(i16, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn u32W(self: *Writer, allocator: std.mem.Allocator, v: u32) !void {
        var _b: [4]u8 = undefined;
        std.mem.writeInt(u32, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn i32W(self: *Writer, allocator: std.mem.Allocator, v: i32) !void {
        var _b: [4]u8 = undefined;
        std.mem.writeInt(i32, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn u64W(self: *Writer, allocator: std.mem.Allocator, v: u64) !void {
        var _b: [8]u8 = undefined;
        std.mem.writeInt(u64, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn i64W(self: *Writer, allocator: std.mem.Allocator, v: i64) !void {
        var _b: [8]u8 = undefined;
        std.mem.writeInt(i64, &_b, v, .little);
        try self.buf.appendSlice(allocator, &_b);
    }

    pub fn boolW(self: *Writer, allocator: std.mem.Allocator, v: bool) !void {
        try self.u8W(allocator, if (v) 1 else 0);
    }

    /// Enum variant discriminant — encoded as u32 LE (matches on-chain Rust wincode).
    pub fn enumTag(self: *Writer, allocator: std.mem.Allocator, disc: u32) !void {
        try self.u32W(allocator, disc);
    }

    // --- composites ---

    /// Fixed-size byte array: N bytes inline, no length prefix.
    pub fn fixed(self: *Writer, allocator: std.mem.Allocator, data: []const u8) !void {
        try self.buf.appendSlice(allocator, data);
    }

    /// Vec<u8> (or any byte slice): u64 LE length + bytes.
    pub fn vecU8(self: *Writer, allocator: std.mem.Allocator, data: []const u8) !void {
        try self.u64W(allocator, data.len);
        try self.buf.appendSlice(allocator, data);
    }

    /// Vec<[u8; N]>: u64 LE length + N * item (each item is N bytes inline).
    pub fn vecFixed(self: *Writer, allocator: std.mem.Allocator, items: []const []const u8) !void {
        try self.u64W(allocator, items.len);
        for (items) |item| try self.buf.appendSlice(allocator, item);
    }

    /// Option<T>: 0 tag if null, else 1 tag + encoded inner.
    /// `encodeSome` is called with the writer + inner value if not null.
    pub fn optionNull(self: *Writer, allocator: std.mem.Allocator) !void {
        try self.u8W(allocator, 0);
    }

    pub fn optionSomeTag(self: *Writer, allocator: std.mem.Allocator) !void {
        try self.u8W(allocator, 1);
    }
};

pub const Reader = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) Reader {
        return .{ .data = data, .pos = 0 };
    }

    pub fn remaining(self: *const Reader) usize {
        return self.data.len - self.pos;
    }

    pub fn eof(self: *const Reader) bool {
        return self.pos >= self.data.len;
    }

    fn advance(self: *Reader, n: usize) ![]const u8 {
        if (self.pos + n > self.data.len) return error.UnexpectedEof;
        const slice = self.data[self.pos .. self.pos + n];
        self.pos += n;
        return slice;
    }

    pub fn u8R(self: *Reader) !u8 {
        const s = try self.advance(1);
        return s[0];
    }

    pub fn i8R(self: *Reader) !i8 {
        return @bitCast(try self.u8R());
    }

    pub fn u16R(self: *Reader) !u16 {
        const s = try self.advance(2);
        return std.mem.readInt(u16, s[0..2], .little);
    }

    pub fn i16R(self: *Reader) !i16 {
        const s = try self.advance(2);
        return std.mem.readInt(i16, s[0..2], .little);
    }

    pub fn u32R(self: *Reader) !u32 {
        const s = try self.advance(4);
        return std.mem.readInt(u32, s[0..4], .little);
    }

    pub fn i32R(self: *Reader) !i32 {
        const s = try self.advance(4);
        return std.mem.readInt(i32, s[0..4], .little);
    }

    pub fn u64R(self: *Reader) !u64 {
        const s = try self.advance(8);
        return std.mem.readInt(u64, s[0..8], .little);
    }

    pub fn i64R(self: *Reader) !i64 {
        const s = try self.advance(8);
        return std.mem.readInt(i64, s[0..8], .little);
    }

    pub fn boolR(self: *Reader) !bool {
        return (try self.u8R()) != 0;
    }

    pub fn enumTag(self: *Reader) !u32 {
        return self.u32R();
    }

    /// Read exactly `n` bytes inline (fixed-size array).
    pub fn fixed(self: *Reader, n: usize) ![]const u8 {
        return self.advance(n);
    }

    /// Read a Vec<u8>: u64 LE length then that many bytes.
    pub fn vecU8(self: *Reader) ![]const u8 {
        const n = try self.u64R();
        return self.advance(n);
    }

    /// Read Option tag. Returns true if Some (caller should read the inner).
    pub fn optionTag(self: *Reader) !bool {
        return (try self.u8R()) != 0;
    }
};

// ── Tests ────────────────────────────────────────────────────────────────

test "wincode roundtrip: primitives" {
    const allocator = std.testing.allocator;

    var w = Writer.init();
    defer w.deinit(allocator);

    try w.u8W(allocator, 0xAB);
    try w.i8W(allocator, -1);
    try w.u16W(allocator, 0x1234);
    try w.i16W(allocator, -100);
    try w.u32W(allocator, 0xDEADBEEF);
    try w.i32W(allocator, -1_000_000);
    try w.u64W(allocator, 0x0102030405060708);
    try w.i64W(allocator, -1);
    try w.boolW(allocator, true);
    try w.boolW(allocator, false);

    var r = Reader.init(w.bytes());
    try std.testing.expectEqual(@as(u8, 0xAB), try r.u8R());
    try std.testing.expectEqual(@as(i8, -1), try r.i8R());
    try std.testing.expectEqual(@as(u16, 0x1234), try r.u16R());
    try std.testing.expectEqual(@as(i16, -100), try r.i16R());
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try r.u32R());
    try std.testing.expectEqual(@as(i32, -1_000_000), try r.i32R());
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), try r.u64R());
    try std.testing.expectEqual(@as(i64, -1), try r.i64R());
    try std.testing.expect(try r.boolR());
    try std.testing.expect(!(try r.boolR()));
    try std.testing.expect(r.eof());
}

test "wincode roundtrip: fixed array" {
    const allocator = std.testing.allocator;

    var w = Writer.init();
    defer w.deinit(allocator);

    const data = [_]u8{1, 2, 3, 4, 5};
    try w.fixed(allocator, &data);

    var r = Reader.init(w.bytes());
    const got = try r.fixed(5);
    try std.testing.expectEqualSlices(u8, &data, got);
}

test "wincode roundtrip: vecU8" {
    const allocator = std.testing.allocator;

    var w = Writer.init();
    defer w.deinit(allocator);

    const data = [_]u8{0xAA, 0xBB, 0xCC};
    try w.vecU8(allocator, &data);

    var r = Reader.init(w.bytes());
    // 8 bytes length prefix (u64 LE = 3) + 3 bytes = 11 total
    try std.testing.expectEqual(@as(usize, 11), w.bytes().len);
    const got = try r.vecU8();
    try std.testing.expectEqualSlices(u8, &data, got);
}

test "wincode VerifyTransition fixture: 125 bytes" {
    // Reproduce the exact 125-byte payload from tests/compression_e2e.zig
    // and tests/wincode_layout.rs.
    const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

    var new_root: [32]u8 = undefined;
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        new_root[i] = try std.fmt.parseInt(u8, NEW_ROOT_HEX[i * 2 .. i * 2 + 2], 16);
    }

    const allocator = std.testing.allocator;

    var w = Writer.init();
    defer w.deinit(allocator);

    // discriminant u32 LE = 0 (VerifyTransition variant)
    try w.enumTag(allocator, 0);
    // old_root [u8; 32]
    try w.fixed(allocator, &([_]u8{0} ** 32));
    // new_root [u8; 32]
    try w.fixed(allocator, &new_root);
    // index u64 LE = 0
    try w.u64W(allocator, 0);
    // siblings Vec<[u8; 32]>: len=0 → just u64 LE 0
    try w.u64W(allocator, 0);
    // leaf_preimage_amount u64 = 1
    try w.u64W(allocator, 1);
    // leaf_preimage_type u8 = 0
    try w.u8W(allocator, 0);
    // leaf_preimage_tx_hash [u8; 32]
    try w.fixed(allocator, &([_]u8{0} ** 32));

    try std.testing.expectEqual(@as(usize, 125), w.bytes().len);

    // Verify the first 4 bytes are discriminant 0 (LE)
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[0]);
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[1]);
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[2]);
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[3]);

    // Verify new_root bytes start at offset 36 (4 disc + 32 old_root)
    try std.testing.expectEqualSlices(u8, &new_root, w.bytes()[36..68]);

    // Verify leaf_preimage_amount at offset 116 (4+32+32+8+8 = 84... wait:
    // 4 + 32 + 32 + 8 + 8 + 8 = 92... no:
    // disc(4) + old_root(32) + new_root(32) + index(8) + siblings_len(8) = 84
    // + amount(8) = 92, type at 92, tx_hash at 93
    try std.testing.expectEqual(@as(u8, 1), w.bytes()[92]); // amount low byte
    try std.testing.expectEqual(@as(u8, 0), w.bytes()[93]); // type = 0 (leaf_preimage_type)
}

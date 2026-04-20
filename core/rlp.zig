const std = @import("std");

pub fn encode(allocator: std.mem.Allocator, item: anytype) ![]u8 {
    const T = @TypeOf(item);
    switch (T) {
        []const u8, []u8 => return try encodeString(allocator, item),
        u8, u16, u32, u64, u128, usize => return try encodeInt(allocator, item),
        else => {
            const info = @typeInfo(T);
            switch (info) {
                .pointer => return try encodeString(allocator, item),
                .@"struct", .array => return try encodeList(allocator, item),
                else => @compileError("Unsupported type for RLP encoding: " ++ @typeName(T)),
            }
        },
    }
}

fn encodeInt(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    if (value == 0) {
        var res = try allocator.alloc(u8, 1);
        res[0] = 0x80;
        return res;
    }
    
    var buf: [16]u8 = undefined;
    std.mem.writeInt(u128, &buf, value, .big);
    
    var start: usize = 0;
    while (start < 16 and buf[start] == 0) : (start += 1) {}
    
    return try encodeString(allocator, buf[start..]);
}

fn encodeString(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    if (s.len == 1 and s[0] < 0x80) {
        return try allocator.dupe(u8, s);
    } else if (s.len <= 55) {
        var res = try allocator.alloc(u8, 1 + s.len);
        res[0] = @intCast(0x80 + s.len);
        @memcpy(res[1..], s);
        return res;
    } else {
        var len_buf: [8]u8 = undefined;
        const len_bytes = writeLen(&len_buf, s.len);
        var res = try allocator.alloc(u8, 1 + len_bytes.len + s.len);
        res[0] = @intCast(0xb7 + len_bytes.len);
        @memcpy(res[1 .. 1 + len_bytes.len], len_bytes);
        @memcpy(res[1 + len_bytes.len ..], s);
        return res;
    }
}

pub fn encodeList(allocator: std.mem.Allocator, items: anytype) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    inline for (items) |item| {
        const encoded = try encode(allocator, item);
        defer allocator.free(encoded);
        try out.appendSlice(encoded);
    }

    return try encodeListFixed(allocator, out.items);
}

pub fn encodeListFixed(allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
    if (payload.len <= 55) {
        var res = try allocator.alloc(u8, 1 + payload.len);
        res[0] = @intCast(0xc0 + payload.len);
        @memcpy(res[1..], payload);
        return res;
    } else {
        var len_buf: [8]u8 = undefined;
        const len_bytes = writeLen(&len_buf, payload.len);
        var res = try allocator.alloc(u8, 1 + len_bytes.len + payload.len);
        res[0] = @intCast(0xf7 + len_bytes.len);
        @memcpy(res[1 .. 1 + len_bytes.len], len_bytes);
        @memcpy(res[1 + len_bytes.len ..], payload);
        return res;
    }
}

fn writeLen(buf: *[8]u8, len: usize) []u8 {
    std.mem.writeInt(u64, buf, len, .big);
    var start: usize = 0;
    while (start < 8 and buf[start] == 0) : (start += 1) {}
    return buf[start..];
}

//! IDL-driven instruction encoder for xB77 on-chain programs.
//!
//! Mirrors the JS IdlClient (webapp_deploy/assets/src/lib/idl-client.js).
//!
//! API:
//!   var client = try IdlClient.init(allocator, idl_json_bytes);
//!   defer client.deinit();
//!   const data = try client.encodeInstruction("VerifyTransition", values);
//!
//! `values` is a tagged-union tree matching the IDL arg structure.
//!
//! Supported IDL type shapes (same as JS implementation):
//!   "u8" | "u16" | "u32" | "u64" | "i8" | "i16" | "i32" | "i64" | "bool"
//!   { "array": ["u8", N] }   → fixed-size byte array
//!   { "vec": <inner> }       → u64 LE length + body
//!   { "defined": "TypeName" } → struct lookup in idl.types[]
//!
//! Because Zig lacks runtime reflection, callers supply field values via the
//! `FieldValue` tagged union. The encoder walks the IDL JSON and picks the
//! matching branch.

const std = @import("std");
const wincode = @import("wincode.zig");

/// A value that can be supplied for any IDL field.
pub const FieldValue = union(enum) {
    u8_val: u8,
    i8_val: i8,
    u16_val: u16,
    i16_val: i16,
    u32_val: u32,
    i32_val: i32,
    u64_val: u64,
    i64_val: i64,
    bool_val: bool,
    bytes: []const u8,         // fixed array or vec<u8>
    vec_fixed32: []const [32]u8, // Vec<[u8;32]> — siblings
    struct_val: []const NamedField,
    null_val: void,
};

pub const NamedField = struct {
    name: []const u8,
    value: FieldValue,
};

pub const IdlClient = struct {
    allocator: std.mem.Allocator,
    parsed: std.json.Parsed(std.json.Value),

    pub fn init(allocator: std.mem.Allocator, idl_json: []const u8) !IdlClient {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, idl_json, .{});
        return .{
            .allocator = allocator,
            .parsed = parsed,
        };
    }

    pub fn deinit(self: *IdlClient) void {
        self.parsed.deinit();
    }

    pub fn programId(self: *const IdlClient) ?[]const u8 {
        const meta = self.parsed.value.object.get("metadata") orelse return null;
        const addr = meta.object.get("address") orelse return null;
        return addr.string;
    }

    /// Returns the 0-based discriminant for an instruction name.
    pub fn discriminantOf(self: *const IdlClient, name: []const u8) !u32 {
        const instructions = self.parsed.value.object.get("instructions") orelse
            return error.NoInstructions;
        for (instructions.array.items, 0..) |ix, i| {
            const ix_name = ix.object.get("name") orelse continue;
            if (std.mem.eql(u8, ix_name.string, name)) return @intCast(i);
        }
        return error.UnknownInstruction;
    }

    /// Encode `instructionName` with the given field values. Returns owned bytes.
    pub fn encodeInstruction(
        self: *const IdlClient,
        instruction_name: []const u8,
        values: []const NamedField,
    ) ![]u8 {
        const instructions = self.parsed.value.object.get("instructions") orelse
            return error.NoInstructions;

        // Find the instruction and its 0-based index.
        var ix_json: ?std.json.Value = null;
        var disc: u32 = 0;
        for (instructions.array.items, 0..) |ix, i| {
            const ix_name = ix.object.get("name") orelse continue;
            if (std.mem.eql(u8, ix_name.string, instruction_name)) {
                ix_json = ix;
                disc = @intCast(i);
                break;
            }
        }
        if (ix_json == null) return error.UnknownInstruction;

        var w = wincode.Writer.init();
        errdefer w.deinit(self.allocator);

        // Discriminant as u32 LE.
        try w.enumTag(self.allocator, disc);

        // Encode each arg in IDL declaration order.
        const args = ix_json.?.object.get("args") orelse return w.toOwnedSlice(self.allocator);
        for (args.array.items) |arg| {
            const arg_name = arg.object.get("name").?.string;
            const arg_type = arg.object.get("type") orelse return error.MissingType;

            // Find value in caller's NamedField list.
            const fv = findField(values, arg_name) orelse return error.MissingField;
            try self.encodeType(&w, arg_type, fv);
        }

        return w.toOwnedSlice(self.allocator);
    }

    fn findField(fields: []const NamedField, name: []const u8) ?FieldValue {
        for (fields) |f| {
            if (std.mem.eql(u8, f.name, name)) return f.value;
        }
        return null;
    }

    fn encodeType(self: *const IdlClient, w: *wincode.Writer, ty: std.json.Value, val: FieldValue) anyerror!void {
        switch (ty) {
            .string => |s| try self.encodePrim(w, s, val),
            .object => {
                if (ty.object.get("defined")) |def| {
                    try self.encodeDefined(w, def.string, val);
                } else if (ty.object.get("array")) |arr| {
                    try self.encodeArray(w, arr, val);
                } else if (ty.object.get("vec")) |inner| {
                    try self.encodeVec(w, inner, val);
                } else if (ty.object.get("option")) |inner| {
                    try self.encodeOption(w, inner, val);
                } else {
                    return error.UnsupportedType;
                }
            },
            else => return error.UnsupportedType,
        }
    }

    fn encodePrim(self: *const IdlClient, w: *wincode.Writer, ty: []const u8, val: FieldValue) !void {
        if (std.mem.eql(u8, ty, "u8")) {
            try w.u8W(self.allocator, val.u8_val);
        } else if (std.mem.eql(u8, ty, "i8")) {
            try w.i8W(self.allocator, val.i8_val);
        } else if (std.mem.eql(u8, ty, "u16")) {
            try w.u16W(self.allocator, val.u16_val);
        } else if (std.mem.eql(u8, ty, "i16")) {
            try w.i16W(self.allocator, val.i16_val);
        } else if (std.mem.eql(u8, ty, "u32")) {
            try w.u32W(self.allocator, val.u32_val);
        } else if (std.mem.eql(u8, ty, "i32")) {
            try w.i32W(self.allocator, val.i32_val);
        } else if (std.mem.eql(u8, ty, "u64")) {
            try w.u64W(self.allocator, val.u64_val);
        } else if (std.mem.eql(u8, ty, "i64")) {
            try w.i64W(self.allocator, val.i64_val);
        } else if (std.mem.eql(u8, ty, "bool")) {
            try w.boolW(self.allocator, val.bool_val);
        } else if (std.mem.eql(u8, ty, "bytes") or std.mem.eql(u8, ty, "string")) {
            // Vec<u8> / String — encoded as compact-u32 LE length prefix + raw bytes.
            try w.vecU8(self.allocator, val.bytes);
        } else {
            return error.UnsupportedPrimitive;
        }
    }

    fn encodeArray(self: *const IdlClient, w: *wincode.Writer, arr: std.json.Value, val: FieldValue) anyerror!void {
        // arr is [inner_type, length]
        const inner = arr.array.items[0];
        const len: usize = @intCast(arr.array.items[1].integer);

        // Fast path for [u8; N]: accept bytes directly.
        if (inner == .string and std.mem.eql(u8, inner.string, "u8")) {
            const b = val.bytes;
            if (b.len != len) return error.LengthMismatch;
            try w.fixed(self.allocator, b);
        } else {
            // Generic fixed array: val must be struct_val with indexed entries
            // (not needed by compression IDL, but kept for completeness).
            return error.UnsupportedArrayElement;
        }
    }

    fn encodeVec(self: *const IdlClient, w: *wincode.Writer, inner: std.json.Value, val: FieldValue) anyerror!void {
        // Vec<u8> fast path.
        if (inner == .string and std.mem.eql(u8, inner.string, "u8")) {
            try w.vecU8(self.allocator, val.bytes);
            return;
        }

        // Vec<[u8; N]> — the siblings field.
        if (inner == .object) {
            if (inner.object.get("array")) |arr| {
                const elem_inner = arr.array.items[0];
                const elem_len: usize = @intCast(arr.array.items[1].integer);
                if (elem_inner == .string and std.mem.eql(u8, elem_inner.string, "u8") and elem_len == 32) {
                    const items = val.vec_fixed32;
                    try w.u64W(self.allocator, items.len);
                    for (items) |item| try w.fixed(self.allocator, &item);
                    return;
                }
            }
        }

        return error.UnsupportedVecElement;
    }

    fn encodeOption(self: *const IdlClient, w: *wincode.Writer, inner: std.json.Value, val: FieldValue) anyerror!void {
        switch (val) {
            .null_val => try w.optionNull(self.allocator),
            else => {
                try w.optionSomeTag(self.allocator);
                try self.encodeType(w, inner, val);
            },
        }
    }

    fn encodeDefined(self: *const IdlClient, w: *wincode.Writer, type_name: []const u8, val: FieldValue) anyerror!void {
        // Look up the type in idl.types[].
        const types_arr = self.parsed.value.object.get("types") orelse return error.NoTypes;
        var def_json: ?std.json.Value = null;
        for (types_arr.array.items) |t| {
            const tname = t.object.get("name") orelse continue;
            if (std.mem.eql(u8, tname.string, type_name)) {
                def_json = t;
                break;
            }
        }
        if (def_json == null) return error.UnknownDefinedType;

        const kind_obj = def_json.?.object.get("type") orelse return error.MalformedType;
        const kind = kind_obj.object.get("kind") orelse return error.MalformedType;
        if (!std.mem.eql(u8, kind.string, "struct")) return error.NonStructDefined;

        const fields_json = kind_obj.object.get("fields") orelse return error.NoFields;
        const fields = val.struct_val;

        for (fields_json.array.items) |f| {
            const fname = f.object.get("name").?.string;
            const ftype = f.object.get("type") orelse return error.MissingType;
            const fval = findField(fields, fname) orelse return error.MissingField;
            try self.encodeType(w, ftype, fval);
        }
    }
};

// ── Tests ────────────────────────────────────────────────────────────────

test "idl_client: encode VerifyTransition matches 125-byte fixture" {
    const allocator = std.testing.allocator;

    // Load the real IDL JSON from the repo.
    const idl_path = "idls/xb77_compression.json";
    const idl_json = try std.fs.cwd().readFileAlloc(allocator, idl_path, 64 * 1024);
    defer allocator.free(idl_json);

    var client = try IdlClient.init(allocator, idl_json);
    defer client.deinit();

    const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";
    var new_root: [32]u8 = undefined;
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        new_root[i] = try std.fmt.parseInt(u8, NEW_ROOT_HEX[i * 2 .. i * 2 + 2], 16);
    }

    const old_root = [_]u8{0} ** 32;
    const tx_hash = [_]u8{0} ** 32;
    const siblings = [0][32]u8{};

    const payload_fields = [_]NamedField{
        .{ .name = "old_root",               .value = .{ .bytes = &old_root } },
        .{ .name = "new_root",               .value = .{ .bytes = &new_root } },
        .{ .name = "index",                  .value = .{ .u64_val = 0 } },
        .{ .name = "siblings",               .value = .{ .vec_fixed32 = &siblings } },
        .{ .name = "leaf_preimage_amount",   .value = .{ .u64_val = 1 } },
        .{ .name = "leaf_preimage_type",     .value = .{ .u8_val = 0 } },
        .{ .name = "leaf_preimage_tx_hash",  .value = .{ .bytes = &tx_hash } },
    };

    const top_fields = [_]NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };

    const data = try client.encodeInstruction("VerifyTransition", &top_fields);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 125), data.len);

    // Check discriminant = 0.
    try std.testing.expectEqual(@as(u8, 0), data[0]);
    try std.testing.expectEqual(@as(u8, 0), data[1]);

    // Check new_root at offset 36.
    try std.testing.expectEqualSlices(u8, &new_root, data[36..68]);
}

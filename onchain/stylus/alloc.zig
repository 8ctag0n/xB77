//! Bump allocator for Stylus WASM contracts.
//! No OS, no GPA. Fixed 64 KB heap. Free is a no-op.
//! Reset between calls is implicit — WASM memory is re-initialized each call
//! by the Stylus runtime, so the bump position starts at 0 every invocation.

const std = @import("std");

// 64 KB should be enough for any single Stylus call.
// If more is needed, increase and call pay_for_memory_grow accordingly.
var heap: [65536]u8 align(16) = undefined;
var pos: usize = 0;

pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &vtable,
};

const vtable = std.mem.Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn alloc(_: *anyopaque, n: usize, log2_align: u8, _: usize) ?[*]u8 {
    const alignment = @as(usize, 1) << @intCast(log2_align);
    const aligned_pos = std.mem.alignForward(usize, pos, alignment);
    if (aligned_pos + n > heap.len) return null;
    pos = aligned_pos + n;
    return heap[aligned_pos..].ptr;
}

fn resize(_: *anyopaque, _: []u8, _: u8, _: usize, _: usize) bool {
    return false;
}

fn remap(_: *anyopaque, _: []u8, _: u8, _: usize, _: usize) ?[*]u8 {
    return null;
}

fn free(_: *anyopaque, _: []u8, _: u8, _: usize) void {}

pub fn reset() void {
    pos = 0;
}

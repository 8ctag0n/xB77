const std = @import("std");

/// Syscalls directos a la VM de Solana (SBF)
pub const syscalls = struct {
    extern fn sol_log_(message: [*]const u8, length: u64) void;
};

fn log(msg: []const u8) void {
    syscalls.sol_log_(msg.ptr, msg.len);
}

/// Entrypoint oficial
export fn entrypoint(input: [*]u8) u64 {
    _ = input;
    log("=== xB77 Sovereign SBF (CPU V3) ===");
    return 0; // Success
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    log("!!! PANIC !!!");
    log(msg);
    while (true) {}
}

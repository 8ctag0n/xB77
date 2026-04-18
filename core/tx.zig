const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");

/// Serialización de Compact-u16 (formato Solana).
pub fn writeCompactU16(writer: anytype, value: u16) !void {
    var val = value;
    while (true) {
        var byte: u8 = @intCast(val & 0x7F);
        val >>= 7;
        if (val > 0) {
            byte |= 0x80;
        }
        try writer.writeByte(byte);
        if (val == 0) break;
    }
}

pub const AccountMeta = struct {
    pubkey: types.Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub const Instruction = struct {
    program_id: types.Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

/// Construye una transacción de transferencia simple (System Program).
pub fn buildTransferTx(
    allocator: std.mem.Allocator,
    from: types.Pubkey,
    to: types.Pubkey,
    lamports: u64,
    recent_blockhash: types.Hash,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);

    // Usar un writer que maneje el allocator
    const writer = buf.writer(allocator);

    // 1. Firmas (Compact-u16 count + 1 placeholder de 64 bytes)
    try writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // --- MESSAGE START ---

    // Header: num_required_sigs, num_readonly_signed, num_readonly_unsigned
    try writer.writeByte(1);
    try writer.writeByte(0);
    try writer.writeByte(1);

    // Account Keys (Compact-u16 count + Keys)
    try writeCompactU16(writer, 3);
    try buf.appendSlice(allocator, &from);
    try buf.appendSlice(allocator, &to);
    var system_program = [_]u8{0} ** 32;
    try buf.appendSlice(allocator, &system_program);

    // Recent Blockhash
    try buf.appendSlice(allocator, &recent_blockhash);

    // Instructions (Compact-u16 count)
    try writeCompactU16(writer, 1);
    
    // Instruction 0: Program ID Index (System Program es el 2 en nuestra lista)
    try writer.writeByte(2);
    
    // Accounts (Compact-u16 count + Indices)
    try writeCompactU16(writer, 2);
    try writer.writeByte(0); // From
    try writer.writeByte(1); // To

    // Data (Compact-u16 count + Transfer data)
    try writeCompactU16(writer, 12);
    try writer.writeInt(u32, 2, .little);
    try writer.writeInt(u64, lamports, .little);

    return buf.toOwnedSlice(allocator);
}

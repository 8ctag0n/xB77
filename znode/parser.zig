const std = @import("std");
const znode = @import("../deps/znode.h");

/// Parser de ultra-alta velocidad para mensajes Yellowstone (Dragon's Mouth)
/// Diseñado para latencia de microsegundos.
pub const YellowstoneParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) YellowstoneParser {
        return .{ .allocator = allocator };
    }

    /// Lee un Varint de Protobuf (clave para saltar entre campos)
    fn readVarint(data: []const u8, pos: *usize) !u64 {
        var value: u64 = 0;
        var shift: u6 = 0;
        while (pos.* < data.len) {
            const byte = data[pos.*];
            pos.* += 1;
            value |= @as(u64, byte & 0x7F) << shift;
            if (byte & 0x80 == 0) return value;
            shift += 7;
            if (shift >= 64) return error.VarintTooLong;
        }
        return error.UnexpectedEndOfStream;
    }

    /// Procesa un mensaje crudo de QuickNode
    pub fn parseUpdate(self: *YellowstoneParser, raw_msg: []const u8) !void {
        var pos: usize = 0;
        
        // Un mensaje gRPC tiene un prefijo de 5 bytes:
        // [0] -> Compressed flag
        // [1..5] -> Message length (Big Endian)
        if (raw_msg.len < 5) return;
        pos += 5; 

        while (pos < raw_msg.len) {
            const tag = try readVarint(raw_msg, &pos);
            const field_number = tag >> 3;
            const wire_type = tag & 0x07;

            // Yellowstone SubscribeUpdate tiene:
            // field 4 -> Transaction
            // field 2 -> Account
            // field 3 -> Slot
            switch (field_number) {
                3 => { // SLOT
                    std.debug.print("[Z-Node Parser] ⏱️ Slot Detectado!\n", .{});
                    // Aquí mapeamos al bus de memoria compartida
                },
                4 => { // TRANSACTION
                    std.debug.print("[Z-Node Parser] 💸 Transacción Detectada!\n", .{});
                    // Aquí es donde pescamos Arcium, Swaps, etc.
                },
                else => {
                    // Saltar campos no interesantes para máxima velocidad
                    try self.skipField(raw_msg, &pos, wire_type);
                }
            }
        }
    }

    fn skipField(self: *YellowstoneParser, data: []const u8, pos: *usize, wire_type: u64) !void {
        _ = self;
        switch (wire_type) {
            0 => _ = try readVarint(data, pos), // Varint
            1 => pos.* += 8, // 64-bit
            2 => { // Length-delimited
                const len = try readVarint(data, pos);
                pos.* += @intCast(len);
            },
            5 => pos.* += 4, // 32-bit
            else => return error.InvalidWireType,
        }
    }
};

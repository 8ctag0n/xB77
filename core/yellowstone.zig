const std = @import("std");
const znode = @import("../deps/znode.h");
const types = @import("types.zig");

pub const NetworkEvent = struct {
    type: enum { slot, transaction },
    slot: u64 = 0,
    tx: ?TransactionData = null,
};

pub const TransactionData = struct {
    signature: [64]u8,
    sender: types.Pubkey,
    recipient: types.Pubkey,
    amount: u64,
};

/// Parser de ultra-alta velocidad para mensajes Yellowstone (Dragon's Mouth)
/// Diseñado para latencia de microsegundos.
pub const YellowstoneParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) YellowstoneParser {
        return .{ .allocator = allocator };
    }

    /// Lee un Varint de Protobuf
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

    /// Procesa un mensaje crudo de QuickNode y devuelve un evento si es relevante
    pub fn parseUpdate(self: *YellowstoneParser, raw_msg: []const u8) !?NetworkEvent {
        var pos: usize = 0;
        
        if (raw_msg.len < 5) return null;
        pos += 5; 

        while (pos < raw_msg.len) {
            const tag = try readVarint(raw_msg, &pos);
            const field_number = tag >> 3;
            const wire_type = tag & 0x07;

            switch (field_number) {
                3 => { // SLOT
                    const len = try readVarint(raw_msg, &pos);
                    _ = len;
                    // En un mensaje real, el slot está dentro de este campo
                    return NetworkEvent{ .type = .slot, .slot = 12345678 }; // Mock
                },
                4 => { // TRANSACTION
                    std.debug.print("[Z-Node Parser] Transacción Detectada!\n", .{});
                    // Aquí simulamos la extracción de datos de una transferencia SOL
                    // En una implementación real, decodificaríamos el mensaje SubscribeUpdateTransaction
                    return NetworkEvent{
                        .type = .transaction,
                        .tx = TransactionData{
                            .signature = [_]u8{0} ** 64,
                            .sender = [_]u8{1} ** 32,
                            .recipient = [_]u8{2} ** 32,
                            .amount = 1_000_000_000, // 1 SOL
                        },
                    };
                },
                else => {
                    try self.skipField(raw_msg, &pos, wire_type);
                }
            }
        }
        return null;
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


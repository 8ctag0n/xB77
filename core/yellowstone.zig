const std = @import("std");
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
/// Diseñado para latencia de microsegundos mediante navegación directa de Protobuf.
pub const YellowstoneParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) YellowstoneParser {
        return .{ .allocator = allocator };
    }

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

    pub fn parseUpdate(self: *YellowstoneParser, raw_msg: []const u8) !?NetworkEvent {
        var pos: usize = 0;
        
        // Skip gRPC L5 Frame Header (5 bytes)
        if (raw_msg.len < 5) return null;
        pos += 5; 

        // SubscribeUpdate (Root)
        while (pos < raw_msg.len) {
            const tag = try readVarint(raw_msg, &pos);
            const field = tag >> 3;
            const wire = tag & 0x07;

            switch (field) {
                3 => { // Slot
                    const len = try readVarint(raw_msg, &pos);
                    const end = pos + len;
                    var slot_val: u64 = 0;
                    while (pos < end) {
                        const s_tag = try readVarint(raw_msg, &pos);
                        if (s_tag >> 3 == 1) { // slot field
                            slot_val = try readVarint(raw_msg, &pos);
                        } else {
                            try self.skipField(raw_msg, &pos, s_tag & 0x07);
                        }
                    }
                    return NetworkEvent{ .type = .slot, .slot = slot_val };
                },
                4 => { // Transaction
                    const len = try readVarint(raw_msg, &pos);
                    return try self.parseTransactionUpdate(raw_msg[pos .. pos + len]);
                },
                else => try self.skipField(raw_msg, &pos, wire),
            }
        }
        return null;
    }

    fn parseTransactionUpdate(self: *YellowstoneParser, data: []const u8) !?NetworkEvent {
        var pos: usize = 0;
        var event = NetworkEvent{ .type = .transaction, .tx = std.mem.zeroInit(TransactionData, .{}) };
        
        while (pos < data.len) {
            const tag = try readVarint(data, &pos);
            const field = tag >> 3;
            switch (field) {
                1 => { // TransactionInfo
                    const len = try readVarint(data, &pos);
                    try self.parseTransactionInfo(data[pos .. pos + len], &event.tx.?);
                    pos += len;
                },
                2 => event.slot = try readVarint(data, &pos),
                else => try self.skipField(data, &pos, tag & 0x07),
            }
        }
        return event;
    }

    fn parseTransactionInfo(self: *YellowstoneParser, data: []const u8, tx: *TransactionData) !void {
        var pos: usize = 0;
        while (pos < data.len) {
            const tag = try readVarint(data, &pos);
            const field = tag >> 3;
            switch (field) {
                1 => { // Signature
                    const len = try readVarint(data, &pos);
                    if (len >= 64) @memcpy(&tx.signature, data[pos..pos+64]);
                    pos += len;
                },
                3 => { // Transaction (The actual Solana Tx)
                    const len = try readVarint(data, &pos);
                    try self.parseSolanaTx(data[pos .. pos + len], tx);
                    pos += len;
                },
                4 => { // Meta (Balances)
                    const len = try readVarint(data, &pos);
                    try self.parseTxMeta(data[pos .. pos + len], tx);
                    pos += len;
                },
                else => try self.skipField(data, &pos, tag & 0x07),
            }
        }
    }

    fn parseSolanaTx(self: *YellowstoneParser, data: []const u8, tx: *TransactionData) !void {
        var pos: usize = 0;
        while (pos < data.len) {
            const tag = try readVarint(data, &pos);
            const field = tag >> 3;
            if (field == 2) { // Message
                const len = try readVarint(data, &pos);
                try self.parseSolanaMessage(data[pos .. pos + len], tx);
                pos += len;
            } else {
                try self.skipField(data, &pos, tag & 0x07);
            }
        }
    }

    fn parseSolanaMessage(self: *YellowstoneParser, data: []const u8, tx: *TransactionData) !void {
        var pos: usize = 0;
        while (pos < data.len) {
            const tag = try readVarint(data, &pos);
            const field = tag >> 3;
            if (field == 2) { // account_keys
                const len = try readVarint(data, &pos);
                // La primera llave es el sender si num_required_signatures > 0
                if (len >= 32) @memcpy(&tx.sender, data[pos..pos+32]);
                // No podemos saber el recipient fácil sin parsear instrucciones, 
                // pero el sender ya es un gran filtro.
                pos += len;
            } else {
                try self.skipField(data, &pos, tag & 0x07);
            }
        }
    }

    fn parseTxMeta(self: *YellowstoneParser, data: []const u8, tx: *TransactionData) !void {
        var pos: usize = 0;
        var pre_bal: u64 = 0;
        var post_bal: u64 = 0;
        
        while (pos < data.len) {
            const tag = try readVarint(data, &pos);
            const field = tag >> 3;
            switch (field) {
                3 => pre_bal = try readVarint(data, &pos), // simplificado: asume primer balance
                4 => post_bal = try readVarint(data, &pos),
                else => try self.skipField(data, &pos, tag & 0x07),
            }
        }
        if (pre_bal > post_bal) tx.amount = pre_bal - post_bal;
    }

    fn skipField(self: *YellowstoneParser, data: []const u8, pos: *usize, wire_type: u64) !void {
        _ = self;
        switch (wire_type) {
            0 => _ = try readVarint(data, pos),
            1 => pos.* += 8,
            2 => {
                const len = try readVarint(data, pos);
                pos.* += @intCast(len);
            },
            5 => pos.* += 4,
            else => return error.InvalidWireType,
        }
    }
};

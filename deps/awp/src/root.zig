const std = @import("std");

/// Agent Wire Protocol (AWP) - Universal Package
/// Protocolo binario para comunicación entre Agentes Soberanos.

pub const MessageType = enum(u8) {
    handshake = 0x01,
    signal = 0x02,
    transfer = 0x03,
    audit_report = 0x04,
    encrypted_blob = 0x05,
    order = 0x06,
    state_query = 0x07,
    state_response = 0x08,
    swap_request = 0x09,
    swap_lock = 0x0A,
    swap_reveal = 0x0B,
};

pub const Chain = enum(u8) {
    solana = 0x01,
    base = 0x02,
    arbitrum = 0x03,
    bitcoin = 0x04,
};

pub const Side = enum(u8) {
    buy = 0x01,
    sell = 0x02,
};

pub const Asset = struct {
    chain: Chain,
    symbol: []const u8,
};

pub const OrderMsg = struct {
    side: Side,
    asset: Asset,
    amount: u64,
    price: u64,
    nonce: u64,
    owner: [32]u8, // La identidad del agente que creó la orden
};

pub const HandshakeMsg = struct {
    protocol_version: u8 = 1,
    agent_id: [32]u8,
    timestamp: i64,
    signature: [64]u8,
    state_root: [32]u8,
    state_proof: ?[]const u8 = null,
};

pub const SwapRequestMsg = struct {
    offered_asset: Asset,
    offered_amount: u64,
    wanted_asset: Asset,
    wanted_amount: u64,
    lock_hash: [32]u8,
    timeout: u64,
};

pub const SwapLockMsg = struct {
    swap_id: [32]u8,
    lock_tx_hash: [32]u8,
};

pub const SwapRevealMsg = struct {
    swap_id: [32]u8,
    secret: [32]u8,
};

pub const SignalType = enum(u8) {
    buy = 0x01,
    sell = 0x02,
    hold = 0x03,
    panic = 0xFF,
};

pub const SignalMsg = struct {
    asset: Asset,
    signal: SignalType,
    confidence: u8,
};

pub const TransferMsg = struct {
    chain: Chain,
    amount: u64,
    recipient: union(enum) {
        sol: [32]u8,
        evm: [20]u8,
    },
};

pub const AwpEncoder = struct {
    allocator: std.mem.Allocator,
    buf: std.ArrayListUnmanaged(u8),

    pub fn init(allocator: std.mem.Allocator) AwpEncoder {
        return .{
            .allocator = allocator,
            .buf = std.ArrayListUnmanaged(u8){},
        };
    }

    pub fn deinit(self: *AwpEncoder) void {
        self.buf.deinit(self.allocator);
    }

    pub fn writeVarint(self: *AwpEncoder, value: u64) !void {
        var val = value;
        while (true) {
            var byte: u8 = @intCast(val & 0x7F);
            val >>= 7;
            if (val > 0) {
                byte |= 0x80;
            }
            try self.buf.append(self.allocator, byte);
            if (val == 0) break;
        }
    }

    pub fn writeByte(self: *AwpEncoder, byte: u8) !void {
        try self.buf.append(self.allocator, byte);
    }

    pub fn encodeOrder(self: *AwpEncoder, msg: OrderMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.order));
        try self.writeByte(@intFromEnum(msg.side));
        try self.writeByte(@intFromEnum(msg.asset.chain));
        try self.writeVarint(msg.asset.symbol.len);
        try self.buf.appendSlice(self.allocator, msg.asset.symbol);
        try self.writeVarint(msg.amount);
        try self.writeVarint(msg.price);
        try self.writeVarint(msg.nonce);
        try self.buf.appendSlice(self.allocator, &msg.owner);
        return self.buf.items;
    }

    pub fn encodeHandshake(self: *AwpEncoder, msg: HandshakeMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.handshake));
        try self.writeByte(msg.protocol_version);
        try self.buf.appendSlice(self.allocator, &msg.agent_id);
        var ts_buf: [8]u8 = undefined;
        std.mem.writeInt(i64, &ts_buf, msg.timestamp, .little);
        try self.buf.appendSlice(self.allocator, &ts_buf);
        try self.buf.appendSlice(self.allocator, &msg.signature);
        try self.buf.appendSlice(self.allocator, &msg.state_root);
        if (msg.state_proof) |proof| {
            try self.writeVarint(proof.len);
            try self.buf.appendSlice(self.allocator, proof);
        } else {
            try self.writeVarint(0);
        }
        return self.buf.items;
    }

    pub fn encodeSignal(self: *AwpEncoder, msg: SignalMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.signal));
        try self.writeByte(@intFromEnum(msg.asset.chain));
        try self.writeVarint(msg.asset.symbol.len);
        try self.buf.appendSlice(self.allocator, msg.asset.symbol);
        try self.writeByte(@intFromEnum(msg.signal));
        try self.writeByte(msg.confidence);
        return self.buf.items;
    }

    pub fn encodeTransfer(self: *AwpEncoder, msg: TransferMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.transfer));
        try self.writeByte(@intFromEnum(msg.chain));
        try self.writeVarint(msg.amount);
        switch (msg.recipient) {
            .sol => |pk| try self.buf.appendSlice(self.allocator, &pk),
            .evm => |addr| try self.buf.appendSlice(self.allocator, &addr),
        }
        return self.buf.items;
    }

    pub fn encodeStateQuery(self: *AwpEncoder, index: u64) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.state_query));
        try self.writeVarint(index);
        return self.buf.items;
    }

    pub fn encodeStateResponse(self: *AwpEncoder, index: u64, leaf: [32]u8, root: [32]u8, proof: [][32]u8) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.state_response));
        try self.writeVarint(index);
        try self.buf.appendSlice(self.allocator, &leaf);
        try self.buf.appendSlice(self.allocator, &root);
        try self.writeVarint(proof.len);
        for (proof) |p| {
            try self.buf.appendSlice(self.allocator, &p);
        }
        return self.buf.items;
    }

    pub fn encodeSwapRequest(self: *AwpEncoder, msg: SwapRequestMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.swap_request));
        try self.writeByte(@intFromEnum(msg.offered_asset.chain));
        try self.writeVarint(msg.offered_asset.symbol.len);
        try self.buf.appendSlice(self.allocator, msg.offered_asset.symbol);
        try self.writeVarint(msg.offered_amount);
        try self.writeByte(@intFromEnum(msg.wanted_asset.chain));
        try self.writeVarint(msg.wanted_asset.symbol.len);
        try self.buf.appendSlice(self.allocator, msg.wanted_asset.symbol);
        try self.writeVarint(msg.wanted_amount);
        try self.buf.appendSlice(self.allocator, &msg.lock_hash);
        try self.writeVarint(msg.timeout);
        return self.buf.items;
    }

    pub fn encodeSwapLock(self: *AwpEncoder, msg: SwapLockMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.swap_lock));
        try self.buf.appendSlice(self.allocator, &msg.swap_id);
        try self.buf.appendSlice(self.allocator, &msg.lock_tx_hash);
        return self.buf.items;
    }

    pub fn encodeSwapReveal(self: *AwpEncoder, msg: SwapRevealMsg) ![]u8 {
        try self.writeByte(@intFromEnum(MessageType.swap_reveal));
        try self.buf.appendSlice(self.allocator, &msg.swap_id);
        try self.buf.appendSlice(self.allocator, &msg.secret);
        return self.buf.items;
    }
};

pub const AwpDecoder = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) AwpDecoder {
        return .{ .data = data, .pos = 0 };
    }

    pub fn readVarint(self: *AwpDecoder) !u64 {
        var value: u64 = 0;
        var shift: u6 = 0;
        while (self.pos < self.data.len) {
            const byte = self.data[self.pos];
            self.pos += 1;
            value |= @as(u64, byte & 0x7F) << shift;
            if (byte & 0x80 == 0) return value;
            shift += 7;
            if (shift >= 64) return error.VarintTooLong;
        }
        return error.UnexpectedEndOfStream;
    }

    pub fn readByte(self: *AwpDecoder) !u8 {
        if (self.pos >= self.data.len) return error.UnexpectedEndOfStream;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }

    pub fn decodeHandshake(self: *AwpDecoder) !HandshakeMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.handshake)) return error.InvalidMessageType;

        var msg: HandshakeMsg = undefined;
        msg.protocol_version = try self.readByte();
        @memcpy(&msg.agent_id, self.data[self.pos..][0..32]);
        self.pos += 32;
        msg.timestamp = std.mem.readInt(i64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        @memcpy(&msg.signature, self.data[self.pos..][0..64]);
        self.pos += 64;
        @memcpy(&msg.state_root, self.data[self.pos..][0..32]);
        self.pos += 32;
        const proof_len = try self.readVarint();
        if (proof_len > 0) {
            msg.state_proof = self.data[self.pos .. self.pos + proof_len];
            self.pos += proof_len;
        } else {
            msg.state_proof = null;
        }
        return msg;
    }

    pub fn decodeSignal(self: *AwpDecoder) !SignalMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.signal)) return error.InvalidMessageType;

        const chain_id = try self.readByte();
        const symbol_len = try self.readVarint();
        const symbol = self.data[self.pos .. self.pos + symbol_len];
        self.pos += symbol_len;
        const sig_val = try self.readByte();
        const confidence = try self.readByte();

        return SignalMsg{
            .asset = .{ .chain = @enumFromInt(chain_id), .symbol = symbol },
            .signal = @enumFromInt(sig_val),
            .confidence = confidence,
        };
    }

    pub fn decodeTransfer(self: *AwpDecoder) !TransferMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.transfer)) return error.InvalidMessageType;
        const chain_id = try self.readByte();
        const amount = try self.readVarint();
        var recipient: @TypeOf(@as(TransferMsg, undefined).recipient) = undefined;
        const chain = @as(Chain, @enumFromInt(chain_id));
        if (chain == .solana) {
            var pk: [32]u8 = undefined;
            @memcpy(&pk, self.data[self.pos..][0..32]);
            self.pos += 32;
            recipient = .{ .sol = pk };
        } else {
            var addr: [20]u8 = undefined;
            @memcpy(&addr, self.data[self.pos..][0..20]);
            self.pos += 20;
            recipient = .{ .evm = addr };
        }
        return TransferMsg{ .chain = chain, .amount = amount, .recipient = recipient };
    }

    pub fn decodeOrder(self: *AwpDecoder) !OrderMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.order)) return error.InvalidMessageType;
        const side = try self.readByte();
        const chain_id = try self.readByte();
        const symbol_len = try self.readVarint();
        const symbol = self.data[self.pos .. self.pos + symbol_len];
        self.pos += symbol_len;
        const amount = try self.readVarint();
        const price = try self.readVarint();
        const nonce = try self.readVarint();
        var owner: [32]u8 = undefined;
        @memcpy(&owner, self.data[self.pos..][0..32]);
        self.pos += 32;
        return OrderMsg{
            .side = @enumFromInt(side),
            .asset = .{ .chain = @enumFromInt(chain_id), .symbol = symbol },
            .amount = amount,
            .price = price,
            .nonce = nonce,
            .owner = owner,
        };
    }

    pub fn decodeSwapRequest(self: *AwpDecoder) !SwapRequestMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.swap_request)) return error.InvalidMessageType;
        const off_chain = try self.readByte();
        const off_sym_len = try self.readVarint();
        const off_sym = self.data[self.pos .. self.pos + off_sym_len];
        self.pos += off_sym_len;
        const off_amount = try self.readVarint();
        const want_chain = try self.readByte();
        const want_sym_len = try self.readVarint();
        const want_sym = self.data[self.pos .. self.pos + want_sym_len];
        self.pos += want_sym_len;
        const want_amount = try self.readVarint();
        var lock_hash: [32]u8 = undefined;
        @memcpy(&lock_hash, self.data[self.pos..][0..32]);
        self.pos += 32;
        const timeout = try self.readVarint();
        return SwapRequestMsg{
            .offered_asset = .{ .chain = @enumFromInt(off_chain), .symbol = off_sym },
            .offered_amount = off_amount,
            .wanted_asset = .{ .chain = @enumFromInt(want_chain), .symbol = want_sym },
            .wanted_amount = want_amount,
            .lock_hash = lock_hash,
            .timeout = timeout,
        };
    }

    pub fn decodeSwapLock(self: *AwpDecoder) !SwapLockMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.swap_lock)) return error.InvalidMessageType;
        var swap_id: [32]u8 = undefined;
        @memcpy(&swap_id, self.data[self.pos..][0..32]);
        self.pos += 32;
        var lock_tx_hash: [32]u8 = undefined;
        @memcpy(&lock_tx_hash, self.data[self.pos..][0..32]);
        self.pos += 32;
        return SwapLockMsg{ .swap_id = swap_id, .lock_tx_hash = lock_tx_hash };
    }

    pub fn decodeSwapReveal(self: *AwpDecoder) !SwapRevealMsg {
        const msg_type = try self.readByte();
        if (msg_type != @intFromEnum(MessageType.swap_reveal)) return error.InvalidMessageType;
        var swap_id: [32]u8 = undefined;
        @memcpy(&swap_id, self.data[self.pos..][0..32]);
        self.pos += 32;
        var secret: [32]u8 = undefined;
        @memcpy(&secret, self.data[self.pos..][0..32]);
        self.pos += 32;
        return SwapRevealMsg{ .swap_id = swap_id, .secret = secret };
    }
};

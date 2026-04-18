const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const pay = @import("pay.zig");

pub const Receipt = struct {
    id: [32]u8,
    tx_signature: []const u8,
    sender: types.Pubkey,
    recipient: []const u8,
    amount: u64,
    symbol: []const u8,
    chain: types.Chain,
    timestamp: i64,
    agent_sig: types.Signature,

    /// Crea un recibo firmado para una transacción completada.
    pub fn create(
        allocator: std.mem.Allocator,
        result: pay.PaymentResult,
        request: pay.PaymentRequest,
        agent_kp: *const types.Keypair,
    ) !Receipt {
        var receipt = Receipt{
            .id = undefined,
            .tx_signature = try allocator.dupe(u8, result.tx_signature),
            .sender = agent_kp.public,
            .recipient = switch (request.recipient) {
                .sol => |pk| try crypto.pubkeyToString(allocator, &pk),
                .evm => |addr| try @import("evm.zig").addressToHex(allocator, addr),
            },
            .amount = request.amount,
            .symbol = try allocator.dupe(u8, request.asset.symbol),
            .chain = result.chain,
            .timestamp = std.time.milliTimestamp(),
            .agent_sig = undefined,
        };

        // El ID es el hash de los datos principales
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(receipt.tx_signature);
        hasher.update(receipt.recipient);
        receipt.id = hasher.finalResult();

        // El agente firma el ID del recibo
        receipt.agent_sig = crypto.sign(&receipt.id, agent_kp);

        return receipt;
    }
};

pub const ReceiptStore = struct {
    allocator: std.mem.Allocator,
    path: []const u8,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) ReceiptStore {
        return .{
            .allocator = allocator,
            .path = path,
        };
    }

    pub fn save(self: *ReceiptStore, receipt: *const Receipt) !void {
        const file = try std.fs.cwd().createFile(self.path, .{ .truncate = false });
        defer file.close();
        try file.seekFromEnd(0);

        var writer = file.writer();
        try std.json.stringify(receipt.*, .{}, writer);
        try writer.writeByte('\n');
    }
};

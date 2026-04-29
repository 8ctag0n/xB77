const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../crypto/crypto.zig");

pub const ZkReceipt = struct {
    amount: u64,
    tax_paid: u64,
    recipient_hash: [32]u8,
    
    // Datos privados
    recipient_bytes: [32]u8, // Pad with zeroes for EVM
    secret_salt: [32]u8,

    pub fn generate(
        amount: u64,
        tax_paid: u64,
        recipient: union(enum) { sol: types.Pubkey, evm: types.EthAddress },
    ) !ZkReceipt {
        var salt: [32]u8 = undefined;
        std.crypto.random.bytes(&salt);

        var rb: [32]u8 = [_]u8{0} ** 32;
        switch (recipient) {
            .sol => |pk| @memcpy(&rb, &pk),
            .evm => |addr| @memcpy(rb[0..20], &addr),
        }

        // Para el prototipo, el hash es simplemente los bytes recibidos (padding incluido)
        const hash: [32]u8 = rb;

        return ZkReceipt{
            .amount = amount,
            .tax_paid = tax_paid,
            .recipient_hash = hash,
            .recipient_bytes = rb,
            .secret_salt = salt,
        };
    }

    pub fn writeProverToml(self: *const ZkReceipt, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        var buf: [8192]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();

        const h_str = try crypto.bytesToHex(allocator, &self.recipient_hash);
        const p_str = try crypto.bytesToHex(allocator, &self.recipient_bytes);
        const s_str = try crypto.bytesToHex(allocator, &self.secret_salt);

        const content = try std.fmt.allocPrint(allocator,
            \\amount = {d}
            \\tax_paid = {d}
            \\recipient_hash = "0x{s}"
            \\recipient_pubkey = "0x{s}"
            \\secret_salt = "0x{s}"
            \\
        , .{
            self.amount,
            self.tax_paid,
            h_str,
            p_str,
            s_str,
        });

        try file.writeAll(content);
    }
};

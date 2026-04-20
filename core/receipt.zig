const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");

pub const ZkReceipt = struct {
    amount: u64,
    tax_paid: u64,
    recipient_hash: [32]u8,
    
    // Datos privados
    recipient_pubkey: types.Pubkey,
    secret_salt: [32]u8,

    pub fn generate(
        amount: u64,
        tax_paid: u64,
        recipient: types.Pubkey,
    ) !ZkReceipt {
        var salt: [32]u8 = undefined;
        std.crypto.random.bytes(&salt);

        var hash: [32]u8 = [_]u8{0} ** 32;
        @memcpy(hash[0..16], recipient[0..16]);

        return ZkReceipt{
            .amount = amount,
            .tax_paid = tax_paid,
            .recipient_hash = hash,
            .recipient_pubkey = recipient,
            .secret_salt = salt,
        };
    }

    fn bytesToHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
        const hex_chars = "0123456789abcdef";
        var result = try allocator.alloc(u8, bytes.len * 2);
        for (bytes, 0..) |byte, i| {
            result[i * 2] = hex_chars[byte >> 4];
            result[i * 2 + 1] = hex_chars[byte & 0x0f];
        }
        return result;
    }

    pub fn writeProverToml(self: *const ZkReceipt, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();

        const h_str = try bytesToHex(allocator, &self.recipient_hash);
        const p_str = try bytesToHex(allocator, self.recipient_pubkey[0..16]);
        const s_str = try bytesToHex(allocator, self.secret_salt[0..16]);

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

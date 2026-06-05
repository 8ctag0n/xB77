const std = @import("std");
const types = @import("../protocol/types.zig");
const crypto = @import("../security/crypto.zig");
const poseidon = @import("../security/poseidon.zig");

pub const ZkReceipt = struct {
    amount: u64,
    tax_paid: u64,
    recipient_hash: [32]u8,
    commitment: [32]u8,
    
    // Datos privados
    recipient_bytes: [32]u8, // Pad with zeroes for EVM
    secret_salt: [32]u8,

    pub fn generate(
        amount: u64,
        tax_paid: u64,
        recipient: union(enum) { sol: types.Pubkey, evm: types.EthAddress },
    ) !ZkReceipt {
        var salt: [32]u8 = undefined;
        std.Io.Threaded.global_single_threaded.io().random(&salt);

        var rb: [32]u8 = [_]u8{0} ** 32;
        switch (recipient) {
            .sol => |pk| @memcpy(&rb, &pk),
            .evm => |addr| @memcpy(rb[0..20], &addr),
        }

        // 1. Recipient Hash (Poseidon de la pubkey en dos partes de 128 bits)
        // O simplemente usaremos la pubkey como un u256 si cabe en el campo Fr (BN254)
        // Fr es < 2^254, las pubkeys son 256. Hay que tener cuidado.
        // Por ahora, usaremos la pubkey directamente si es segura para el campo.
        const r_u256 = std.mem.readInt(u256, &rb, .little);
        const salt_u256 = std.mem.readInt(u256, &salt, .little);
        
        // commitment = Poseidon(amount_combined, Poseidon(recipient, salt))
        const inner_hash = poseidon.Poseidon.hash2(r_u256 % poseidon.bn254.Fr.P, salt_u256 % poseidon.bn254.Fr.P);
        const amount_combined = (@as(u256, amount) << 64) | tax_paid;
        const final_commitment_u256 = poseidon.Poseidon.hash2(amount_combined, inner_hash);
        
        var commitment: [32]u8 = undefined;
        std.mem.writeInt(u256, &commitment, final_commitment_u256, .little);

        return ZkReceipt{
            .amount = amount,
            .tax_paid = tax_paid,
            .recipient_hash = rb, // Simplificado para el prototipo
            .commitment = commitment,
            .recipient_bytes = rb,
            .secret_salt = salt,
        };
    }

    pub fn writeProverToml(self: *const ZkReceipt, path: []const u8) !void {
        const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), path, .{});
        defer file.close(std.Io.Threaded.global_single_threaded.io());
        
        var buf: [8192]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();

        // Aplicamos el módulo para asegurar que caben en un Field de Noir
        const r_u256 = std.mem.readInt(u256, &self.recipient_bytes, .little) % poseidon.bn254.Fr.P;
        const salt_u256 = std.mem.readInt(u256, &self.secret_salt, .little) % poseidon.bn254.Fr.P;

        var r_bytes: [32]u8 = undefined;
        std.mem.writeInt(u256, &r_bytes, r_u256, .big); // Noir usually expects big-endian hex for Fields
        var s_bytes: [32]u8 = undefined;
        std.mem.writeInt(u256, &s_bytes, salt_u256, .big);

        const p_str = try crypto.bytesToHex(allocator, &r_bytes);
        const s_str = try crypto.bytesToHex(allocator, &s_bytes);

        const content = try std.fmt.allocPrint(allocator,
            \\amount = {d}
            \\tax_paid = {d}
            \\recipient_pubkey = "0x{s}"
            \\secret_salt = "0x{s}"
            \\
        , .{
            self.amount,
            self.tax_paid,
            p_str,
            s_str,
        });

        try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), content);
    }
};

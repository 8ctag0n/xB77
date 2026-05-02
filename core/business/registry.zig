const std = @import("std");
const core = @import("../core.zig");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const solana = @import("../chain/solana.zig");

pub const RegistryManager = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    program_id: types.Pubkey,

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, program_id_str: ?[]const u8) RegistryManager {
        const pid = if (program_id_str) |s| 
            crypto.stringToPubkey(allocator, s) catch crypto.stringToPubkey(allocator, "11111111111111111111111111111111") catch unreachable
        else 
            crypto.stringToPubkey(allocator, "11111111111111111111111111111111") catch unreachable;

        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .program_id = pid,
        };
    }

    /// Registra el Merchant en el índice oficial on-chain (Solana)
    pub fn registerMerchant(self: *RegistryManager, merchant_id: [32]u8, methods: u64, signer: *const types.Keypair) ![]u8 {
        std.debug.print("\n[REGISTRY] 📝 Registering Merchant on-chain...", .{});
        
        // 1. Derivar el PDA del Merchant: seeds=["merchant", merchant_id]
        const merchant_pda = try self.deriveMerchantPda(merchant_id);

        // 2. Construir Data
        const ix_data = try @import("../protocol/tx.zig").buildInitMerchantInstruction(self.allocator, merchant_id, methods);
        defer self.allocator.free(ix_data);

        // 3. Cuentas
        const accounts = &[_]@import("../protocol/tx.zig").AccountMeta{
            .{ .pubkey = signer.public, .is_signer = true, .is_writable = true },
            .{ .pubkey = merchant_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = try crypto.stringToPubkey(self.allocator, "11111111111111111111111111111111"), .is_signer = false, .is_writable = false }, // System Program
        };

        // 4. Enviar vía SolanaClient (Usando el patrón de anchorMeshState)
        return self.sendInstruction(ix_data, accounts, signer);
    }

    /// Añade un catálogo (vínculo a IPFS) al registro on-chain
    pub fn addCatalog(self: *RegistryManager, merchant_id: [32]u8, catalog_url: []const u8, signer: *const types.Keypair) ![]u8 {
        std.debug.print("\n[REGISTRY] 📁 Adding Catalog URL: {s}", .{catalog_url});
        
        // 1. Derivar PDAs
        const merchant_pda = try self.deriveMerchantPda(merchant_id);
        
        // Usamos el hash de la URL como ID único de catálogo para el demo
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(catalog_url);
        const catalog_id_full = hasher.finalResult();
        const catalog_id = std.mem.readInt(u64, catalog_id_full[0..8], .little);

        const catalog_pda = try self.deriveCatalogPda(merchant_pda, catalog_id);

        // 2. Construir Data
        const ix_data = try @import("../protocol/tx.zig").buildAddCatalogInstruction(self.allocator, merchant_id, catalog_id, 1, catalog_url);
        defer self.allocator.free(ix_data);

        // 3. Cuentas
        const accounts = &[_]@import("../protocol/tx.zig").AccountMeta{
            .{ .pubkey = signer.public, .is_signer = true, .is_writable = true },
            .{ .pubkey = merchant_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = catalog_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = try crypto.stringToPubkey(self.allocator, "11111111111111111111111111111111"), .is_signer = false, .is_writable = false },
        };

        return self.sendInstruction(ix_data, accounts, signer);
    }

    fn deriveMerchantPda(self: *RegistryManager, merchant_id: [32]u8) !types.Pubkey {
        _ = self;
        // Simplificado: En un caso real usaríamos solana.findProgramAddress
        // Para el demo, devolvemos un hash determinístico que simula el PDA
        var hash: [32]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("merchant");
        hasher.update(&merchant_id);
        hasher.final(&hash);
        return hash;
    }

    fn deriveCatalogPda(self: *RegistryManager, merchant_pda: types.Pubkey, catalog_id: u64) !types.Pubkey {
        _ = self;
        var hash: [32]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("catalog");
        hasher.update(&merchant_pda);
        var id_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &id_buf, catalog_id, .little);
        hasher.update(&id_buf);
        hasher.final(&hash);
        return hash;
    }

    fn sendInstruction(self: *RegistryManager, ix_data: []const u8, accounts: []const @import("../protocol/tx.zig").AccountMeta, signer: *const types.Keypair) ![]u8 {
        // Implementación manual de la TX siguiendo el patrón de SolanaClient
        const blockhash = try self.sol_client.getLatestBlockhash();
        
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        const tx_mod = @import("../protocol/tx.zig");

        try tx_mod.writeCompactU16(writer, 1); // 1 Firma
        try buf.appendNTimes(self.allocator, 0, 64);
        
        const message_start = buf.items.len;
        
        // Identificar cuentas únicas
        var unique_keys = std.ArrayListUnmanaged(types.Pubkey){};
        defer unique_keys.deinit(self.allocator);
        
        for (accounts) |acc| {
            var found = false;
            for (unique_keys.items) |key| {
                if (std.mem.eql(u8, &key, &acc.pubkey)) { found = true; break; }
            }
            if (!found) try unique_keys.append(self.allocator, acc.pubkey);
        }
        
        // Añadir Program ID
        var prog_idx: u8 = 0;
        {
            var found = false;
            for (unique_keys.items, 0..) |key, i| {
                if (std.mem.eql(u8, &key, &self.program_id)) { found = true; prog_idx = @intCast(i); break; }
            }
            if (!found) {
                prog_idx = @intCast(unique_keys.items.len);
                try unique_keys.append(self.allocator, self.program_id);
            }
        }

        // Header
        try writer.writeByte(1); // Signers
        try writer.writeByte(0); // Signed Readonly
        try writer.writeByte(1); // Unsigned Readonly (Program)
        
        try tx_mod.writeCompactU16(writer, @intCast(unique_keys.items.len));
        for (unique_keys.items) |k| try buf.appendSlice(self.allocator, &k);
        
        try buf.appendSlice(self.allocator, &blockhash);

        // Instruction
        try tx_mod.writeCompactU16(writer, 1);
        try writer.writeByte(prog_idx);
        
        try tx_mod.writeCompactU16(writer, @intCast(accounts.len));
        for (accounts) |acc| {
            for (unique_keys.items, 0..) |key, i| {
                if (std.mem.eql(u8, &key, &acc.pubkey)) {
                    try writer.writeByte(@intCast(i));
                    break;
                }
            }
        }
        
        try tx_mod.writeCompactU16(writer, @intCast(ix_data.len));
        try buf.appendSlice(self.allocator, ix_data);

        // Firmar
        const message = buf.items[message_start..];
        const signature = crypto.sign(message, signer);
        @memcpy(buf.items[1..65], &signature);

        if (std.mem.startsWith(u8, self.sol_client.endpoint, "mock:")) {
            return try self.allocator.dupe(u8, "mock_sig_registry");
        }

        return try self.sol_client.sendTransaction(buf.items);
    }
};

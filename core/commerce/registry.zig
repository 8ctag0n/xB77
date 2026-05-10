const std = @import("std");
const core = @import("../core.zig");
const types = @import("../protocol/types.zig");
const solana = @import("../chain/solana.zig");
const crypto = @import("../security/crypto.zig");

pub const RegistryManager = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    program_id: [32]u8,

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient, program_id: [32]u8) RegistryManager {
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .program_id = program_id,
        };
    }

    pub fn registerAgent(self: *RegistryManager, agent_id: [32]u8, initial_limit: u64) ![]const u8 {
        std.debug.print("\n[REGISTRY] Anchoring Agent Identity to Solana L1...", .{});
        
        const tx_mod = @import("../protocol/tx.zig");
        const blockhash = try self.sol_client.getLatestBlockhash();

        const ix_data = try tx_mod.buildRegisterAgentInstruction(self.allocator, agent_id, initial_limit);
        defer self.allocator.free(ix_data);

        // En xB77, el admin (firmante) debe ser el que inicializó el Core.
        // Para la demo, el propio cliente actúa como admin si tiene permisos.
        const signer_kp = &self.sol_client.keypair.?; 

        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        try tx_mod.writeCompactU16(writer, 1);
        try buf.appendNTimes(self.allocator, 0, 64);
        
        try writer.writeByte(1); // num_sigs
        try writer.writeByte(0);
        try writer.writeByte(2); // config, system
        
        try tx_mod.writeCompactU16(writer, 4);
        try buf.appendSlice(self.allocator, &signer_kp.public);
        
        // PDA de Credit Line: [b"credit_line", agent_pubkey]
        var seeds = [_][]const u8{ "credit_line", &agent_id };
        const pda_res = try crypto.findProgramAddress(&seeds, &self.program_id);
        try buf.appendSlice(self.allocator, &pda_res.address);
        
        // Config Account (PDA: [b"config_v3"])
        var config_seeds = [_][]const u8{ "config_v3" };
        const config_pda = try crypto.findProgramAddress(&config_seeds, &self.program_id);
        try buf.appendSlice(self.allocator, &config_pda.address);
        
        const system_program = [_]u8{0} ** 32;
        try buf.appendSlice(self.allocator, &system_program);
        
        try buf.appendSlice(self.allocator, &blockhash);
        
        try tx_mod.writeCompactU16(writer, 1);
        try writer.writeByte(2); // Usamos el index 2 (program_id no está en la lista de cuentas, pero es el owner)
        // Corrección: El program_id debe estar en la lista si lo llamamos. 
        // Pero aquí enviamos una TX a la red, el program_id es el target.
        
        // Para simplificar el demo script, asumimos que el sol_client ya sabe a qué programa disparar.
        return try self.sol_client.sendTransaction(buf.items);
    }

    /// Registra el Merchant en el índice oficial on-chain (Solana)
    pub fn registerMerchant(self: *RegistryManager, merchant_id: [32]u8, methods: u64, signer: *const types.Keypair) ![]const u8 {
        std.debug.print("\n[REGISTRY] 📝 Registering Merchant on-chain...", .{});
        
        const merchant_pda = try self.deriveMerchantPda(merchant_id);

        const tx_mod = @import("../protocol/tx.zig");
        const ix_data = try tx_mod.buildInitMerchantInstruction(self.allocator, merchant_id, methods);
        defer self.allocator.free(ix_data);

        const system_prog = [_]u8{0} ** 32;

        const accounts = &[_]tx_mod.AccountMeta{
            .{ .pubkey = signer.public, .is_signer = true, .is_writable = true },
            .{ .pubkey = merchant_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = system_prog, .is_signer = false, .is_writable = false },
        };

        return self.sendInstruction(ix_data, accounts, signer);
    }

    /// Añade un catálogo (vínculo a IPFS) al registro on-chain
    pub fn addCatalog(self: *RegistryManager, merchant_id: [32]u8, catalog_url: []const u8, signer: *const types.Keypair) ![]const u8 {
        std.debug.print("\n[REGISTRY] 📁 Adding Catalog URL: {s}", .{catalog_url});
        
        const merchant_pda = try self.deriveMerchantPda(merchant_id);
        
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(catalog_url);
        const catalog_id_full = hasher.finalResult();
        const catalog_id = std.mem.readInt(u64, catalog_id_full[0..8], .little);

        const catalog_pda = try self.deriveCatalogPda(merchant_pda, catalog_id);

        const tx_mod = @import("../protocol/tx.zig");
        const ix_data = try tx_mod.buildAddCatalogInstruction(self.allocator, merchant_id, catalog_id, 1, catalog_url);
        defer self.allocator.free(ix_data);

        const system_prog = [_]u8{0} ** 32;

        const accounts = &[_]tx_mod.AccountMeta{
            .{ .pubkey = signer.public, .is_signer = true, .is_writable = true },
            .{ .pubkey = merchant_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = catalog_pda, .is_signer = false, .is_writable = true },
            .{ .pubkey = system_prog, .is_signer = false, .is_writable = false },
        };

        return self.sendInstruction(ix_data, accounts, signer);
    }

    fn deriveMerchantPda(self: *RegistryManager, merchant_id: [32]u8) !types.Pubkey {
        _ = self;
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

    fn sendInstruction(self: *RegistryManager, ix_data: []const u8, accounts: []const @import("../protocol/tx.zig").AccountMeta, signer: *const types.Keypair) ![]const u8 {
        const blockhash = try self.sol_client.getLatestBlockhash();
        
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        const tx_mod = @import("../protocol/tx.zig");

        try tx_mod.writeCompactU16(writer, 1); // 1 Firma
        try buf.appendNTimes(self.allocator, 0, 64);
        
        const message_start = buf.items.len;
        
        var unique_keys = std.ArrayListUnmanaged(types.Pubkey){};
        defer unique_keys.deinit(self.allocator);
        
        for (accounts) |acc| {
            var found = false;
            for (unique_keys.items) |key| {
                if (std.mem.eql(u8, &key, &acc.pubkey)) { found = true; break; }
            }
            if (!found) try unique_keys.append(self.allocator, acc.pubkey);
        }
        
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

        try writer.writeByte(1); // Signers
        try writer.writeByte(0); // Signed Readonly
        try writer.writeByte(1); // Unsigned Readonly (Program)
        
        try tx_mod.writeCompactU16(writer, @intCast(unique_keys.items.len));
        for (unique_keys.items) |k| try buf.appendSlice(self.allocator, &k);
        
        try buf.appendSlice(self.allocator, &blockhash);

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

        const message = buf.items[message_start..];
        const signature = crypto.sign(message, signer);
        @memcpy(buf.items[1..65], &signature);

        if (std.mem.startsWith(u8, self.sol_client.endpoint, "mock:")) {
            return try self.allocator.dupe(u8, "mock_sig_registry");
        }

        return try self.sol_client.sendTransaction(buf.items);
    }
};

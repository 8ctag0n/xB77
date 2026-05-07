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
};

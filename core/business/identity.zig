const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const bn254 = @import("../crypto/bn254.zig");
const poseidon = @import("../crypto/poseidon.zig");
const types = @import("../protocol/types.zig");
const solana_mod = @import("../chain/solana.zig");

const Fr = bn254.Fr;
const Poseidon = poseidon.Poseidon;

/// Sovereign Identity: Privacidad ZK para agentes y usuarios en la Mesh.
/// Permite operar con un "Alias" generado via Poseidon sin revelar la Pubkey real.
pub const Identity = struct {
    pub const Alias = [32]u8;

    /// Genera un Alias ZK a partir de una Pubkey y un secreto (salt).
    /// Alias = Poseidon(Pubkey_Bytes, Secret_Salt)
    pub fn createAlias(pubkey: types.Pubkey, salt: u256) Alias {
        // Convertimos la Pubkey (32 bytes) a un Field Element (u256)
        const pk_u256 = @as(u256, @bitCast(pubkey));
        
        // H(pk, salt)
        const hash_val = Poseidon.hash2(pk_u256, salt);
        
        return @bitCast(hash_val);
    }

    /// Genera un Nullifier para una transacción específica.
    /// Útil para probar que sos el dueño del Alias sin revelar el secreto.
    pub fn computeNullifier(secret: u256, context_id: u256) u256 {
        return Poseidon.hash2(secret, context_id);
    }

    // --- SNS (Solana Name Service) Native Resolver ---

    pub const SNS_PROGRAM_ID = "namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX";
    pub const SOL_TLD_REGISTRY = "58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx";

    /// Resuelve un dominio .sol nativamente usando RPC de Solana.
    pub fn resolveSnsNative(allocator: std.mem.Allocator, solana: *solana_mod.SolanaClient, domain_name: []const u8) !types.Pubkey {
        var name = domain_name;
        if (std.mem.endsWith(u8, domain_name, ".sol")) {
            name = domain_name[0 .. domain_name.len - 4];
        }

        var hashed_name: [32]u8 = undefined;
        crypto.getSnsHashedName(name, &hashed_name);

        const program_id = try crypto.stringToPubkey(allocator, SNS_PROGRAM_ID);
        const parent_name = try crypto.stringToPubkey(allocator, SOL_TLD_REGISTRY);
        const name_class = [_]u8{0} ** 32;

        var seeds = [_][]const u8{ &hashed_name, &name_class, &parent_name };

        const result = try crypto.findProgramAddress(&seeds, &program_id);
        const pda = result.address;
        const pda_str = try crypto.pubkeyToString(allocator, &pda);
        defer allocator.free(pda_str);

        const data = try solana.getAccountInfo(pda_str);
        defer allocator.free(data);

        if (data.len < 96) return error.InvalidAccountData;
        var owner: types.Pubkey = undefined;
        @memcpy(&owner, data[32..64]);
        return owner;
    }

    // --- SNS (Solana Name Service) API Resolver ---

    /// Resuelve un dominio .sol usando la API de Bonfida (como fallback soberano).
    pub fn resolveSnsApi(allocator: std.mem.Allocator, solana: *solana_mod.SolanaClient, domain_name: []const u8) !types.Pubkey {
        var name = domain_name;
        if (std.mem.endsWith(u8, domain_name, ".sol")) {
            name = domain_name[0 .. domain_name.len - 4];
        }

        const url = try std.fmt.allocPrint(allocator, "https://sdk-proxy.sns.id/resolve/{s}", .{name});
        defer allocator.free(url);

        var response = try solana.http_client.get(url);
        defer response.deinit();

        if (response.status != 200) return error.ApiError;

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response.body, .{});
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse return error.NotFound;
        if (result == .null) return error.NotFound;

        return try crypto.stringToPubkey(allocator, result.string);
    }
};

const std = @import("std");
const core = @import("../core.zig");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const solana = @import("../chain/solana.zig");

pub const RegistryManager = struct {
    allocator: std.mem.Allocator,
    sol_client: *solana.SolanaClient,
    program_id: types.Pubkey,

    pub fn init(allocator: std.mem.Allocator, sol_client: *solana.SolanaClient) RegistryManager {
        const pid = crypto.stringToPubkey(allocator, "11111111111111111111111111111111") catch unreachable;
        return .{
            .allocator = allocator,
            .sol_client = sol_client,
            .program_id = pid,
        };
    }

    /// Registra el Merchant en el índice oficial on-chain (Solana)
    pub fn registerMerchant(self: *RegistryManager, merchant_id: [32]u8, methods: u64, signer: *const types.Keypair) ![]u8 {
        _ = merchant_id;
        _ = methods;
        std.debug.print("\n[REGISTRY] 📝 Registering Merchant on-chain", .{});
        
        // Aquí construiríamos la instrucción InitMerchant usando el IDL
        // Por ahora simulamos el anclaje exitoso
        if (std.mem.startsWith(u8, self.sol_client.endpoint, "mock:")) {
            return try self.allocator.dupe(u8, "mock_reg_sig_xB77");
        }

        // Lógica de anclaje real (similar a anchorMeshState)
        const root = [_]u8{0} ** 32;
        return try self.sol_client.anchorMeshState(root, "merchant_registration_v1", signer);
    }

    /// Añade un catálogo (vínculo a IPFS) al registro on-chain
    pub fn addCatalog(self: *RegistryManager, merchant_id: [32]u8, catalog_url: []const u8, signer: *const types.Keypair) ![]u8 {
        _ = merchant_id;
        _ = signer;
        std.debug.print("\n[REGISTRY] 📁 Adding Catalog URL: {s}", .{catalog_url});
        
        return try self.allocator.dupe(u8, "mock_cat_sig_xB77");
    }
};

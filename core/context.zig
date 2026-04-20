const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("types.zig");
const vault = @import("vault.zig");
const solana = @import("solana.zig");
const evm = @import("evm.zig");

pub const AgentContext = struct {
    allocator: std.mem.Allocator,
    vaults: vault.VaultSet,
    sol_client: solana.SolanaClient,
    evm_client: evm.EvmClient,
    config_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) !AgentContext {
        // En una app real, aquí cargaríamos el agent.toml
        return AgentContext{
            .allocator = allocator,
            .vaults = try vault.VaultSet.init(allocator),
            .sol_client = solana.SolanaClient.init(allocator, "https://api.devnet.solana.com"),
            .evm_client = evm.EvmClient.init(allocator, "https://sepolia.base.org"), // Por defecto a Base Sepolia
            .config_dir = try allocator.dupe(u8, config_dir),
        };
    }

    pub fn deinit(self: *AgentContext) void {
        self.vaults.deinit();
        self.sol_client.deinit();
        self.evm_client.deinit();
        self.allocator.free(self.config_dir);
    }
};

const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("types.zig");
const vault = @import("vault.zig");
const solana = @import("solana.zig");
const evm = @import("evm.zig");
const config_mod = @import("config.zig");

pub const AgentContext = struct {
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    vaults: vault.VaultSet,
    sol_client: solana.SolanaClient,
    evm_client: evm.EvmClient,

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !AgentContext {
        const config = try config_mod.Config.load(allocator, config_path);
        
        return AgentContext{
            .allocator = allocator,
            .config = config,
            .vaults = try vault.VaultSet.init(allocator),
            .sol_client = solana.SolanaClient.init(allocator, config.rpc.solana),
            .evm_client = evm.EvmClient.init(allocator, config.rpc.base),
        };
    }

    pub fn deinit(self: *AgentContext) void {
        self.vaults.deinit();
        self.sol_client.deinit();
        self.evm_client.deinit();
        self.config.deinit(self.allocator);
    }
};

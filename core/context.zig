const std = @import("std");
const crypto = @import("crypto.zig");
const types = @import("types.zig");
const vault = @import("vault.zig");
const solana = @import("solana.zig");
const evm = @import("evm.zig");
const config_mod = @import("config.zig");
const const_mod = @import("constitution.zig");
const cdp = @import("cdp.zig");
const compliance = @import("compliance.zig");
const store = @import("store.zig");

pub const AgentContext = struct {
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    vaults: vault.VaultSet,
    sol_client: solana.SolanaClient,
    evm_client: evm.EvmClient,
    cdp_client: ?cdp.CdpClient,
    constitution: const_mod.Constitution,
    compliance: compliance.ComplianceEngine,
    store: store.Store,

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !AgentContext {
        const config = try config_mod.Config.load(allocator, config_path);

        var cdp_client: ?cdp.CdpClient = null;
        if (config.cdp.key_name != null and config.cdp.key_secret != null) {
            cdp_client = cdp.CdpClient.init(allocator, config.cdp.key_name.?, config.cdp.key_secret.?);
        }

        return AgentContext{
            .allocator = allocator,
            .config = config,
            .vaults = try vault.VaultSet.init(allocator, config.vaults.path),
            .sol_client = solana.SolanaClient.init(allocator, config.rpc.solana),
            .evm_client = evm.EvmClient.init(allocator, config.rpc.base),
            .cdp_client = cdp_client,
            .constitution = const_mod.Constitution.init(allocator),
            .compliance = compliance.ComplianceEngine.init(allocator, [_]u8{0} ** 32),
            .store = try store.Store.init(allocator, config.vaults.path),
        };
    }


    pub fn deinit(self: *AgentContext) void {
        self.store.deinit();
        self.constitution.deinit();
        self.vaults.deinit();
        self.sol_client.deinit();
        self.evm_client.deinit();
        self.config.deinit(self.allocator);
    }
};

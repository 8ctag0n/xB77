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
const pay = @import("pay.zig");

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
    router: pay.PaymentRouter,

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !AgentContext {
        const config = try config_mod.Config.load(allocator, config_path);

        var cdp_client: ?cdp.CdpClient = null;
        if (config.cdp.key_name != null and config.cdp.key_secret != null) {
            cdp_client = cdp.CdpClient.init(allocator, config.cdp.key_name.?, config.cdp.key_secret.?);
        }

        var ctx = AgentContext{
            .allocator = allocator,
            .config = config,
            .vaults = try vault.VaultSet.init(allocator, config.vaults.path),
            .sol_client = solana.SolanaClient.init(allocator, config.rpc.solana),
            .evm_client = evm.EvmClient.init(allocator, config.rpc.base),
            .cdp_client = cdp_client,
            .constitution = const_mod.Constitution.init(allocator),
            .compliance = compliance.ComplianceEngine.init(allocator, [_]u8{0} ** 32),
            .store = try store.Store.init(allocator, config.vaults.path),
            .router = undefined, 
        };

        // El router se inicializa con los punteros de 'ctx'. 
        // En Zig, si devolvemos 'ctx' por valor, debemos tener cuidado.
        // Pero como el router es parte de la misma estructura, sus punteros internos
        // a sol_client, evm_client, etc, se mantendrán válidos si apuntan a campos de 'ctx'
        // y el llamador mantiene a 'ctx' en una posición estable.
        
        ctx.router = pay.PaymentRouter.init(
            allocator,
            &ctx.sol_client,
            &ctx.evm_client,
            &ctx.vaults,
            &ctx.constitution,
            null,
        );

        return ctx;
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

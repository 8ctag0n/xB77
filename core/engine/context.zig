const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const vault = @import("../state/vault.zig");
const solana = @import("../chain/solana.zig");
const evm = @import("../chain/evm.zig");
const config_mod = @import("../engine/config.zig");
const const_mod = @import("../business/constitution.zig");
const cdp = @import("../business/cdp.zig");
const compliance = @import("../business/compliance.zig");
const store = @import("../state/store.zig");
const pay = @import("../business/pay.zig");
const mesh = @import("../net/mesh.zig");
const swap = @import("../business/swap.zig");

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
    mesh_manager: mesh.MeshManager,
    swap_manager: swap.SwapManager,
    ipfs_client: @import("../net/ipfs.zig").IpfsClient,
    active_agents: std.StringHashMapUnmanaged(*std.process.Child),

    pub fn spawnAgent(self: *AgentContext, name: []const u8) !void {
        const allocator = self.allocator;
        
        // 1. Crear perfil para el nuevo agente
        try std.fs.cwd().makePath("profiles");
        var config_buf: [256]u8 = undefined;
        const config_path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{name});
        
        {
            const file = try std.fs.cwd().createFile(config_path, .{});
            defer file.close();
            
            const content = try std.fmt.allocPrint(allocator, 
                \\# xB77 Sovereign Agent Configuration
                \\[vaults]
                \\path = ".xb77/{s}"
                \\
                \\[rpc]
                \\solana = "{s}"
                \\base = "{s}"
                \\
            , .{ name, self.config.rpc.solana, self.config.rpc.base });
            defer allocator.free(content);
            try file.writeAll(content);
        }

        // 2. Lanzar el proceso
        var child = try allocator.create(std.process.Child);
        child.* = std.process.Child.init(&[_][]const u8{ 
            "./zig-out/bin/xb77", 
            "-p", name,
            "serve" 
        }, allocator);
        
        try child.spawn();
        
        const name_dupe = try allocator.dupe(u8, name);
        try self.active_agents.put(allocator, name_dupe, child);
        
        std.debug.print("\n[SPAWN ] 🚀 Agent '{s}' deployed. PID: {d}", .{ name, child.id });
    }

    pub fn killAgent(self: *AgentContext, name: []const u8) !void {
        const kv = self.active_agents.fetchRemove(name) orelse return error.AgentNotFound;
        defer self.allocator.free(kv.key);
        defer self.allocator.destroy(kv.value);

        _ = try kv.value.kill();
        std.debug.print("\n[KILL  ] 💀 Agent '{s}' terminated.", .{name});
    }

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !AgentContext {
        const config = try config_mod.Config.load(allocator, config_path);

        var cdp_client: ?cdp.CdpClient = null;
        if (config.cdp.key_name != null and config.cdp.key_secret != null) {
            cdp_client = cdp.CdpClient.init(allocator, config.cdp.key_name.?, config.cdp.key_secret.?);
        }

        var vaults = try vault.VaultSet.init(allocator, config.vaults.path);
        const sol_addr = try vaults.ops.address(.solana, allocator);
        defer allocator.free(sol_addr);
        
        var agent_id: [32]u8 = [_]u8{0} ** 32;
        @memcpy(agent_id[0..@min(sol_addr.len, 32)], sol_addr[0..@min(sol_addr.len, 32)]);

        const s = try store.Store.init(allocator, config.vaults.path);

        var ctx = AgentContext{
            .allocator = allocator,
            .config = config,
            .vaults = vaults,
            .sol_client = solana.SolanaClient.init(allocator, config.rpc.solana),
            .evm_client = evm.EvmClient.init(allocator, config.rpc.base),
            .cdp_client = cdp_client,
            .constitution = const_mod.Constitution.init(allocator),
            .compliance = compliance.ComplianceEngine.init(allocator, [_]u8{0} ** 32),
            .store = s,
            .router = undefined, 
            .mesh_manager = try mesh.MeshManager.init(allocator, undefined, agent_id),
            .swap_manager = swap.SwapManager.init(allocator),
            .ipfs_client = @import("../net/ipfs.zig").IpfsClient.init(allocator, config.ipfs.endpoint, config.ipfs.api_key),
            .active_agents = .{},
        };
        
        ctx.mesh_manager.store = &ctx.store;

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
        var it = self.active_agents.iterator();
        while (it.next()) |kv| {
            _ = kv.value_ptr.*.kill() catch {};
            self.allocator.free(kv.key_ptr.*);
            self.allocator.destroy(kv.value_ptr.*);
        }
        self.active_agents.deinit(self.allocator);

        self.swap_manager.deinit();
        self.mesh_manager.deinit();
        self.store.deinit();
        self.constitution.deinit();
        self.vaults.deinit();
        self.sol_client.deinit();
        self.evm_client.deinit();
        self.config.deinit(self.allocator);
    }
};

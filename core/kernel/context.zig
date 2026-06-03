const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const vault = @import("../security/vault.zig");
const solana = @import("../chain/solana.zig");
const evm = @import("../chain/evm.zig");
const config_mod = @import("../kernel/config.zig");
const const_mod = @import("../security/constitution.zig");
const compliance = @import("../security/shield.zig");
const store = @import("../protocol/store.zig");
const pay = @import("../commerce/pay.zig");
const mesh = @import("../mesh/mesh.zig");
const swap = @import("../commerce/swap.zig");
const mb = @import("../chain/magicblock.zig");
const orchestrator = @import("orchestrator.zig");
const telemetry = @import("telemetry.zig");
const registry_mod = @import("../commerce/registry.zig");
const app_mod = @import("../kernel/app.zig");

pub const PendingAuth = struct {
    id: [32]u8,
    amount: u64,
    recipient: []const u8,
    chain: types.Chain,
    description: []const u8,
    ts: i64,
};

pub const AgentContext = struct {
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    vaults: vault.VaultSet,
    sol_client: solana.SolanaClient,
    evm_client: evm.EvmClient,
    mb_client: mb.MagicBlockSDK,
    constitution: const_mod.Constitution,
    compliance: compliance.ComplianceEngine,
    store: store.Store,
    router: pay.PaymentRouter,
    mesh_manager: mesh.MeshManager,
    swap_manager: swap.SwapManager,
    registry_manager: registry_mod.RegistryManager,
    app_manager: app_mod.AppManager,
    merchant: @import("../commerce/merchant.zig").MerchantConfig,
    ipfs_client: @import("../mesh/ipfs.zig").IpfsClient,
    brain: @import("../intelligence/brain.zig").Brain,
    active_agents: std.StringHashMapUnmanaged(*std.process.Child),
    pending_authorizations: std.ArrayListUnmanaged(PendingAuth),

    // --- Infrastructure Layer ---
    orchestrator: orchestrator.Orchestrator,
    telemetry: telemetry.TelemetryHub,

    pub fn spawnAgent(self: *AgentContext, name: []const u8) !void {
        const allocator = self.allocator;

        // --- Security: Sanitize name to prevent path traversal ---
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
                return error.InvalidAgentName;
            }
        }

        try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), "profiles");
        var config_buf: [256]u8 = undefined;
        const config_path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{name});
        
        {
            const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), config_path, .{});
            defer file.close(std.Io.Threaded.global_single_threaded.io());
            const content = try std.fmt.allocPrint(allocator, 
                \\# xB77 Sovereign Agent Configuration
                \\[vaults]
                \\path = ".xb77/{s}"
                \\[rpc]
                \\solana = "{s}"
                \\base = "{s}"
            , .{ name, self.config.rpc.solana, self.config.rpc.base });
            defer allocator.free(content);
            try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), content);
        }

        var child = try allocator.create(std.process.Child);
        child.* = std.process.Child.init(&[_][]const u8{ "./zig-out/bin/xb77", "-p", name, "serve" }, allocator);
        try child.spawn();
        const name_dupe = try allocator.dupe(u8, name);
        try self.active_agents.put(allocator, name_dupe, child);
    }

    pub fn onPendingAuth(ptr: *anyopaque, request: pay.PaymentRequest, desc: []const u8) anyerror!void {
        const self: *AgentContext = @ptrCast(@alignCast(ptr));
        
        var id: [32]u8 = undefined;
        const ts = std.time.milliTimestamp();
        var ts_buf: [8]u8 = undefined;
        std.mem.writeInt(i64, &ts_buf, ts, .little);
        std.crypto.hash.sha2.Sha256.hash(&ts_buf, &id, .{});

        const recipient_str = switch (request.recipient) {
            .sol => |pk| try crypto.pubkeyToString(self.allocator, &pk),
            .evm => |addr| try evm.addressToHex(self.allocator, addr),
        };

        try self.pending_authorizations.append(self.allocator, .{
            .id = id,
            .amount = request.amount,
            .recipient = recipient_str,
            .chain = request.asset.chain,
            .description = try self.allocator.dupe(u8, desc),
            .ts = ts,
        });

        std.debug.print("\n[GUARD ]  High-value transaction QUEUED for Human Approval. ID: {x}...", .{id[0..4].*});
    }

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8, password: ?[]const u8) !AgentContext {
        var config = try config_mod.Config.load(allocator, config_path);
        errdefer config.deinit(allocator);

        var vaults = try vault.VaultSet.init(allocator, config.vaults.path, password);
        errdefer vaults.deinit();
        const sol_addr = try vaults.ops.address(.solana, allocator);
        defer allocator.free(sol_addr);
        
        var agent_id: [32]u8 = [_]u8{0} ** 32;
        // Proper pubkey parsing if possible, otherwise fallback to bytes
        if (crypto.stringToPubkey(allocator, sol_addr)) |pk| {
            @memcpy(&agent_id, &pk);
        } else |_| {
            @memcpy(agent_id[0..@min(sol_addr.len, 32)], sol_addr[0..@min(sol_addr.len, 32)]);
        }

        const s = try store.Store.init(allocator, config.vaults.path);
        const merchant_path = try std.fs.path.join(allocator, &[_][]const u8{ config.vaults.path, "merchant.json" });
        defer allocator.free(merchant_path);
        const m_config = @import("../commerce/merchant.zig").MerchantConfig.load(allocator, merchant_path) catch |err| blk: {
            std.debug.print("\n[CONTEXT]  Warning loading merchant.json: {s}. Using default.", .{@errorName(err)});
            break :blk @import("../commerce/merchant.zig").MerchantConfig{
                .business_name = "xB77 Sovereign Agent",
                .contact = "@agent",
                .services = &.{},
            };
        };

        var registry_id: [32]u8 = [_]u8{0} ** 32;
        if (config.registry_program_id) |rid| {
            if (crypto.stringToPubkey(allocator, rid)) |pk| {
                @memcpy(&registry_id, &pk);
            } else |_| {
                @memcpy(registry_id[0..@min(rid.len, 32)], rid[0..@min(rid.len, 32)]);
            }
        }

        var ctx = AgentContext{
            .allocator = allocator,
            .config = config,
            .vaults = vaults,
            .sol_client = solana.SolanaClient.init(allocator, config.rpc.solana),
            .evm_client = evm.EvmClient.init(allocator, config.rpc.base),
            .mb_client = mb.MagicBlockSDK.init(allocator, "https://devnet.magicblock.app"),
            .constitution = const_mod.Constitution.init(allocator),
            .compliance = compliance.ComplianceEngine.init(allocator),
            .store = s,
            .router = undefined, 
            .mesh_manager = try mesh.MeshManager.init(allocator, undefined, agent_id),
            .swap_manager = swap.SwapManager.init(allocator),
            .registry_manager = registry_mod.RegistryManager.init(allocator, undefined, registry_id),
            .app_manager = app_mod.AppManager.init(allocator, null),
            .merchant = m_config,
            .ipfs_client = @import("../mesh/ipfs.zig").IpfsClient.init(allocator, config.ipfs.endpoint, config.ipfs.api_key),
            .brain = undefined,
            .active_agents = .{},
            .pending_authorizations = .{},
            .orchestrator = orchestrator.Orchestrator.init(allocator),
            .telemetry = telemetry.TelemetryHub.init(allocator),
        };
        
        ctx.sol_client.http_client.telemetry = &ctx.telemetry;
        ctx.evm_client.http_client.telemetry = &ctx.telemetry;
        ctx.ipfs_client.http_client.telemetry = &ctx.telemetry;
        
        ctx.mb_client.sol_client = &ctx.sol_client;

        ctx.brain = @import("../intelligence/brain.zig").Brain.init(allocator, &ctx.constitution);
        ctx.mesh_manager.store = &ctx.store;
        ctx.registry_manager.sol_client = &ctx.sol_client;
        
        // Link Shield with Context references
        ctx.compliance.sol_client = &ctx.sol_client;
        ctx.compliance.constitution = &ctx.constitution;

        // Optional: opt into Hard SNS Enforcement via env var. Keeps the
        // sovereign-identity gate visible in demos and audits without forcing
        // it on every profile.
        if (std.process.getEnvVarOwned(allocator, "XB77_SNS_NAMESPACE")) |ns| {
            ctx.constitution.required_sns_namespace = ns;
            std.debug.print("\n[Shield]  Hard SNS Enforcement: namespace '{s}' is now mandatory for non-trivial transfers.\n", .{ns});
        } else |_| {}

        ctx.router = pay.PaymentRouter.init(
            allocator,
            &ctx.sol_client,
            &ctx.evm_client,
            &ctx.mb_client,
            &ctx.vaults,
            &ctx.store,
            &ctx.constitution,
            config.facilitator,
        );

        ctx.router.pending_auth_ptr = &ctx;
        ctx.router.pending_auth_fn = onPendingAuth;

        ctx.router.mb_session = ctx.mb_client.openSovereignSession(&ctx.vaults.ops.sol_kp) catch |err| blk: {
            std.debug.print("\n[MAGIC ]  {s}[WARN]{s} Sovereign Session initialization failed: {s}. Operating on Standard Rails.", .{ "\x1b[33;1m", "\x1b[0m", @errorName(err) });
            break :blk null;
        };

        ctx.app_manager.router = ctx.router.asAppRouter();
        ctx.ipfs_client.http_client.payment_provider = ctx.getPaymentProvider();

        return ctx;
    }

    pub fn saveMerchantConfig(self: *AgentContext) !void {
        const merchant_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.config.vaults.path, "merchant.json" });
        defer self.allocator.free(merchant_path);
        try self.merchant.save(merchant_path);
    }

    pub fn payToll(ptr: *anyopaque, amount: u64, memo: []const u8) anyerror![]const u8 {
        const self: *AgentContext = @ptrCast(@alignCast(ptr));
        if (self.constitution.validateToll(amount, memo)) {
            self.telemetry.recordRpc(); 
            return "0x402_wdk_tether_toll_settlement_hash";
        } else {
            return error.UnauthorizedToll;
        }
    }

    pub fn getPaymentProvider(self: *AgentContext) @import("../mesh/http.zig").PaymentProvider {
        return .{ .ptr = self, .payFn = payToll };
    }

    pub fn deinit(self: *AgentContext) void {
        var it = self.active_agents.iterator();
        while (it.next()) |kv| {
            _ = kv.value_ptr.*.kill() catch {};
            self.allocator.free(kv.key_ptr.*);
            self.allocator.destroy(kv.value_ptr.*);
        }
        self.active_agents.deinit(self.allocator);
        for (self.pending_authorizations.items) |p| {
            self.allocator.free(p.recipient);
            self.allocator.free(p.description);
        }
        self.pending_authorizations.deinit(self.allocator);
        _ = self.telemetry.endSession();
        self.merchant.deinit(self.allocator);
        self.mb_client.deinit();
        self.app_manager.deinit();
        self.orchestrator.deinit();
        self.brain.deinit();
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

fn isQuietMode(allocator: std.mem.Allocator) bool {
    if (std.process.getEnvVarOwned(allocator, "XB77_DEMO")) |val| {
        allocator.free(val);
        return true;
    } else |_| return false;
}

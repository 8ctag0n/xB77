const std = @import("std");
const core = @import("../core.zig");
const builtin = @import("builtin");

const bridge = if (builtin.target.os.tag != .wasi) @import("../mesh/znode_bridge.zig") else struct {
    pub fn startBridge(_: anytype) !void {}
};

const yellowstone = @import("../mesh/yellowstone.zig");
const awpool = @import("../protocol/awpool.zig");
const anchor = @import("../chain/anchor.zig");
const mesh = @import("../mesh/mesh.zig");
const strategist = @import("../kernel/strategist.zig");
const prover_mod = @import("../kernel/prover.zig");
const http_bridge = @import("../kernel/http_bridge.zig");
const magicblock = @import("../chain/magicblock.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    ctx: *core.kernel.context.AgentContext,
    is_running: bool,
    awpool: awpool.AWPool,
    anchor_service: anchor.AnchorService,
    prover: prover_mod.SovereignProver,
    http_telemetry: http_bridge.HttpBridge,
    strategist: strategist.Strategist,
    mb_client: magicblock.MagicBlockSDK,
    mb_session: ?magicblock.MagicBlockSDK.Session = null,

    pub fn init(allocator: std.mem.Allocator, ctx: *core.kernel.context.AgentContext) Engine {
        var pool = awpool.AWPool.init(allocator);
        pool.router = &ctx.router;
        pool.store = &ctx.store;
        
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .is_running = false,
            .awpool = pool,
            .anchor_service = anchor.AnchorService.init(allocator, &ctx.store),
            .prover = prover_mod.SovereignProver.init(allocator, &ctx.store, &ctx.sol_client),
            .http_telemetry = http_bridge.HttpBridge.init(allocator, ctx),
            .strategist = strategist.Strategist.init(allocator, &ctx.store),
            .mb_client = magicblock.MagicBlockSDK.init(allocator, "https://devnet.magicblock.app"),
            .mb_session = null,
        };
    }

    var tick_count: u64 = 0;

    pub fn start(self: *Engine) !void {
        self.is_running = true;
        self.ctx.telemetry.startSession();
        
        const sol_kp = &self.ctx.vaults.ops.sol_kp;
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);

        if (!self.ctx.orchestrator.canOperate(sol_kp.public)) {
            std.debug.print("\n[ORCH  ]  Insufficient Credits to start agent. Please fund via /blink.", .{});
            return error.InsufficientCredits;
        }
        
        const eth_addr = try self.ctx.vaults.ops.address(.base, self.allocator);
        defer self.allocator.free(eth_addr);

        std.debug.print("\n[Kernel] xB77 Sovereign OS - Kernel Starting v0.1.0\n", .{});
        std.debug.print("         ----------------------------------------\n", .{});
        std.debug.print("         ID Solana: {s}\n", .{sol_addr});
        std.debug.print("         ID EVM:    {s}\n", .{eth_addr});
        std.debug.print("         ----------------------------------------\n", .{});

        // Discovery thread
        const discovery_thread = try std.Thread.spawn(.{}, struct {
            fn run(m: *mesh.MeshManager) void {
                m.listenForPeers() catch |err| {
                    std.debug.print("[Kernel]  Discovery Listener Error: {}\n", .{err});
                };
            }
        }.run, .{&self.ctx.mesh_manager});
        discovery_thread.detach();

        // HTTP Telemetry Bridge thread
        const http_thread = try std.Thread.spawn(.{}, struct {
            fn run(h_bridge: *http_bridge.HttpBridge) void {
                h_bridge.start() catch |err| {
                    std.debug.print("[Kernel]  HTTP Bridge Error: {}\n", .{err});
                };
            }
        }.run, .{&self.http_telemetry});
        http_thread.detach();

        // Local Bridge
        if (comptime builtin.target.os.tag != .wasi) {
            try bridge.startBridge(self);
        }

        while (self.is_running) {
            std.debug.print("\n[Kernel] --- TICK START ({d}) ---", .{tick_count});
            try self.ctx.mesh_manager.broadcastPresence(self.ctx.config.mesh_port);

            if (tick_count == 0 or tick_count % 6 == 0) {
                try self.runStrategist();
            }

            try self.tick();
            
            if (tick_count > 0 and tick_count % 3 == 0) {
                const report = self.ctx.telemetry.endSession();
                const balance = try self.ctx.orchestrator.processUsage(sol_kp.public, report);
                std.debug.print("\n[ORCH  ]  Usage Processed. Credits: {d} SC", .{ balance });
                self.ctx.telemetry.startSession();
            }

            tick_count += 1;
            std.debug.print("\n[Kernel] --- TICK END ---", .{});
            std.Io.sleep(std.Io.Threaded.global_single_threaded.io(), .{ .nanoseconds = @intCast(10 * std.time.ns_per_s) }, .awake) catch {};
        }
    }

    fn runStrategist(self: *Engine) !void {
        const sol_kp = &self.ctx.vaults.ops.sol_kp;
        const balance = self.ctx.orchestrator.balances.get(sol_kp.public) orelse 0;
        const analysis = try self.strategist.analyze(self.ctx.active_agents.count(), balance);
        
        switch (analysis.decision) {
            .austerity_mode => {
                std.debug.print("\n[STRAT ]  AUSTERITY MODE: Requesting flash loan protocol...", .{});
                self.ctx.mesh_manager.broadcastLoanRequest(50000000, 500, 60) catch {};
            },
            .compress_state => {
                std.debug.print("\n[STRAT ]  HIGH VOLUME: Triggering Sovereign Anchor (L1).", .{});
                const ops_kp = &self.ctx.vaults.ops.sol_kp;
                try self.prover.checkAndAnchor(ops_kp);
            },
            .expand => {
                var name_buf: [32]u8 = undefined;
                const name = try std.fmt.bufPrint(&name_buf, "worker-{d}", .{@mod(std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds(), 1000)});
                try self.ctx.spawnAgent(name);
            },
            else => {},
        }
    }

    pub fn processIntent(self: *Engine, intent: []const u8) !void {
        // Negotiation and Directive logic delegated to Brain
        const insight = try self.ctx.brain.interpret(intent);
        std.debug.print("\n[Kernel]  Directive Interpreted: {d} lamports", .{insight.directive.max_budget});
    }

    fn tick(self: *Engine) !void {
        const ops_kp = &self.ctx.vaults.ops.sol_kp;
        self.prover.checkAndAnchor(ops_kp) catch {};
        self.prover.checkAndProveReceipts() catch {};
        self.ctx.mesh_manager.tick() catch {};
    }

    pub fn onNetworkEvent(self: *Engine, event: yellowstone.NetworkEvent) void {
        switch (event.type) {
            .transaction => {
                const tx = event.tx orelse return;

                if (tx.amount > 5_000_000_000) {
                    std.debug.print("\n[HFT   ]  Whale transaction detected!", .{});
                    const ops_kp = &self.ctx.vaults.ops.sol_kp;
                    self.prover.checkAndAnchor(ops_kp) catch {};
                }

                // Compliance & Shield
                if (!self.ctx.compliance.check(tx)) {
                    std.debug.print("\n[SHIELD]  Transaction Rejected: Compliance Violation.", .{});
                    return;
                }

                std.debug.print("\n[PULSE ]  Verdict: Sovereign Transaction Accepted.", .{});
                
                const sig_hex = core.security.crypto.bytesToHex(self.allocator, &tx.signature) catch tx.signature[0..8];
                defer if (sig_hex.len > 8) self.allocator.free(sig_hex);

                self.ctx.store.record(.{
                    .timestamp = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds(),
                    .chain = event.chain,
                    .entry_type = .audit,
                    .description = "Sovereign Transaction Accepted",
                    .amount = tx.amount,
                    .tx_hash = sig_hex,
                }) catch {};

                // Generate ZK-Receipt
                const tax_amount = (tx.amount * 211) / 10000;
                if (core.commerce.receipt.ZkReceipt.generate(tx.amount, tax_amount, .{ .sol = tx.recipient })) |r| {
                    var path_buf: [256]u8 = undefined;
                    const prover_path = std.fmt.bufPrint(&path_buf, "{s}/zk_prover_{s}.toml", .{ self.ctx.config.vaults.path, sig_hex[0..8] }) catch "Prover.toml";
                    r.writeProverToml(prover_path) catch {};
                }
            },
            else => {},
        }
    }

    pub fn stop(self: *Engine) void {
        self.is_running = false;
    }
};

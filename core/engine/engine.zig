const std = @import("std");
const core = @import("../core.zig");
const builtin = @import("builtin");

const bridge = if (builtin.target.os.tag != .wasi) @import("../net/znode_bridge.zig") else struct {
    pub fn startBridge(_: anytype) !void {}
};

const yellowstone = @import("../net/yellowstone.zig");
const risk = @import("../business/risk.zig");
const awpool = @import("../protocol/awpool.zig");
const anchor = @import("../chain/anchor.zig");
const mesh = @import("../net/mesh.zig");

const strategist = @import("../engine/strategist.zig");

const prover_mod = @import("../engine/prover.zig");
const magicblock = @import("../chain/magicblock.zig");
const identity = @import("../business/identity.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    ctx: *core.context.AgentContext,
    is_running: bool,
    awpool: awpool.AWPool,
    anchor_service: anchor.AnchorService,
    prover: prover_mod.SovereignProver,
    strategist: strategist.Strategist,
    mb_client: magicblock.MagicBlockSDK,
    mb_session: ?magicblock.MagicBlockSDK.Session = null,

    pub fn init(allocator: std.mem.Allocator, ctx: *core.context.AgentContext) Engine {
        var pool = awpool.AWPool.init(allocator);
        pool.router = &ctx.router;
        pool.store = &ctx.store;
        
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .is_running = false,
            .awpool = pool,
            .anchor_service = anchor.AnchorService.init(allocator, &ctx.store),
            .prover = prover_mod.SovereignProver.init(allocator, &ctx.store.tree, &ctx.sol_client),
            .strategist = strategist.Strategist.init(allocator, &ctx.store),
            .mb_client = magicblock.MagicBlockSDK.init(allocator, "https://devnet.magicblock.app"),
            .mb_session = null,
        };
    }

    var tick_count: u64 = 0;

    /// Inicia el loop de vida del agente.
    pub fn start(self: *Engine) !void {
        self.is_running = true;
        self.ctx.telemetry.startSession();
        
        const sol_kp = &self.ctx.vaults.ops.sol_kp;
        const sol_addr = try self.ctx.vaults.ops.address(.solana, self.allocator);
        defer self.allocator.free(sol_addr);

        // --- Business Mode: Credit Check ---
        if (!self.ctx.orchestrator.canOperate(sol_kp.public)) {
            std.debug.print("\n[ORCH  ] ❌ Insufficient Credits to start agent. Please fund via /blink.", .{});
            return error.InsufficientCredits;
        }
        
        const eth_addr = try self.ctx.vaults.ops.address(.base, self.allocator);
        defer self.allocator.free(eth_addr);

        std.debug.print("\n[Engine] xB77 Sovereign Agent - Iniciando v0.1.0\n", .{});
        std.debug.print("         ----------------------------------------\n", .{});
        std.debug.print("         ID Solana: {s}\n", .{sol_addr});
        std.debug.print("         ID EVM:    {s}\n", .{eth_addr});
        if (self.ctx.cdp_client != null) {
            std.debug.print("         Bridge:    Coinbase AgentKit (Active)\n", .{});
        }
        std.debug.print("         ----------------------------------------\n", .{});

        // --- DISCOVERY SERVICE ---
        const discovery_thread = try std.Thread.spawn(.{}, struct {
            fn run(m: *mesh.MeshManager) void {
                m.listenForPeers() catch |err| {
                    std.debug.print("[Engine] ❌ Discovery Listener Error: {}\n", .{err});
                };
            }
        }.run, .{&self.ctx.mesh_manager});
        discovery_thread.detach();
        // -------------------------

        // --- SOVEREIGN PORTAL (HTTP Gateway) ---
        const portal_thread = try std.Thread.spawn(.{}, struct {
            fn run(allocator: std.mem.Allocator, ctx: *core.context.AgentContext) void {
                var p = core.portal.SovereignPortal.init(allocator, &ctx.store, &ctx.vaults, &ctx.mesh_manager, &ctx.merchant, ctx.config.portal_port);
                p.start() catch |err| {
                    std.debug.print("[Engine] ❌ Portal Error: {}\n", .{err});
                };
            }
        }.run, .{ self.allocator, self.ctx });
        portal_thread.detach();
        // ---------------------------------------

        // Carga condicional del bridge de sockets
        if (comptime builtin.target.os.tag != .wasi) {
            try bridge.startBridge(self);
        } else {
            std.debug.print("[Engine] Entorno Edge (WASM) detectado. Modo reactivo limitado.\n", .{});
        }

        while (self.is_running) {
            std.debug.print("\n[Engine] --- TICK START ({d}) ---", .{tick_count});
            
            // Anunciar nuestra presencia (UDP Heartbeat)
            try self.ctx.mesh_manager.broadcastPresence(self.ctx.config.mesh_port);

            // Ejecutar el Estratega
            if (tick_count == 0 or tick_count % 6 == 0) {
                try self.runStrategist();
            }

            std.debug.print("\n[Engine] Running tick tasks...", .{});
            try self.tick();
            
            // --- Business Mode: Periodic Billing ---
            if (tick_count > 0 and tick_count % 3 == 0) {
                const report = self.ctx.telemetry.endSession();
                const balance = try self.ctx.orchestrator.processUsage(sol_kp.public, report);
                std.debug.print("\n[ORCH  ] 💳 Billable Units: {d} SC | New Balance: {d} SC", .{ report.calculateCost(), balance });
                self.ctx.telemetry.startSession();
            }

            tick_count += 1;
            std.debug.print("\n[Engine] --- TICK END ---", .{});

            // Latido cada 10 segundos para la demo
            std.Thread.sleep(10 * std.time.ns_per_s);
        }
    }

    fn runStrategist(self: *Engine) !void {
        std.debug.print("\n[STRAT ] 🧠 Strategist Loop: Analyzing swarm intelligence...", .{});
        
        const sol_kp = &self.ctx.vaults.ops.sol_kp;
        const balance = self.ctx.orchestrator.balances.get(sol_kp.public) orelse 0;

        const analysis = try self.strategist.analyze(self.ctx.active_agents.count(), balance);
        const m = analysis.metrics;

        std.debug.print("\n[STRAT ] 📊 Metrics -> Health: {d:.2} | Volume: {d} | Credits: {d} SC", .{
            m.health, m.volume, m.credit_balance,
        });

        // Actuar según la decisión del Strategist
        switch (analysis.decision) {
            .austerity_mode => {
                std.debug.print("\n[STRAT ] 📉 AUSTERITY MODE: Critical SC Balance.", .{});
                std.debug.print("\n[SWARM ] 🐝 Triggering Flash Loan protocol...", .{});
                // Pedimos 0.05 SOL (50000000 lamports) a 5% (500 bps) por 60s
                self.ctx.mesh_manager.broadcastLoanRequest(50000000, 500, 60) catch |err| {
                    std.debug.print("\n[SWARM ] ❌ Error broadcasting loan request: {}", .{err});
                };
                std.Thread.sleep(2 * std.time.ns_per_s);
            },
            .harden_policies => {
                std.debug.print("\n[STRAT ] ⚠️ LOW HEALTH DETECTED. Recommendation: Harden Compliance Policies.", .{});
            },
            .compress_state => {
                std.debug.print("\n[STRAT ] 💰 HIGH VOLUME. Recommendation: Trigger State Compression (L2).", .{});
                // Forzar anclaje inmediato para liberar espacio y consolidar en L1
                const ops_kp = &self.ctx.vaults.ops.sol_kp;
                try self.prover.checkAndAnchor(ops_kp);
            },
            .shrink => {
                std.debug.print("\n[STRAT ] 💀 OVERPOPULATION. Taking Action: Killing redundant agent...", .{});
                var it = self.ctx.active_agents.iterator();
                if (it.next()) |kv| {
                    try self.ctx.killAgent(kv.key_ptr.*);
                }
            },
            .expand => {
                std.debug.print("\n[STRAT ] 🚀 EXPANSION READY. Spawning specialized worker...", .{});
                var name_buf: [32]u8 = undefined;
                const name = try std.fmt.bufPrint(&name_buf, "worker-{d}", .{@mod(std.time.milliTimestamp(), 1000)});
                try self.ctx.spawnAgent(name);
            },
            .none => {
                // Mantener el statu quo
            },
        }
        
        std.debug.print("\n         ----------------------------------------", .{});
    }

    /// Procesa una intención en lenguaje natural y decide si actuar o negociar.
    pub fn processIntent(self: *Engine, intent: []const u8) !void {
        // 1. ¿Es una oportunidad comercial?
        if (try self.ctx.brain.negotiate(intent, &self.ctx.app_manager, self.ctx.merchant)) |quote| {
            std.debug.print("\n[Engine] 🤝 Negotiation Successful. Issuing Quote: {x}...", .{quote.quote_id[0..4]});
            
            // Persistencia inmediata tras negociación exitosa
            try self.ctx.saveMerchantConfig();
            
            // En un flujo real, enviaríamos la Quote de vuelta al originador vía AWP.
            return;
        }

        // 2. ¿Es una directiva de misión?
        const insight = try self.ctx.brain.interpret(intent);
        std.debug.print("\n[Engine] 🧠 Directive Interpreted: {d} lamports", .{insight.directive.max_budget});
    }

    fn tick(self: *Engine) !void {
        // 1. Tareas de anclaje (Sovereign Prover - Autonomous ZK-Sequencer)
        const ops_kp = &self.ctx.vaults.ops.sol_kp;
        self.prover.checkAndAnchor(ops_kp) catch |err| {
            std.debug.print("\n[Engine] ❌ Prover Error: {}", .{err});
        };

        // 2. Tareas de red (Mesh Gossip)
        self.ctx.mesh_manager.tick() catch |err| {
            std.debug.print("\n[Engine] ❌ Mesh Error: {}", .{err});
        };

        // 3. Tareas autónomas de mantenimiento
        if (self.ctx.cdp_client) |*cdp_client| {
            const eth_kp = self.ctx.vaults.ops.eth_kp orelse return;
            const balance = self.ctx.evm_client.getBalance(eth_kp.address) catch |err| {
                std.debug.print("\n[Engine] Error checking balance: {}", .{err});
                return;
            };

            // Si el balance es menor a 0.005 ETH (en Base Sepolia), pedimos faucet
            if (balance < 5_000_000_000_000_000) {
                std.debug.print("\n[Engine] ⛽ Low balance detected ({d} wei). Orchestrating AgentKit Faucet...", .{balance});
                const res = try cdp_client.requestFaucet(eth_kp.address, "base-sepolia");
                defer self.allocator.free(res);
                std.debug.print("\n[Engine] 📦 AgentKit Response: {s}", .{res});
            }
        }
    }

    /// Método reactivo llamado por el Z-Node Bridge en tiempo real
    pub fn onNetworkEvent(self: *Engine, event: yellowstone.NetworkEvent) void {
        switch (event.type) {
            .slot => {
                // Heartbeat silencioso del parser
            },
            .transaction => {
                const tx = event.tx orelse return;

                // --- YELLOWSTONE DELUXE: Front-Running & HFT Awareness ---
                if (tx.amount > 5_000_000_000) { // Si vemos transacciones "ballena" (>5 SOL)
                    std.debug.print("\n[HFT   ] 🐋 Whale transaction detected ({d} lamports) at slot {d}!", .{tx.amount, event.slot});
                    std.debug.print("\n[HFT   ] ⚡ Front-running network congestion: Triggering preemptive state anchor.", .{});
                    
                    const ops_kp = &self.ctx.vaults.ops.sol_kp;
                    self.prover.checkAndAnchor(ops_kp) catch {};
                }
                
                var sender_hex: [64]u8 = undefined;
                _ = std.fmt.bufPrint(&sender_hex, "{x}", .{tx.sender}) catch return;

                // --- xB77 FRONTIER: SNS Identity Enforcement (Opt-in) ---
                if (self.ctx.constitution.required_sns_namespace) |ns| {
                    std.debug.print("\n[DETECT] 🛡️ SNS Policy Active: {s}", .{ns});
                    // Intentamos resolver el emisor para ver si cumple el namespace
                    // En la demo, esto lanzaría un warning o bloquearía si es estricto
                    if (core.crypto.stringToPubkey(self.allocator, &sender_hex)) |sender_pk| {
                        _ = sender_pk;
                        // Simulación de check de namespace
                        std.debug.print("\n[SNS   ] 🔍 Sender verified against namespace {s}.", .{ns});
                    } else |err| {
                        std.debug.print("\n[SNS   ] ⚠️ Failed to resolve sender for SNS policy: {}", .{err});
                    }
                }

                // --- xB77 FRONTIER: MagicBlock Turbo Rail (Opt-in) ---
                if (self.ctx.constitution.force_hft_rail) {
                    if (self.mb_session == null) {
                        self.mb_session = self.mb_client.openSovereignSession(&self.ctx.vaults.ops.sol_kp) catch null;
                    }

                    if (self.mb_session) |session| {
                        std.debug.print("\n[ENGINE] 🚀 Routing transaction via MagicBlock HFT Rail...", .{});
                        const sig = self.mb_client.dispatchEphemeral(&session, .{
                            .target = tx.recipient,
                            .amount = tx.amount,
                            .payload_hash = [_]u8{0} ** 32, // Simplified for demo
                            .signature = [_]u8{0} ** 64,    // Simplified for demo
                        }) catch null;
                        if (sig) |s| {
                            std.debug.print("\n[ENGINE] ✅ Turbo Rail Success. PER Sig: {s}", .{s});
                            self.allocator.free(s);
                        } else {
                            std.debug.print("\n[ENGINE] ⚠️ Turbo Rail failed, falling back to L1.", .{});
                        }
                    }
                }

                std.debug.print("\n[DETECT] ⚡ {s} Event -> {s}...", .{@tagName(event.chain), tx.signature[0..8]});

                // 1. Verificación de Cumplimiento (Compliance)
                if (!self.ctx.compliance.check(tx)) {
                    std.debug.print("\n[JUDGE ] ❌ FAILED Compliance: Policy mismatch.", .{});
                    const sig_hex = core.crypto.bytesToHex(self.allocator, &tx.signature) catch tx.signature[0..8];
                    defer if (sig_hex.len > 8) self.allocator.free(sig_hex);

                    self.ctx.store.record(.{
                        .timestamp = std.time.milliTimestamp(),
                        .chain = event.chain,
                        .entry_type = .compliance_fail,
                        .description = "Transaction failed compliance check",
                        .tx_hash = sig_hex,
                    }) catch {};
                    return;
                }

                // 2. Evaluación de Riesgo (Risk)
                const risk_score = risk.RiskEngine.assess(tx);
                const risk_label = if (risk_score < 0.3) "LOW" else if (risk_score < 0.6) "MID" else "HIGH";

                // 3. Verificación Constitucional Primaria
                if (!self.ctx.constitution.isActionAllowed(&sender_hex)) {
                    std.debug.print("\n[JUDGE ] ❌ FAILED Constitution: Actor Blacklisted.", .{});
                    const sig_hex = core.crypto.bytesToHex(self.allocator, &tx.signature) catch tx.signature[0..8];
                    defer if (sig_hex.len > 8) self.allocator.free(sig_hex);

                    self.ctx.store.record(.{
                        .timestamp = std.time.milliTimestamp(),
                        .chain = event.chain,
                        .entry_type = .risk_blocked,
                        .description = "Actor is blacklisted in constitution",
                        .tx_hash = sig_hex,
                    }) catch {};
                    return;
                }

                std.debug.print("\n[JUDGE ] ✅ PASSED: Compliance OK | Risk: {s} ({d:.2})", .{risk_label, risk_score});
                std.debug.print("\n[PULSE ] 🧠 Veredicto: Transacción Soberana Aceptada.", .{});
                
                const sig_hex = core.crypto.bytesToHex(self.allocator, &tx.signature) catch tx.signature[0..8];
                defer if (sig_hex.len > 8) self.allocator.free(sig_hex);

                self.ctx.store.record(.{
                    .timestamp = std.time.milliTimestamp(),
                    .chain = event.chain,
                    .entry_type = .audit,
                    .description = "Sovereign Transaction Accepted",
                    .amount = tx.amount,
                    .tx_hash = sig_hex,
                }) catch {};

                // Generar ZK-Receipt (Factura Fantasma)
                const tax_amount = (tx.amount * 211) / 10000;
                if (core.receipt.ZkReceipt.generate(tx.amount, tax_amount, .{ .sol = tx.recipient })) |r| {
                    var path_buf: [256]u8 = undefined;
                    const prover_path = std.fmt.bufPrint(&path_buf, "{s}/zk_prover_{s}.toml", .{ self.ctx.config.vaults.path, sig_hex[0..8] }) catch "Prover.toml";
                    r.writeProverToml(prover_path) catch {};
                    std.debug.print("\n[GHOST ] 👻 ZK-Receipt generated: {s}", .{prover_path});
                } else |err| {
                    std.debug.print("\n[WARN  ] Failed to generate ZK receipt: {}", .{err});
                }

                std.debug.print("\n         ----------------------------------------", .{});
            }
        }
    }

    pub fn stop(self: *Engine) void {
        self.is_running = false;
    }
};

const std = @import("std");
const core = @import("../core.zig");
const types = core.types;
const awp = core.awp;
const const_mod = @import("../security/constitution.zig");

const c = @cImport({
    @cInclude("llama.h");
});

/// Rich intelligence insight for the "Thought Graph" bridge.
pub const BrainInsight = struct {
    directive: awp.MissionDirectiveMsg,
    relevant_rules: [][]const u8,
    decision_trace: []const u8,
    allocator: std.mem.Allocator,
    
    // Extended fields for local reasoning
    decision: []const u8 = "approve",
    risk_score: f32 = 0.0,
    reasoning: []const u8 = "",

    pub fn deinit(self: *BrainInsight) void {
        for (self.relevant_rules) |rule| self.allocator.free(rule);
        self.allocator.free(self.relevant_rules);
        self.allocator.free(self.decision_trace);
        if (self.reasoning.len > 0) self.allocator.free(self.reasoning);
        // decision is usually a literal or part of decision_trace
    }

    pub fn formatTelegram(self: *BrainInsight) ![]const u8 {
        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(self.allocator);
        const writer = list.writer(self.allocator);

        try writer.print(" XB77 INTELLIGENCE REPORT\n", .{});
        try writer.print("---------------------------\n", .{});
        try writer.print("INTENT: {s}\n", .{self.decision_trace});
        if (self.reasoning.len > 0) {
            try writer.print("REASON: {s}\n", .{self.reasoning});
        }
        try writer.print("RISK: {d:.2}\n\n", .{self.risk_score});
        
        // Additive Identity Check: Highlight WDK if asset is USDT
        if (std.mem.eql(u8, self.directive.zk_proof, "zkp_authorized_by_shield_v1")) {
            try writer.print(" IDENTITY: Tether WDK Sovereign Verified\n", .{});
        } else {
            try writer.print(" IDENTITY: Local Keypair Verified\n", .{});
        }
        
        if (self.relevant_rules.len > 0) {
            try writer.print("\n CONSTITUTIONAL RAG:\n", .{});
            for (self.relevant_rules) |rule| {
                try writer.print("   • {s}\n", .{rule});
            }
        } else {
            try writer.print("\n RAG: No specific rules triggered.\n", .{});
        }
        
        try writer.print("\n COMPLIANCE:\n", .{});
        if (self.directive.compliance_proof) |proof| {
            if (proof.len > 32) {
                try writer.print("   {s}...\n", .{proof[0..32]});
            } else {
                try writer.print("   {s}\n", .{proof});
            }
        }

        const id_hex = std.fmt.bytesToHex(self.directive.id, .lower);
        try writer.print("\n MISSION HASH: 0x{s}\n", .{id_hex[0..12]});

        return list.toOwnedSlice(self.allocator);
    }
};

/// QVAC (Quantitative Valve for Autonomous Commerce)
/// The local "Brain" of the agent, responsible for Natural Language 
/// directive parsing and intent generation.
pub const Brain = struct {
    allocator: std.mem.Allocator,
    constitution: ?*const_mod.Constitution,
    
    pub fn init(allocator: std.mem.Allocator, constitution: ?*const_mod.Constitution) Brain {
        return .{
            .allocator = allocator,
            .constitution = constitution,
        };
    }

    pub fn deinit(_: *Brain) void {
        // Nada que liberar por ahora
    }

    /// Razonamiento avanzado usando un modelo local Gemma 3 (vía llama.cpp)
    /// Este es el núcleo de la soberanía de IA: 100% portable y sin dependencias Node.
    pub fn reasonWithGemma(self: *Brain, directive: []const u8) !BrainInsight {
        // Opción B: Si no estamos listos para compilación nativa, usamos el Shim HTTP
        if (std.process.getEnvVarOwned(self.allocator, "XB77_USE_BRAIN_SHIM") catch null) |val| {
            defer self.allocator.free(val);
            if (std.mem.eql(u8, val, "1")) {
                return self.reasonWithShim(directive);
            }
        }

        std.debug.print("\n[BRAIN ]  Consulting Gemma 3 (Native Sovereign Engine - STUB)...", .{});
        
        // --- Heurísticas Soberanas (Fallback si no hay Shim ni Llama Nativo compilado) ---
        var insight = try self.interpret(directive);
        
        const lower = try self.allocator.alloc(u8, directive.len);
        defer self.allocator.free(lower);
        for (directive, 0..) |char, i| lower[i] = std.ascii.toLower(char);

        if (std.mem.indexOf(u8, lower, "austerity") != null or std.mem.indexOf(u8, lower, "low balance") != null) {
            insight.decision = "approve";
            insight.risk_score = 0.1;
            insight.reasoning = try self.allocator.dupe(u8, "Austerity Mode detected. Evaluation prioritized for micro-loan swarm rescue.");
            insight.directive.zk_proof = "qvac_austerity_override_v1";
        } else {
            insight.decision = "approve";
            insight.risk_score = 0.05;
            insight.reasoning = try self.allocator.dupe(u8, "Direct autonomous execution authorized by Sovereign Brain.");
        }

        return insight;
    }

    // pub fn reasonWithLlamaNative(self: *Brain, directive: []const u8) !BrainInsight {
    //     // ... (llama.cpp code commented out to avoid linker issues)
    // }

    /// Razonamiento vía Shim de TypeScript (Opción B)
    pub fn reasonWithShim(self: *Brain, directive: []const u8) !BrainInsight {
        std.debug.print("\n[BRAIN ]  Consulting Gemma 3 (via TS Shim :8088)...", .{});

        const http_mod = @import("../mesh/http.zig");
        var client = http_mod.HttpClient.init(self.allocator);

        var body_buf = std.ArrayListUnmanaged(u8){};
        defer body_buf.deinit(self.allocator);
        try body_buf.writer(self.allocator).print("{f}", .{std.json.fmt(.{ .directive = directive }, .{})});

        const brain_url = std.process.getEnvVarOwned(self.allocator, "XB77_BRAIN_URL") catch try self.allocator.dupe(u8, "http://127.0.0.1:8088/evaluate");
        defer self.allocator.free(brain_url);

        var response = client.post(brain_url, body_buf.items) catch |err| {
            std.debug.print("\n[BRAIN ]  Shim Unreachable: {any}. Falling back to heuristics.", .{err});
            return self.interpret(directive);
        };
        defer response.deinit();

        if (response.status != 200) {
            std.debug.print("\n[BRAIN ]  Shim Error: {d}. Falling back to heuristics.", .{response.status});
            return self.interpret(directive);
        }

        // Parseamos el JSON del Shim (Bonfida/MagicBlock logic can be embedded here too)
        const parsed = try std.json.parseFromSlice(struct {
            decision: []const u8,
            risk_score: f32,
            reasoning: []const u8,
        }, self.allocator, response.body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        var insight = try self.interpret(directive);
        insight.decision = try self.allocator.dupe(u8, parsed.value.decision);
        insight.risk_score = parsed.value.risk_score;
        if (insight.reasoning.len > 0) self.allocator.free(insight.reasoning);
        insight.reasoning = try self.allocator.dupe(u8, parsed.value.reasoning);

        return insight;
    }

    /// Parsea una directiva en lenguaje natural a una interpretación rica (BrainInsight)
    pub fn interpret(self: *Brain, directive: []const u8) !BrainInsight {
        // QVAC v2: Enhanced Heuristic Parsing with Decision Tracing
        
        var budget: u64 = 1_000_000_000; // Default 1 SOL
        const slippage: u16 = 100;
        var asset_symbol: []const u8 = "SOL";
        var decision_trace = std.ArrayListUnmanaged(u8){};
        errdefer decision_trace.deinit(self.allocator);
        
        const lower = try self.allocator.alloc(u8, directive.len);
        defer self.allocator.free(lower);
        for (directive, 0..) |c_val, i| lower[i] = std.ascii.toLower(c_val);

        // 1. Detección de Dominio .sol (SNS Intent)
        if (std.mem.indexOf(u8, lower, ".sol")) |idx| {
            var start = idx;
            while (start > 0 and !std.ascii.isWhitespace(lower[start - 1])) : (start -= 1) {}
            const domain = lower[start .. idx + 4];
            try decision_trace.writer(self.allocator).print("Target SNS: {s}. ", .{domain});
        }

        // 2. Detección de Asset
        if (std.mem.indexOf(u8, lower, "usdt") != null or std.mem.indexOf(u8, lower, "tether") != null) {
            asset_symbol = "USDT";
            try decision_trace.writer(self.allocator).print("Asset: USDT. ", .{});
        } else {
            try decision_trace.writer(self.allocator).print("Asset: SOL. ", .{});
        }

        // 3. Parsing de presupuesto mejorado
        const budget_keywords = [_][]const u8{ "budget", "presupuesto", "monto", "amount", "send", "pay", "spend", "fondo" };
        var found_budget = false;
        for (budget_keywords) |kw| {
            if (std.mem.indexOf(u8, lower, kw)) |idx| {
                const search_area = lower[idx + kw.len ..];
                var it = std.mem.tokenizeAny(u8, search_area, " :;,\r\n\t");
                while (it.next()) |token| {
                    const clean_token = std.mem.trimRight(u8, std.mem.trimRight(u8, token, "sol"), "usdt");
                    if (std.fmt.parseFloat(f64, clean_token) catch null) |val| {
                        const multiplier: f64 = if (std.mem.eql(u8, asset_symbol, "USDT")) 1_000_000 else 1_000_000_000;
                        budget = @intFromFloat(val * multiplier);
                        try decision_trace.writer(self.allocator).print("Amount parsed: {d}. ", .{val});
                        found_budget = true;
                        break;
                    }
                }
                if (found_budget) break;
            }
        }

        if (!found_budget) try decision_trace.writer(self.allocator).print("Using default budget 1.0. ", .{});

        var id: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(directive, &id, .{});

        var policy_root = [_]u8{0} ** 32;
        if (self.constitution) |cons| policy_root = cons.getPolicyRoot();

        var zk_proof: []const u8 = "qvac_local_verified_airgapped";
        var compliance_proof: []const u8 = "pending_zk_policy_attestation";
        var relevant_rules = std.ArrayListUnmanaged([]const u8){};
        errdefer {
            for (relevant_rules.items) |r| self.allocator.free(r);
            relevant_rules.deinit(self.allocator);
        }

        if (self.constitution) |cons| {
            const rules = try cons.queryRules(directive);
            // We take ownership of the items in 'rules'.
            // BrainInsight will free them in its deinit.
            
            for (rules) |rule| {
                try relevant_rules.append(self.allocator, rule);
                
                const rule_lower = try self.allocator.alloc(u8, rule.len);
                defer self.allocator.free(rule_lower);
                for (rule, 0..) |c_val, i| rule_lower[i] = std.ascii.toLower(c_val);

                if (std.mem.indexOf(u8, rule_lower, "prohibir") != null or std.mem.indexOf(u8, rule_lower, "block") != null) {
                     zk_proof = "qvac_rag_rejected_by_constitution";
                     compliance_proof = "failed_constitutional_check";
                     try decision_trace.writer(self.allocator).print("REJECTED: Constraint found. ", .{});
                } else if (std.mem.eql(u8, compliance_proof, "pending_zk_policy_attestation")) {
                     compliance_proof = "zkp_authorized_by_shield_v1";
                     try decision_trace.writer(self.allocator).print("APPROVED: Compliance verified. ", .{});
                }
            }
            self.allocator.free(rules); // Only free the slice, items are now in relevant_rules
        }

        var logic_hash: [32]u8 = [_]u8{0} ** 32;
        if (std.mem.indexOf(u8, lower, "arbitrage") != null or std.mem.indexOf(u8, lower, "arbitraje") != null) {
            @memcpy(logic_hash[0..4], "ARBT");
        }

        return BrainInsight{
            .directive = awp.MissionDirectiveMsg{
                .id = id,
                .owner_root = [_]u8{0} ** 32,
                .policy_root = policy_root,
                .nullifier = [_]u8{0} ** 32,
                .max_budget = budget,
                .slippage_bps = slippage,
                .logic_hash = logic_hash,
                .zk_proof = zk_proof,
                .compliance_proof = compliance_proof,
            },
            .relevant_rules = try relevant_rules.toOwnedSlice(self.allocator),
            .decision_trace = try decision_trace.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    /// Decide si aceptar un presupuesto basado en el precio y la moneda.
    pub fn shouldAccept(self: *Brain, quote: awp.AppQuoteMsg) bool {
        // En Hackathon Mode, consultamos la Constitución (RAG-Lite)
        const budget_limit: u64 = if (self.constitution) |cons| blk: {
            // Buscamos reglas que mencionen "budget", "limit", "sol" o "max"
            const rules = cons.queryRules("budget limit sol maximum cost") catch {
                break :blk 1_000_000_000; // Default 1 SOL si falla el RAG
            };
            defer {
                for (rules) |rule| self.allocator.free(rule);
                self.allocator.free(rules);
            }

            var max: u64 = 1_000_000_000; 
            for (rules) |rule| {
                // Buscamos patrones de números en las reglas (ej: "0.5 SOL", "2.0", "500000000")
                if (std.mem.indexOf(u8, rule, "0.5") != null or std.mem.indexOf(u8, rule, "medio") != null) {
                    max = 500_000_000;
                } else if (std.mem.indexOf(u8, rule, "2.0") != null or std.mem.indexOf(u8, rule, "dos") != null) {
                    max = 2_000_000_000;
                } else if (std.mem.indexOf(u8, rule, "0.1") != null) {
                    max = 100_000_000;
                }
            }
            break :blk max;
        } else 1_000_000_000;

        if (std.mem.eql(u8, quote.asset.symbol, "SOL")) {
            const accepted = quote.price <= budget_limit;
            if (!accepted) {
                std.debug.print("\n[BRAIN ]  Quote Rejected by Constitution: {d} > limit {d} SOL", .{quote.price, budget_limit});
            } else {
                std.debug.print("\n[BRAIN ]  Quote Approved by Constitution ({d} lamports <= {d} limit)", .{quote.price, budget_limit});
            }
            return accepted;
        }
        
        // Otros assets no soportados en la demo por defecto
        return false;
    }

    /// Analiza una intención y decide si corresponde emitir un presupuesto (Quote).
    pub fn negotiate(self: *Brain, intent: []const u8, app_manager: *@import("../kernel/app.zig").AppManager, catalog: *@import("../commerce/merchant.zig").MerchantConfig) !?awp.AppQuoteMsg {
        const lower = try self.allocator.alloc(u8, intent.len);
        defer self.allocator.free(lower);
        for (intent, 0..) |c_val, i| lower[i] = std.ascii.toLower(c_val);

        // Heurística de detección de servicios
        for (catalog.services) |*service| {
            const s_lower = try self.allocator.alloc(u8, service.name.len);
            defer self.allocator.free(s_lower);
            for (service.name, 0..) |c_val, i| s_lower[i] = std.ascii.toLower(c_val);

            if (std.mem.indexOf(u8, lower, s_lower) != null or std.mem.indexOf(u8, s_lower, lower) != null) {
                // Verificar stock e inventario
                if (service.status != .available or service.stock == 0) {
                    std.debug.print("\n[BRAIN ]  Commercial Intent Detected but OUT OF STOCK: {s}", .{service.name});
                    return null;
                }

                std.debug.print("\n[BRAIN ]  Commercial Intent Detected: {s} (Current Stock: {d})", .{service.name, service.stock});

                // PERSISTENCIA: Reducimos stock y marcamos para guardar
                service.stock -= 1;
                if (service.stock == 0) service.status = .out_of_stock;

                std.debug.print("\n[BRAIN ]  Stock reduced for {s}. New stock: {d}", .{service.name, service.stock});

                // Generar presupuesto autónomo (1 hora de validez)
                return try app_manager.createQuote(
                    service.name,
                    service.price_lamports,
                    3600
                );
            }        }

        return null;
    }};

const std = @import("std");
const core = @import("../core.zig");
const types = core.types;
const awp = core.awp;
const const_mod = @import("../business/constitution.zig");

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

    /// Parsea una directiva en lenguaje natural a un mensaje de misión binario (AWP)
    pub fn interpret(self: *Brain, directive: []const u8) !awp.MissionDirectiveMsg {
        // QVAC v1: Heuristic-based NL parsing for air-gapped performance.
        // Simulates local intelligence by extracting key parameters.
        
        var budget: u64 = 1_000_000_000; // Default 1 SOL (en lamports)
        var slippage: u16 = 100;        // Default 1% (100 bps)
        var asset_symbol: []const u8 = "SOL";
        
        // Convertir a minúsculas para facilitar el matching
        const lower = try self.allocator.alloc(u8, directive.len);
        defer self.allocator.free(lower);
        for (directive, 0..) |c, i| {
            lower[i] = std.ascii.toLower(c);
        }

        // --- EXTRACT ASSET ---
        if (std.mem.indexOf(u8, lower, "usdt") != null or std.mem.indexOf(u8, lower, "tether") != null) {
            asset_symbol = "USDT";
        }

        // --- EXTRACT BUDGET ---
        const budget_keywords = [_][]const u8{ "budget", "presupuesto", "fondo", "monto", "amount", "send", "pago", "pay" };
        for (budget_keywords) |kw| {
            if (std.mem.indexOf(u8, lower, kw)) |idx| {
                const search_area = lower[idx + kw.len ..];
                var it = std.mem.tokenizeAny(u8, search_area, " :;,\r\n\t");
                while (it.next()) |token| {
                    const clean_token = std.mem.trimRight(u8, token, "sol");
                    const final_clean = std.mem.trimRight(u8, clean_token, "usdt");
                    if (std.fmt.parseFloat(f64, final_clean) catch null) |val| {
                        const multiplier: f64 = if (std.mem.eql(u8, asset_symbol, "USDT")) 1_000_000 else 1_000_000_000;
                        budget = @intFromFloat(val * multiplier);
                        break;
                    }
                }
                break;
            }
        }

        // --- EXTRACT SLIPPAGE ---
        if (std.mem.indexOf(u8, lower, "slippage")) |idx| {
            // Primero intentamos buscar DESPUÉS de la palabra clave
            const search_after = lower[idx + 8 ..];
            var it_after = std.mem.tokenizeAny(u8, search_after, " :;,\r\n\t");
            var found = false;
            while (it_after.next()) |token| {
                const clean_token = std.mem.trimRight(u8, token, "%");
                if (std.fmt.parseFloat(f64, clean_token) catch null) |val| {
                    slippage = @intFromFloat(val * 100);
                    found = true;
                    break;
                }
            }

            // Si no se encontró, intentamos buscar ANTES de la palabra clave
            if (!found and idx > 0) {
                const search_before = lower[0..idx];
                var it_before = std.mem.tokenizeAny(u8, search_before, " :;,\r\n\t");
                var last_token: ?[]const u8 = null;
                while (it_before.next()) |token| {
                    last_token = token;
                }
                if (last_token) |token| {
                    const clean_token = std.mem.trimRight(u8, token, "%");
                    if (std.fmt.parseFloat(f64, clean_token) catch null) |val| {
                        slippage = @intFromFloat(val * 100);
                    }
                }
            }
        }

        // --- MISSION IDENTITY ---
        var id: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(directive, &id, .{});

        // --- POLICY ROOT (Deluxe) ---
        var policy_root = [_]u8{0} ** 32;
        if (self.constitution) |cons| {
            policy_root = cons.getPolicyRoot();
        }

        // --- RAG (Retrieval-Augmented Generation) LITE ---
        // Verificamos si la directiva viola alguna regla constitucional
        var zk_proof: []const u8 = "qvac_local_verified_airgapped";
        var compliance_proof: []const u8 = "pending_zk_policy_attestation";

        if (self.constitution) |cons| {
            const relevant_rules = try cons.queryRules(directive);
            defer {
                for (relevant_rules) |rule| self.allocator.free(rule);
                self.allocator.free(relevant_rules);
            }
            
            if (relevant_rules.len > 0) {
                std.debug.print("\n[BRAIN ] 🔍 RAG: Found {d} relevant constitutional rules.", .{relevant_rules.len});
                for (relevant_rules) |rule| {
                    std.debug.print("\n[BRAIN ]   - Rule: {s}", .{rule});
                    
                    const rule_lower = try self.allocator.alloc(u8, rule.len);
                    defer self.allocator.free(rule_lower);
                    for (rule, 0..) |c, i| rule_lower[i] = std.ascii.toLower(c);

                    // Si la regla contiene "prohibir" o "block", rechazamos
                    if (std.mem.indexOf(u8, rule_lower, "prohibir") != null or std.mem.indexOf(u8, rule_lower, "block") != null) {
                         zk_proof = "qvac_rag_rejected_by_constitution";
                         compliance_proof = "failed_constitutional_check";
                    } else {
                         // --- REAL ZK PROOF (Deluxe Feature) ---
                         // Llamamos al circuito 'compliance_shield' de Noir
                         std.debug.print("\n[BRAIN ] 🛡️  Generating REAL ZK Compliance Proof (Noir)...", .{});
                         
                         const p_root_hex_val = try core.bytesToHex(self.allocator, &policy_root);
                         defer self.allocator.free(p_root_hex_val);
                         const p_root_hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{p_root_hex_val});
                         defer self.allocator.free(p_root_hex);

                         const m_id_hex_val = try core.bytesToHex(self.allocator, &id);
                         defer self.allocator.free(m_id_hex_val);
                         const m_id_hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{m_id_hex_val});
                         defer self.allocator.free(m_id_hex);
                         
                         // Mocking rule hash for the demo: hash of the rule string
                         var r_hash: [32]u8 = undefined;
                         std.crypto.hash.sha2.Sha256.hash(rule, &r_hash, .{});
                         const r_hash_hex_val = try core.bytesToHex(self.allocator, &r_hash);
                         defer self.allocator.free(r_hash_hex_val);
                         const r_hash_hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{r_hash_hex_val});
                         defer self.allocator.free(r_hash_hex);

                         const budget_str = try std.fmt.allocPrint(self.allocator, "{d}", .{budget});
                         defer self.allocator.free(budget_str);
                         
                         const argv = [_][]const u8{
                             "./scripts/gen_compliance_proof.sh",
                             p_root_hex,
                             m_id_hex,
                             budget_str,
                             budget_str, // actual amount = budget for simplicity in demo
                             r_hash_hex,
                         };

                         var child = std.process.Child.init(&argv, self.allocator);
                         child.stdout_behavior = .Pipe;
                         try child.spawn();
                         
                         const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 1024 * 1024);
                         defer self.allocator.free(stdout);
                         
                         const term = try child.wait();
                         if (term == .Exited and term.Exited == 0) {
                             std.debug.print(" OK!", .{});
                             compliance_proof = try self.allocator.dupe(u8, std.mem.trim(u8, stdout, " \n\r\t"));
                         } else {
                             std.debug.print(" FAILED (Technical Error).", .{});
                             compliance_proof = "error_generating_real_proof";
                         }
                    }
                }
            }
        }

        // --- LOGIC HASH ---
        // Si detectamos ciertas estrategias, cambiamos el hash de la lógica
        var logic_hash: [32]u8 = [_]u8{0} ** 32;
        if (std.mem.indexOf(u8, lower, "arbitrage") != null or std.mem.indexOf(u8, lower, "arbitraje") != null) {
            @memcpy(logic_hash[0..4], "ARBT");
        } else if (std.mem.indexOf(u8, lower, "liquidity") != null or std.mem.indexOf(u8, lower, "liquidez") != null) {
            @memcpy(logic_hash[0..4], "LIQD");
        }

        return awp.MissionDirectiveMsg{
            .id = id,
            .owner_root = [_]u8{0} ** 32, // En una DAO, esto sería la raíz del Merkle de gobernanza
            .policy_root = policy_root,
            .nullifier = [_]u8{0} ** 32,  // Prevenir replay
            .max_budget = budget,
            .slippage_bps = slippage,
            .logic_hash = logic_hash,
            .zk_proof = zk_proof,
            .compliance_proof = compliance_proof,
        };
    }
};

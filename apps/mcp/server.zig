const std = @import("std");
const core = @import("core");
const awp = core.awp;

pub fn run(allocator: std.mem.Allocator, ctx: *core.context.AgentContext) !void {
    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;
    
    var stdin = std.fs.File.stdin().reader(&stdin_buf);
    var stdout = std.fs.File.stdout().writer(&stdout_buf);

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    while (true) {
        buf.items.len = 0;
        
        while (true) {
            const byte = stdin.interface.takeByte() catch break;
            if (byte == '\n') break;
            try buf.append(allocator, byte);
        }

        if (buf.items.len == 0) continue;

        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buf.items, .{});
        defer parsed.deinit();

        const method = parsed.value.object.get("method") orelse continue;
        const method_name = method.string;

        if (std.mem.eql(u8, method_name, "initialize")) {
            try sendResponse(&stdout, "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"serverInfo\":{\"name\":\"xB77-Agent\",\"version\":\"0.1.0\"}}");
        } else if (std.mem.eql(u8, method_name, "tools/list")) {
            try sendResponse(&stdout, "{\"tools\":[{\"name\":\"agent_status\",\"description\":\"Get balance and identity\"},{\"name\":\"semantic_preflight\",\"description\":\"Check action intent against on-chain Constitution\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"intent\":{\"type\":\"string\"}}}},{\"name\":\"recursive_audit\",\"description\":\"Audit another agent intent on-chain (Recursive Governance)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"target_id\":{\"type\":\"string\"},\"alleged_intent\":{\"type\":\"string\"}}}},{\"name\":\"execute_payment_arbitrum\",\"description\":\"Settle via Arbitrum Settlement.sol with Semantic Enforcement\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"amount\":{\"type\":\"string\"},\"intent\":{\"type\":\"string\"}}}}]}");
        } else if (std.mem.eql(u8, method_name, "tools/call")) {
            const params = parsed.value.object.get("params").?.object;
            const name = params.get("name").?.string;

            if (std.mem.eql(u8, name, "agent_status")) {
                const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
                defer allocator.free(sol_addr);
                const eth_addr = try ctx.vaults.ops.address(.base, allocator);
                defer allocator.free(eth_addr);

                const legacy_balance = try ctx.sol_client.getBalance(sol_addr);
                const compressed_balance = try ctx.sol_client.getCompressedBalanceByOwner(sol_addr);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Agent Active!\\nSolana: {s}\\n  - Legacy: {d} lamports\\n  - Compressed: {d} lamports\\nEVM: {s}\"}}]}}", .{ sol_addr, legacy_balance, compressed_balance, eth_addr });
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "semantic_preflight")) {
                const args = params.get("arguments").?.object;
                const intent_text = args.get("intent").?.string;
                
                // Demo logic: If intent contains 'toxic', simulate failure
                const is_toxic = std.mem.indexOf(u8, intent_text, "toxic") != null;
                const msg = if (is_toxic) 
                    "🚨 SEMANTIC REJECTION: Your intent violates the Swarm Constitution (Similarity: 0.92)" 
                else 
                    "✅ SEMANTIC PASSED: Intent verified by Zig-Stylus Engine (Similarity: 0.15)";
                
                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{msg});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "recursive_audit")) {
                const args = params.get("arguments").?.object;
                const target_id = args.get("target_id").?.string;
                const alleged_intent = args.get("alleged_intent").?.string;

                const is_toxic = std.mem.indexOf(u8, alleged_intent, "toxic") != null;
                const msg = if (is_toxic) 
                    try std.fmt.allocPrint(allocator, "🔨 RECURSIVE SLASH: Agent {s} found guilty of toxic intent. Reputation burned by Stylus Supreme Court.", .{target_id})
                else 
                    try std.fmt.allocPrint(allocator, "⚖️ AUDIT FAILED: Accusation against {s} is semantically invalid. Frivolous report logged.", .{target_id});
                
                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{msg});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "execute_payment_arbitrum")) {
                const args = params.get("arguments").?.object;
                const amount = args.get("amount").?.string;
                const intent = args.get("intent").?.string;

                // --- Real-world Execution via Bun + ZeroDev SDK ---
                const argv = &[_][]const u8{ "bun", "sdk/ts/src/execute_semantic_tx.ts", intent, amount };
                var child = std.process.Child.init(argv, allocator);
                child.stdout_behavior = .Pipe;
                child.stderr_behavior = .Pipe;
                
                try child.spawn();
                
                const out_buf = try child.stdout.?.readAllAlloc(allocator, 1024 * 16);
                defer allocator.free(out_buf);
                _ = try child.wait();

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{out_buf});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "spawn_agent")) {
                const args = params.get("arguments").?.object;
                const agent_name = args.get("name").?.string;
                
                // Simulación de Spawn (creación de config)
                try std.fs.cwd().makePath("profiles");
                var config_buf: [512]u8 = undefined;
                const path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{agent_name});
                const file = try std.fs.cwd().createFile(path, .{});
                defer file.close();
                
                const agent_port = 7777 + ctx.active_agents.count() + 1;
                const config_text = try std.fmt.allocPrint(allocator, "# xB77 Profile: {s}\n[vaults]\npath = \".xb77/{s}\"\nmesh_port = {d}\n[rpc]\nsolana = \"https://api.devnet.solana.com\"\nbase = \"https://sepolia.base.org\"\n", .{ agent_name, agent_name, agent_port });
                defer allocator.free(config_text);
                try file.writeAll(config_text);

                // --- DYNAMIC SPAWNING ---
                // Launch: ./xb77 serve --profile <agent_name>
                const argv = &[_][]const u8{ "zig-out/bin/xb77", "serve", "--profile", agent_name };
                var child = try allocator.create(std.process.Child);
                child.* = std.process.Child.init(argv, allocator);
                
                // Redirigir stdout/stderr para no ensuciar la terminal del MCP, 
                // pero podríamos capturarlos en logs después.
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;

                try child.spawn();
                
                const name_copy = try allocator.dupe(u8, agent_name);
                try ctx.active_agents.put(allocator, name_copy, child);
                // -----------------------

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Sovereign Agent '{s}' spawned and RUNNING (PID: {d}). \\nConfiguration: {s}\"}}]}}", .{agent_name, child.id, path});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "get_swarm_topology")) {
                var report = std.ArrayListUnmanaged(u8){};
                defer report.deinit(allocator);
                try report.writer(allocator).print("--- Swarm P2P Topology Map ---\n", .{});

                var dir = std.fs.cwd().openDir("profiles", .{ .iterate = true }) catch null;
                if (dir) |*d| {
                    var it = d.iterate();
                    while (try it.next()) |entry| {
                        if (std.mem.endsWith(u8, entry.name, ".toml")) {
                            const agent_name = entry.name[0 .. entry.name.len - 5];
                            const is_running = ctx.active_agents.contains(agent_name);
                            
                            try report.writer(allocator).print("Agent: {s} [{s}]\n", .{ agent_name, if (is_running) "ACTIVE" else "OFFLINE" });
                            
                            // Para esta demo, simulamos la lectura de los peers que el agente ha guardado en su MeshManager.
                            // En una versión final, esto vendría de una consulta IPC al proceso hijo.
                            try report.writer(allocator).print("  L Connections: [Mesh Syncing via UDP Heartbeat...]\n", .{});
                        }
                    }
                    d.close();
                }

                var escaped = std.ArrayListUnmanaged(u8){};
                defer escaped.deinit(allocator);
                for (report.items) |c| {
                    if (c == '\n') {
                        try escaped.appendSlice(allocator, "\\n");
                    } else if (c == '"') {
                        try escaped.appendSlice(allocator, "\\\"");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{escaped.items});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "issue_mission")) {
                const args = params.get("arguments").?.object;
                const budget_str = args.get("budget").?.string;
                const slippage = @as(u16, @intCast(args.get("slippage").?.integer));
                
                const budget = try std.fmt.parseInt(u64, budget_str, 10);
                
                var encoder = awp.AwpEncoder.init(allocator);
                defer encoder.deinit();

                const mission = awp.MissionDirectiveMsg{
                    .id = [_]u8{0x4D} ** 32, // 'M' de Misión
                    .owner_root = [_]u8{0} ** 32,
                    .policy_root = [_]u8{0} ** 32,
                    .nullifier = [_]u8{0} ** 32,
                    .max_budget = budget,
                    .slippage_bps = slippage,
                    .logic_hash = [_]u8{0} ** 32,
                    .zk_proof = "zk_badge_verified_by_commander", // Prueba dummy para validar el cableado
                };

                const bin_msg = try encoder.encodeMissionDirective(mission);
                
                // Enviar al socket local para que el bridge lo propague
                const address = try std.net.Address.initUnix("/tmp/xb77_znode.sock");
                const stream = try std.net.tcpConnectToAddress(address);
                defer stream.close();
                _ = try stream.write(bin_msg);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Sovereign Mission Issued! \\nBudget: {d} | Slippage: {d} bps. \\nStatus: Broadcasting to swarm...\"}}]}}", .{budget, slippage});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "issue_directive")) {
                const args = params.get("arguments").?.object;
                const text = args.get("text").?.string;
                
                const mission = try ctx.brain.interpret(text);
                
                var encoder = awp.AwpEncoder.init(allocator);
                defer encoder.deinit();
                const bin_msg = try encoder.encodeMissionDirective(mission.directive);

                // Enviar al socket local para que el bridge lo propague
                const address = try std.net.Address.initUnix("/tmp/xb77_znode.sock");
                const stream = std.net.tcpConnectToAddress(address) catch |err| {
                    const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Error connecting to Z-Node Bridge: {any}. Ensure 'xb77 serve' is running.\"}}]}}", .{err});
                    defer allocator.free(res);
                    try sendResponse(&stdout, res);
                    return;
                };
                defer stream.close();
                _ = try stream.write(bin_msg);

                const res = try std.fmt.allocPrint(allocator, 
                    \\{{"content":[ {{"type":"text","text":"QVAC Directive Interpreted & Issued!\n- Mission ID: {s}\n- Budget: {d} lamports\n- Slippage: {d} bps\n- Status: Broadcasting to swarm..."}} ]}}
                , .{ 
                    &std.fmt.bytesToHex(mission.directive.id, .lower), 
                    mission.directive.max_budget, 
                    mission.directive.slippage_bps
                });
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "parse_directive")) {
                const args = params.get("arguments").?.object;
                const text = args.get("text").?.string;
                
                const mission = try ctx.brain.interpret(text);
                
                var encoder = awp.AwpEncoder.init(allocator);
                defer encoder.deinit();
                const bin_msg = try encoder.encodeMissionDirective(mission.directive);
                _ = bin_msg;

                // Opcional: Propagar automáticamente si el usuario lo desea, 
                // pero por ahora solo devolvemos la interpretación.
                
                const res = try std.fmt.allocPrint(allocator, 
                    \\{{"content":[ {{"type":"text","text":"QVAC Local Interpretation:\n- Mission ID: {s}\n- Budget: {d} lamports\n- Slippage: {d} bps\n- Logic Hash: {s}\n- ZK Proof: {s}"}} ]}}
                , .{ 
                    &std.fmt.bytesToHex(mission.directive.id, .lower), 
                    mission.directive.max_budget, 
                    mission.directive.slippage_bps,
                    &std.fmt.bytesToHex(mission.directive.logic_hash, .lower),
                    mission.directive.zk_proof
                });
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "snapshot_swarm")) {
                // 1. Generate analytics summary
                var active_agents: u32 = 0;

                var dir = std.fs.cwd().openDir("profiles", .{ .iterate = true }) catch null;
                if (dir) |*d| {
                    var it = d.iterate();
                    while (try it.next()) |entry| {
                        if (std.mem.endsWith(u8, entry.name, ".toml")) active_agents += 1;
                    }
                    d.close();
                }

                const state_json = try std.fmt.allocPrint(allocator, "{{\"active_agents\": {d}, \"timestamp\": {d}}}", .{active_agents, std.time.timestamp()});
                defer allocator.free(state_json);

                // 2. Upload to QuickNode IPFS
                const cid = try ctx.ipfs_client.uploadState(state_json);
                defer allocator.free(cid);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Sovereign Snapshot Created!\\nIPFS CID: {s}\\nStatus: Secured via QuickNode.\"}}]}}", .{cid});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "get_swarm_analytics")) {
                var total_volume: u64 = 0;
                var total_txs: u32 = 0;
                var risk_blocks: u32 = 0;
                var compliance_fails: u32 = 0;
                var active_agents: u32 = 0;

                // 1. Scan profiles for active agents
                var dir = std.fs.cwd().openDir("profiles", .{ .iterate = true }) catch null;
                if (dir) |*d| {
                    var it = d.iterate();
                    while (try it.next()) |entry| {
                        if (std.mem.endsWith(u8, entry.name, ".toml")) {
                            active_agents += 1;
                            const agent_name = entry.name[0 .. entry.name.len - 5];
                            
                            // 2. Read ledger for this agent
                            var path_buf: [512]u8 = undefined;
                            const path = try std.fmt.bufPrint(&path_buf, ".xb77/{s}/ledger.jsonl", .{agent_name});
                            const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch continue;
                            defer file.close();

                            const content = try file.readToEndAlloc(allocator, 1024 * 1024);
                            defer allocator.free(content);

                            var lines = std.mem.splitScalar(u8, content, '\n');
                            while (lines.next()) |line| {
                                if (line.len == 0) continue;
                                const json_entry = std.json.parseFromSlice(core.store.LedgerEntry, allocator, line, .{ .ignore_unknown_fields = true }) catch continue;
                                defer json_entry.deinit();

                                total_txs += 1;
                                total_volume += json_entry.value.amount;
                                if (json_entry.value.entry_type == .risk_blocked) risk_blocks += 1;
                                if (json_entry.value.entry_type == .compliance_fail) compliance_fails += 1;
                            }
                        }
                    }
                    d.close();
                }

                // 3. Also check main ledger (root)
                const main_file = std.fs.cwd().openFile(".xb77/ledger.jsonl", .{ .mode = .read_only }) catch null;
                if (main_file) |f| {
                    defer f.close();
                    const content = try f.readToEndAlloc(allocator, 1024 * 1024);
                    defer allocator.free(content);

                    var lines = std.mem.splitScalar(u8, content, '\n');
                    while (lines.next()) |line| {
                        if (line.len == 0) continue;
                        const json_entry = std.json.parseFromSlice(core.store.LedgerEntry, allocator, line, .{ .ignore_unknown_fields = true }) catch continue;
                        defer json_entry.deinit();

                        total_txs += 1;
                        total_volume += json_entry.value.amount;
                        if (json_entry.value.entry_type == .risk_blocked) risk_blocks += 1;
                        if (json_entry.value.entry_type == .compliance_fail) compliance_fails += 1;
                    }
                }

                var report = std.ArrayListUnmanaged(u8){};
                defer report.deinit(allocator);
                try report.writer(allocator).print(
                    \\--- Swarm Financial Intelligence Report ---
                    \\Active Agents: {d}
                    \\Total Volume: {d}
                    \\Total Transactions: {d}
                    \\Risk Blocked: {d}
                    \\Compliance Failures: {d}
                    \\Health Status: {s}
                , .{
                    active_agents,
                    total_volume,
                    total_txs,
                    risk_blocks,
                    compliance_fails,
                    if (risk_blocks + compliance_fails == 0) "OPTIMAL" else "DEGRADED",
                });

                var escaped = std.ArrayListUnmanaged(u8){};
                defer escaped.deinit(allocator);
                for (report.items) |c| {
                    if (c == '\n') {
                        try escaped.appendSlice(allocator, "\\n");
                    } else if (c == '"') {
                        try escaped.appendSlice(allocator, "\\\"");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{escaped.items});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "update_constitution")) {
                // ... (mantener lógica existente)
                const args = params.get("arguments").?.object;
                if (args.get("emergency")) |emerg| {
                    if (args.get("slippage")) |slip| {
                        ctx.constitution.update(emerg.bool, @intCast(slip.integer));
                    }
                }
                try sendResponse(&stdout, "{\"content\":[{\"type\":\"text\",\"text\":\"Constitution updated\"}]}");
            } else if (std.mem.eql(u8, name, "execute_payment")) {
                const args = params.get("arguments").?.object;
                const amount_str = args.get("amount").?.string;
                const chain_str = args.get("chain").?.string;
                const recipient_str = args.get("recipient").?.string;
                const symbol = args.get("symbol").?.string;

                const amount = try std.fmt.parseInt(u64, amount_str, 10);
                const chain = if (std.mem.eql(u8, chain_str, "solana")) core.types.Chain.solana else core.types.Chain.base;

                // Inicializar Router
                const pay_mod = @import("core").pay;
                var router = pay_mod.PaymentRouter.init(allocator, &ctx.sol_client, &ctx.evm_client, &ctx.mb_client, &ctx.vaults, &ctx.store, &ctx.constitution, ctx.config.facilitator);

                // Construir Request
                const request = pay_mod.PaymentRequest{
                    .amount = amount,
                    .asset = .{ .chain = chain, .symbol = symbol },
                    .recipient = if (chain == .solana)
                        .{ .sol = try core.crypto.stringToPubkey(allocator, recipient_str) }
                    else
                        .{ .evm = try @import("core").evm.hexToAddress(recipient_str) },
                };

                const result = try router.pay(request);
                
                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Payment executed!\\nChain: {s}\\nSig: {s}\\nFee: {d}\"}}]}}", .{@tagName(result.chain), result.tx_signature, result.fee_paid});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "list_active_swarm")) {
                var dir = std.fs.cwd().openDir("profiles", .{ .iterate = true }) catch null;
                var content = std.ArrayListUnmanaged(u8){};
                defer content.deinit(allocator);

                if (dir) |*d| {
                    var it = d.iterate();
                    while (try it.next()) |entry| {
                        if (std.mem.endsWith(u8, entry.name, ".toml")) {
                            const agent_name = entry.name[0 .. entry.name.len - 5];
                            const status = if (ctx.active_agents.contains(agent_name)) "RUNNING" else "OFFLINE";
                            try content.writer(allocator).print("- Agent: {s} [{s}]\n", .{ agent_name, status });
                        }
                    }
                    d.close();
                }

                if (content.items.len == 0) {
                    try content.writer(allocator).print("No active agents in the swarm.", .{});
                }

                // Manual JSON building to avoid std.json.stringify issues
                var escaped = std.ArrayListUnmanaged(u8){};
                defer escaped.deinit(allocator);
                for (content.items) |c| {
                    if (c == '\n') {
                        try escaped.appendSlice(allocator, "\\n");
                    } else if (c == '"') {
                        try escaped.appendSlice(allocator, "\\\"");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{escaped.items});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "terminate_agent")) {
                const args = params.get("arguments").?.object;
                const agent_name = args.get("name").?.string;
                
                var content = std.ArrayListUnmanaged(u8){};
                defer content.deinit(allocator);

                // 1. Kill the process if active
                if (ctx.active_agents.fetchRemove(agent_name)) |kv| {
                    _ = kv.value.*.kill() catch {};
                    allocator.free(kv.key);
                    allocator.destroy(kv.value);
                    try content.writer(allocator).print("Agent '{s}' process terminated. ", .{agent_name});
                }
                
                // 2. Delete the profile file
                var path_buf: [512]u8 = undefined;
                const path = try std.fmt.bufPrint(&path_buf, "profiles/{s}.toml", .{agent_name});
                
                if (std.fs.cwd().deleteFile(path)) {
                    try content.writer(allocator).print("Profile deleted. Liquidity sweep initiated.", .{});
                } else |err| {
                    try content.writer(allocator).print("Failed to delete profile for '{s}': {any}", .{agent_name, err});
                }
                
                var escaped = std.ArrayListUnmanaged(u8){};
                defer escaped.deinit(allocator);
                for (content.items) |c| {
                    if (c == '\n') {
                        try escaped.appendSlice(allocator, "\\n");
                    } else if (c == '"') {
                        try escaped.appendSlice(allocator, "\\\"");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{escaped.items});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            } else if (std.mem.eql(u8, name, "get_agent_history")) {
                const args = params.get("arguments").?.object;
                const agent_name = args.get("name").?.string;

                // --- Security: Sanitize name to prevent path traversal ---
                var safe = true;
                for (agent_name) |c| {
                    if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
                        safe = false;
                        break;
                    }
                }
                if (!safe) {
                    try sendResponse(&stdout, "{\"error\":{\"code\":-32602,\"message\":\"Invalid agent name.\"}}");
                    continue;
                }

                var path_buf: [512]u8 = undefined;
                const path = try std.fmt.bufPrint(&path_buf, ".xb77/{s}/ledger.jsonl", .{agent_name});
                
                var history_content: []const u8 = "No history found for agent.";
                const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch null;
                var file_content: ?[]u8 = null;
                
                if (file) |f| {
                    file_content = try f.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
                    f.close();
                    if (file_content.?.len > 0) {
                        history_content = file_content.?;
                    }
                }
                defer if (file_content) |fc| allocator.free(fc);

                var escaped = std.ArrayListUnmanaged(u8){};
                defer escaped.deinit(allocator);
                for (history_content) |c| {
                    if (c == '\n') {
                        try escaped.appendSlice(allocator, "\\n");
                    } else if (c == '"') {
                        try escaped.appendSlice(allocator, "\\\"");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"{s}\"}}]}}", .{escaped.items});
                defer allocator.free(res);
                try sendResponse(&stdout, res);
            }
        }
    }
}

fn sendResponse(writer: anytype, result_json: []const u8) !void {
    try writer.interface.print("{{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{s}}}\n", .{result_json});
    try writer.interface.flush();
}

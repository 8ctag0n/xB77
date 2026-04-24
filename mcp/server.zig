const std = @import("std");
const core = @import("core");

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
            try sendResponse(&stdout, "{\"tools\":[{\"name\":\"agent_status\",\"description\":\"Get balance and identity\"}, {\"name\":\"spawn_agent\",\"description\":\"Create a new sovereign agent profile\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}}}}, {\"name\":\"update_constitution\",\"description\":\"Update agent dynamic rules\"}, {\"name\":\"execute_payment\",\"description\":\"Execute a multi-chain payment\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"amount\":{\"type\":\"string\"},\"chain\":{\"type\":\"string\"},\"recipient\":{\"type\":\"string\"},\"symbol\":{\"type\":\"string\"}}}}]}");
        } else if (std.mem.eql(u8, method_name, "tools/call")) {
            const params = parsed.value.object.get("params").?.object;
            const name = params.get("name").?.string;

            if (std.mem.eql(u8, name, "agent_status")) {
                // ...
                const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
                defer allocator.free(sol_addr);
                const eth_addr = try ctx.vaults.ops.address(.base, allocator);
                defer allocator.free(eth_addr);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Agent Active!\\nSolana: {s}\\nEVM: {s}\"}}]}}", .{sol_addr, eth_addr});
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
                
                const config_text = try std.fmt.allocPrint(allocator, "# xB77 Profile: {s}\n[vaults]\npath = \".xb77/{s}\"\n[rpc]\nsolana = \"https://api.devnet.solana.com\"\nbase = \"https://sepolia.base.org\"\n", .{agent_name, agent_name});
                defer allocator.free(config_text);
                try file.writeAll(config_text);

                const res = try std.fmt.allocPrint(allocator, "{{\"content\":[{{\"type\":\"text\",\"text\":\"Sovereign Agent '{s}' spawned successfully. \\nConfiguration: {s}\"}}]}}", .{agent_name, path});
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
                var router = pay_mod.PaymentRouter.init(allocator, &ctx.sol_client, &ctx.evm_client, &ctx.vaults, &ctx.constitution, ctx.config.facilitator);

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
            }
        }
    }
}

fn sendResponse(writer: anytype, result_json: []const u8) !void {
    try writer.interface.print("{{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{s}}}\n", .{result_json});
    try writer.interface.flush();
}

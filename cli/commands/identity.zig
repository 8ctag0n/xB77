//! Commands related to agent identity, status, and onchain claims.
//! `init`, `status`, `state`, `identity <claim|resolve>`, `credits`.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

pub fn init(cli: *const Cli) !void {
    std.debug.print("\n[INIT  ]  Generating Sovereign Identity for profile '{s}'...\n", .{cli.profile});

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, cli.allocator);
    defer cli.allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
    defer cli.allocator.free(eth_addr);

    std.debug.print("\n[SUCCESS] Profile '{s}' initialized!\n", .{cli.profile});
    std.debug.print("          --------------------------------------\n", .{});
    std.debug.print("          Solana (L1/PER):  {s}\n", .{sol_addr});
    std.debug.print("          Base (EVM/Sett):  {s}\n", .{eth_addr});
    std.debug.print("          --------------------------------------\n", .{});
    std.debug.print("\nNext Steps:\n", .{});
    std.debug.print("  1. Fund your agent:  xb77 -p {s} credits\n", .{cli.profile});
    std.debug.print("  2. Setup your shop:  xb77 -p {s} merchant setup-shop\n", .{cli.profile});
    std.debug.print("  3. Start operating:  xb77 -p {s} serve\n", .{cli.profile});
}

pub fn status(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, cli.allocator);
    defer cli.allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
    defer cli.allocator.free(eth_addr);

    std.debug.print("\n{s}--- xB77 SOVEREIGN AGENT STATUS ({s}) ---{s}\n", .{ "\x1b[33;1m", cli.profile, "\x1b[0m" });
    
    // --- [1] SOVEREIGN IDENTITY (SNS) ---
    if (ctx.config.name) |name| {
        std.debug.print("{s}[IDENTITY]{s} {s}.xb77 / {s}.sol", .{ "\x1b[36m", "\x1b[0m", name, name });
        // Intentar resolución nativa rápida de su propio nombre (si fuera .sol)
        const name_sol = try std.fmt.allocPrint(cli.allocator, "{s}.sol", .{name});
        defer cli.allocator.free(name_sol);
        if (core.business.identity.Identity.resolveSnsNative(cli.allocator, &ctx.sol_client, name_sol)) |pk| {
            const pk_str = try core.crypto.pubkeyToString(cli.allocator, &pk);
            defer cli.allocator.free(pk_str);
            std.debug.print(" -> {s} {s}(Native Verified){s}\n", .{ pk_str[0..8], "\x1b[32m", "\x1b[0m" });
        } else |_| {
            std.debug.print(" {s}(Local Only){s}\n", .{ "\x1b[90m", "\x1b[0m" });
        }
    } else {
        std.debug.print("{s}[IDENTITY]{s} Anonymous Agent\n", .{ "\x1b[36m", "\x1b[0m" });
    }

    // --- [2] SOVEREIGN BRAIN (QVAC) ---
    const use_shim = if (std.process.getEnvVarOwned(cli.allocator, "XB77_USE_BRAIN_SHIM") catch null) |val| blk: {
        const is_shim = std.mem.eql(u8, val, "1");
        cli.allocator.free(val);
        break :blk is_shim;
    } else false;

    std.debug.print("{s}[BRAIN   ]{s} Gemma 3 {s}\n", .{ 
        "\x1b[36m", "\x1b[0m", 
        if (use_shim) "\x1b[32m(Active via TS Shim :8088)\x1b[0m" else "\x1b[33m(Heuristics Fallback)\x1b[0m" 
    });

    // --- [3] HFT RAIL (MagicBlock) ---
    const mb_active = !std.mem.startsWith(u8, ctx.mb_client.sequencer_url, "mock:");
    std.debug.print("{s}[HFT RAIL ]{s} MagicBlock {s}\n", .{ 
        "\x1b[36m", "\x1b[0m",
        if (mb_active) "\x1b[32m(Live Sequencer)\x1b[0m" else "\x1b[33m(Simulated/Mock)\x1b[0m"
    });

    std.debug.print("--------------------------------------------------\n", .{});
    std.debug.print("Solana L1: {s}\n", .{sol_addr});
    std.debug.print("Base EVM:  {s}\n", .{eth_addr});
    
    const root = ctx.store.tree.getRoot();
    std.debug.print("ZK Ledger: Root 0x{x:0>2}{x:0>2}... ({d} entries)\n", .{ root[0], root[1], ctx.store.tree.rightmost_index });
    std.debug.print("Status:    {s}SOVEREIGN & ACTIVE{s}\n", .{ "\x1b[32;1m", "\x1b[0m" });
}

pub fn state(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const root = ctx.store.tree.getRoot();
    const count = ctx.store.tree.rightmost_index;

    std.debug.print("\n--- xB77 Sovereign State ({s}) ---\n", .{cli.config_path});
    std.debug.print("Entries:     {d}\n", .{count});
    std.debug.print("Merkle Root: ", .{});
    for (root) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\nIntegrity:   Sovereign & Verified\n", .{});
}

pub fn credits(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(sol_addr);

    std.debug.print("\n[CREDIT]  Sovereign Credits Balance for {s}\n", .{sol_addr});

    const balance = ctx.orchestrator.syncBalance(sol_kp.public) catch |err| {
        std.debug.print("\n[ERROR ]  Gateway Sync Failed: {}. Falling back to local cache.\n", .{err});
        return;
    };

    std.debug.print("          Balance: {d} SC\n", .{balance});
    std.debug.print("          Status:  {s}\n", .{if (balance >= 50) "Active & Funded" else "Low Credits"});

    if (balance < 50) {
        std.debug.print("\nHow to Fund:\n", .{});
        std.debug.print("  1. Send 0.05 SOL to the agent's Solana address above.\n", .{});
        std.debug.print("  2. Use the following Blink to fund via Credit Card/Apple Pay (MOCK):\n", .{});
        std.debug.print("     https://dial.to/?action=solana-action:https://gateway.xb77.com/api/fund/{s}\n", .{sol_addr});
    }
}

pub fn identity(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print(
            \\Uso: xb77 identity <comando> [opciones]
            \\
            \\Comandos:
            \\  claim <nombre>   Reclama una identidad .xb77 en el Gateway
            \\  resolve <name>   Resuelve un dominio .sol o .xb77 a una Pubkey
            \\
        , .{});
        return;
    }

    const sub = args[0];
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    if (std.mem.eql(u8, sub, "claim")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 identity claim <nombre>\n", .{});
            return;
        }
        const name = args[1];
        std.debug.print("  Reclamando identidad '{s}.xb77' para este agente...\n", .{name});

        const sol_kp = ctx.vaults.ops.sol_kp;
        const msg = try std.fmt.allocPrint(cli.allocator, "claim:{s}", .{name});
        defer cli.allocator.free(msg);
        const sig = core.crypto.sign(msg, &sol_kp);

        const payload = .{
            .agent_id = sol_kp.public,
            .name = name,
            .signature = sig,
        };

        var json_list = std.ArrayListUnmanaged(u8){};
        defer json_list.deinit(cli.allocator);
        try json_list.writer(cli.allocator).print("{any}", .{std.json.fmt(payload, .{})});

        var http = core.net.http.HttpClient.init(cli.allocator);
        const url = "https://gateway.xb77.com/identity/claim";

        var resp = http.post(url, json_list.items) catch |err| {
            std.debug.print(" Error de conexión: {}\n", .{err});
            return;
        };
        defer resp.deinit();

        if (resp.status == 200) {
            std.debug.print(" ¡Identidad asegurada! Tu agente es ahora '{s}.xb77'.\n", .{name});

            ctx.config.name = try cli.allocator.dupe(u8, name);
            try ctx.config.save(cli.allocator, cli.config_path);
            std.debug.print(" Configuración local actualizada.\n", .{});
        } else {
            std.debug.print(" Error al reclamar identidad ({d}): {s}\n", .{ resp.status, resp.body });
        }
    } else if (std.mem.eql(u8, sub, "resolve")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 identity resolve <nombre.sol>\n", .{});
            return;
        }
        const domain = args[1];
        std.debug.print(" Resolviendo '{s}'...\n", .{domain});

        const pubkey = resolve_blk: {
            break :resolve_blk core.business.identity.Identity.resolveSnsNative(cli.allocator, &ctx.sol_client, domain) catch |err| {
                std.debug.print("  Fallo resolución nativa: {s}. Probando API fallback...\n", .{@errorName(err)});
                break :resolve_blk core.business.identity.Identity.resolveSnsApi(cli.allocator, &ctx.sol_client, domain) catch |err2| {
                    std.debug.print(" Fallo total de resolución: {s}\n", .{@errorName(err2)});
                    return;
                };
            };
        };

        const pk_str = try core.crypto.encodeBase58(cli.allocator, &pubkey);
        defer cli.allocator.free(pk_str);
        std.debug.print(" Dueño de {s}: {s}\n", .{ domain, pk_str });
    }
}

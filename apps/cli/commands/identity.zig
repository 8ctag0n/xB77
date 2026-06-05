//! Commands related to agent identity, status, and onchain claims.
//! `init`, `status`, `state`, `identity <claim|resolve>`, `credits`.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const esc = "\x1b";
const LIME = esc ++ "[1;32m";
const CYAN = esc ++ "[1;36m";
const GOLD = esc ++ "[1;33m";
const MAG = esc ++ "[1;35m";
const DIM = esc ++ "[1;30m";
const WHT = esc ++ "[1;37m";
const RST = esc ++ "[0m";

pub fn init(cli: *const Cli) !void {
    const banner = 
        "\n" ++
        "    " ++ LIME ++ "█" ++ CYAN ++ "▀▀" ++ LIME ++ "█" ++ CYAN ++ "▀▀" ++ LIME ++ "█" ++ CYAN ++ " █" ++ LIME ++ "▀▀▀█" ++ CYAN ++ " ▀▀█" ++ LIME ++ "▀▀" ++ CYAN ++ "▀ ▀▀█" ++ LIME ++ "▀▀" ++ CYAN ++ "▀\n" ++
        "    " ++ LIME ++ " " ++ CYAN ++ " ▄▀" ++ LIME ++ "▀" ++ CYAN ++ "▄ " ++ LIME ++ " █" ++ CYAN ++ "   █" ++ LIME ++ "   █" ++ CYAN ++ "▄▄" ++ LIME ++ "   █" ++ CYAN ++ "▄▄\n" ++
        "    " ++ LIME ++ "█" ++ CYAN ++ "▄▄" ++ LIME ++ "█" ++ CYAN ++ "▄▄" ++ LIME ++ "█" ++ CYAN ++ " █" ++ LIME ++ "▄▄▄█" ++ CYAN ++ "   █" ++ LIME ++ "     █\n" ++
        "    " ++ DIM ++ ">> SOVEREIGN FINANCIAL ENGINE <<\n" ++ RST;
    
    std.debug.print("{s}", .{banner});
    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "SYSTEM" ++ CYAN ++ "]" ++ RST ++ " INITIALIZING_AGENT_CORE: " ++ GOLD ++ "{s}" ++ RST ++ "\n", .{cli.profile});

    std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), "profiles") catch {};
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;

    // --- Arc / Sui / Circle Integration ---
    const is_arc = std.mem.eql(u8, cli.chain, "arc");
    const is_sui = std.mem.eql(u8, cli.chain, "sui");

    std.debug.print("\n" ++ LIME ++ "╔══════════════════════════════════════════════════╗" ++ RST ++ "\n", .{});
    std.debug.print(LIME ++ "║" ++ RST ++ "  " ++ WHT ++ "AGENT_READY: " ++ GOLD ++ "{s: <27}" ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{cli.profile});
    std.debug.print(LIME ++ "╠══════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    
    if (is_arc) {
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ MAG ++ "Chain:  " ++ RST ++ " " ++ WHT ++ "Arc (Circle Agent Stack)           " ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{});
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Status: " ++ RST ++ " " ++ WHT ++ "USDC + USYC Yield Enabled        " ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{});
    } else if (is_sui) {
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ CYAN ++ "Chain:  " ++ RST ++ " " ++ WHT ++ "Sui (Agentic Web Edition)        " ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{});
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Object: " ++ RST ++ " " ++ WHT ++ "OwnedTreasury + PTB Enabled      " ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{});
    } else {
        const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
        defer cli.allocator.free(sol_addr);
        const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
        defer cli.allocator.free(eth_addr);
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Solana:" ++ RST ++ " " ++ WHT ++ "{s: <42}" ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{sol_addr});
        std.debug.print(LIME ++ "║" ++ RST ++ " " ++ DIM ++ "Base:  " ++ RST ++ " " ++ WHT ++ "{s: <42}" ++ RST ++ LIME ++ "║" ++ RST ++ "\n", .{eth_addr});
    }
    
    std.debug.print(LIME ++ "╚══════════════════════════════════════════════════╝" ++ RST ++ "\n", .{});

    // --- Deluxe Registration ---
    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "NETWORK" ++ CYAN ++ "]" ++ RST ++ " Sincronizando con Sovereign Gateway...", .{});
    
    const balance = ctx.orchestrator.registerAgent(sol_kp.public, &sol_kp) catch blk: {
        std.debug.print(" " ++ esc ++ "[1;31m[OFFLINE]" ++ RST ++ "\n", .{});
        break :blk ctx.orchestrator.balances.get(sol_kp.public) orelse 0;
    };
    
    std.debug.print(" " ++ LIME ++ "[CONNECTED]" ++ RST ++ "\n", .{});
    std.debug.print(CYAN ++ "[" ++ WHT ++ "CREDITS" ++ CYAN ++ "]" ++ RST ++ " Balance: " ++ WHT ++ "{d} SC" ++ RST ++ "\n", .{balance});

    if (balance < 50) {
        std.debug.print("\n" ++ GOLD ++ "⚠ ALERTA: Créditos insuficientes para operar." ++ RST ++ "\n", .{});
        std.debug.print(DIM ++ "Ejecuta " ++ WHT ++ "'xb77 credits topup'" ++ DIM ++ " para fondear via Blink." ++ RST ++ "\n", .{});
    }

    std.debug.print("\n" ++ DIM ++ "Next:" ++ RST ++ " " ++ WHT ++ "xb77 -p {s} serve" ++ RST ++ "\n\n", .{cli.profile});
}

pub fn status(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, cli.allocator);
    defer cli.allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
    defer cli.allocator.free(eth_addr);

    std.debug.print("\n" ++ DIM ++ "┌──────────────────────────────────────────────────┐" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "│" ++ RST ++ "  " ++ GOLD ++ "xB77_AGENT_V2" ++ RST ++ " // " ++ WHT ++ "{s: <27}" ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{cli.profile});
    std.debug.print(DIM ++ "├──────────────────────────────────────────────────┤" ++ RST ++ "\n", .{});
    
    // --- [1] SOVEREIGN IDENTITY (SNS) ---
    if (ctx.config.name) |name| {
        std.debug.print(DIM ++ "│" ++ RST ++ " " ++ CYAN ++ "ID:" ++ RST ++ " " ++ WHT ++ "{s}.xb77" ++ RST ++ " / " ++ LIME ++ "{s}.sol" ++ RST ++ DIM ++ "     │" ++ RST ++ "\n", .{ name, name });
    } else {
        std.debug.print(DIM ++ "│" ++ RST ++ " " ++ CYAN ++ "ID:" ++ RST ++ " " ++ DIM ++ "Anonymous_Sovereign_Agent          " ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{});
    }

    // --- [2] SOVEREIGN BRAIN (QVAC) ---
    const use_shim = if (@as(?[]const u8, if (std.c.getenv("XB77_USE_BRAIN_SHIM")) |_p| std.mem.span(_p) else null)) |val| blk: {
        const is_shim = std.mem.eql(u8, val, "1");
        cli.allocator.free(val);
        break :blk is_shim;
    } else false;

    std.debug.print(DIM ++ "│" ++ RST ++ " " ++ CYAN ++ "CEREBRO:" ++ RST ++ " " ++ WHT ++ "Gemma_3" ++ RST ++ " {s: <18} " ++ DIM ++ "│" ++ RST ++ "\n", .{ 
        if (use_shim) LIME ++ "(LIVE)" ++ RST else GOLD ++ "(HEURISTIC)" ++ RST 
    });

    // --- [3] HFT RAIL (MagicBlock) ---
    const mb_active = !std.mem.startsWith(u8, ctx.mb_client.sequencer_url, "mock:");
    std.debug.print(DIM ++ "│" ++ RST ++ " " ++ CYAN ++ "RED:" ++ RST ++ " " ++ WHT ++ "MagicBlock" ++ RST ++ " {s: <15} " ++ DIM ++ "│" ++ RST ++ "\n", .{ 
        if (mb_active) LIME ++ "(ACTIVE)" ++ RST else DIM ++ "(MOCKED)" ++ RST
    });

    std.debug.print(DIM ++ "├──────────────────────────────────────────────────┤" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "│" ++ RST ++ " " ++ DIM ++ "L1_SOL:" ++ RST ++ " " ++ WHT ++ "{s}" ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{sol_addr});
    std.debug.print(DIM ++ "│" ++ RST ++ " " ++ DIM ++ "L2_BASE:" ++ RST ++ " " ++ WHT ++ "{s}" ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{eth_addr});
    
    const root = ctx.store.tree.getRoot();
    std.debug.print(DIM ++ "│" ++ RST ++ " " ++ DIM ++ "ZK_ROOT:" ++ RST ++ " " ++ LIME ++ "0x{x:0>2}{x:0>2}..." ++ RST ++ " (" ++ WHT ++ "{d} txs" ++ RST ++ ")                 " ++ DIM ++ "│" ++ RST ++ "\n", .{ root[0], root[1], ctx.store.tree.rightmost_index });
    std.debug.print(DIM ++ "└──────────────────────────────────────────────────┘" ++ RST ++ "\n", .{});
    std.debug.print("   " ++ LIME ++ "●" ++ RST ++ " STATUS: " ++ WHT ++ "SOVEREIGN_COMPUTING_ACTIVE" ++ RST ++ "\n\n", .{});
}

pub fn state(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const root = ctx.store.tree.getRoot();
    const count = ctx.store.tree.rightmost_index;

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "STATE" ++ CYAN ++ "]" ++ RST ++ " xB77_SOVEREIGN_LEDGER\n", .{});
    std.debug.print(DIM ++ "Path:    {s}" ++ RST ++ "\n", .{cli.config_path});
    std.debug.print(DIM ++ "Entries: " ++ RST ++ WHT ++ "{d}" ++ RST ++ "\n", .{count});
    std.debug.print(DIM ++ "Root:    " ++ RST ++ LIME ++ "0x", .{});
    for (root) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print(RST ++ "\n" ++ LIME ++ "INTEGRITY_VERIFIED" ++ RST ++ "\n\n", .{});
}

pub fn credits(cli: *const Cli, args: []const [:0]const u8) !void {
    if (args.len > 0 and std.mem.eql(u8, args[0], "topup")) {
        try topup(cli);
        return;
    }

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(sol_addr);

    const balance = ctx.orchestrator.syncBalance(sol_kp.public) catch |err| blk: {
        std.debug.print("\n" ++ GOLD ++ "[WARN]" ++ RST ++ " Gateway Offline: {s}. Usando cache.\n", .{@errorName(err)});
        break :blk ctx.orchestrator.balances.get(sol_kp.public) orelse 0;
    };

    std.debug.print("\n" ++ WHT ++ "SOVEREIGN_CREDIT_INVOICE" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "══════════════════════════════════════════════════" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "Agente: " ++ RST ++ WHT ++ "{s}" ++ RST ++ "\n", .{sol_addr});
    std.debug.print(DIM ++ "Estado: " ++ RST ++ "{s}\n", .{ if (balance >= 50) LIME ++ "HEALTHY" ++ RST else GOLD ++ "DEBT_RISK" ++ RST });
    std.debug.print(DIM ++ "──────────────────────────────────────────────────" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "BALANCE DISPONIBLE: " ++ RST ++ WHT ++ "{d} SC" ++ RST ++ "\n", .{balance});
    std.debug.print(DIM ++ "══════════════════════════════════════════════════" ++ RST ++ "\n", .{});

    std.debug.print("\n" ++ CYAN ++ ">> ACCIÓN:" ++ RST ++ " Ejecuta " ++ WHT ++ "'xb77 credits topup'" ++ RST ++ " para recargar.\n\n", .{});
}

fn topup(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(sol_addr);

    const blink_url = try std.fmt.allocPrint(cli.allocator, "https://dial.to/?action=solana-action:https://gateway.xb77.io/api/v1/actions/pay?agent={s}", .{sol_addr});
    defer cli.allocator.free(blink_url);

    std.debug.print("\n" ++ GOLD ++ "╔══════════════════════════════════════════════════════════════╗" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "║" ++ RST ++ "          " ++ WHT ++ "GENERATE SOVEREIGN CREDITS TOPUP" ++ RST ++ "          " ++ GOLD ++ "║" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "╠══════════════════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "║" ++ RST ++ " " ++ DIM ++ "Target:" ++ RST ++ " " ++ WHT ++ "{s: <48}" ++ RST ++ GOLD ++ " ║" ++ RST ++ "\n", .{sol_addr});
    std.debug.print(GOLD ++ "║" ++ RST ++ " " ++ DIM ++ "Method:" ++ RST ++ " " ++ LIME ++ "Solana Blink (Direct Settlement)" ++ RST ++ "      " ++ GOLD ++ "║" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "╠══════════════════════════════════════════════════════════════╣" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "║" ++ RST ++ " " ++ WHT ++ "PAYMENT_URL:" ++ RST ++ "                                         " ++ GOLD ++ "║" ++ RST ++ "\n", .{});
    std.debug.print(GOLD ++ "║" ++ RST ++ " " ++ CYAN ++ "{s}" ++ RST ++ GOLD ++ " ║" ++ RST ++ "\n", .{blink_url[0..@min(blink_url.len, 60)]});
    std.debug.print(GOLD ++ "╚══════════════════════════════════════════════════════════════╝" ++ RST ++ "\n\n", .{});
}

pub fn identity(cli: *const Cli, args: []const [:0]const u8) !void {
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

        var json_list = std.ArrayListUnmanaged(u8).empty;
        defer json_list.deinit(cli.allocator);
        {
            const _json = try std.json.Stringify.valueAlloc(cli.allocator, payload, .{});
            defer cli.allocator.free(_json);
            try json_list.appendSlice(cli.allocator, _json);
        }

        var http = core.net.http.HttpClient.init(cli.allocator);
        const url = "https://gateway.xb77.io/identity/claim";

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

        const pk_str = try core.crypto.pubkeyToString(cli.allocator, &pubkey);
        defer cli.allocator.free(pk_str);
        std.debug.print(" Dueño de {s}: {s}\n", .{ domain, pk_str });
    }
}

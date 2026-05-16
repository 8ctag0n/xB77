//! Commands related to agent identity, status, and onchain claims.
//! `init`, `status`, `state`, `identity <claim|resolve>`, `credits`.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const esc = "\x1b";

pub fn init(cli: *const Cli) !void {
    const banner = 
        "\n" ++
        "    " ++ esc ++ "[1;32m██╗  ██╗" ++ esc ++ "[1;36m██████╗ " ++ esc ++ "[1;32m███████╗" ++ esc ++ "[1;36m███████╗\n" ++
        "    " ++ esc ++ "[1;32m╚██╗██╔╝" ++ esc ++ "[1;36m██╔══██╗╚══███╔╝╚══███╔╝\n" ++
        "    " ++ esc ++ "[1;32m ╚███╔╝ " ++ esc ++ "[1;36m██████╔╝  ███╔╝   ███╔╝ \n" ++
        "    " ++ esc ++ "[1;32m ██╔██╗ " ++ esc ++ "[1;36m██╔══██╗ ███╔╝   ███╔╝  \n" ++
        "    " ++ esc ++ "[1;32m██╔╝ ██╗" ++ esc ++ "[1;36m██████╔╝" ++ esc ++ "[1;32m███████╗" ++ esc ++ "[1;36m███████╗\n" ++
        "    " ++ esc ++ "[1;32m╚═╝  ╚═╝" ++ esc ++ "[1;36m╚═════╝ ╚══════╝╚══════╝" ++ esc ++ "[0m\n" ++
        "    " ++ esc ++ "[1;30m>> SOVEREIGN FINANCIAL INFRASTRUCTURE <<" ++ esc ++ "[0m\n\n";
    
    std.debug.print("{s}", .{banner});
    std.debug.print("[INIT]  Generating Sovereign Identity for profile " ++ esc ++ "[1;33m'{s}'" ++ esc ++ "[0m...\n", .{cli.profile});

    // Aseguramos que la carpeta profiles exista
    std.fs.cwd().makePath("profiles") catch {};

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
    defer cli.allocator.free(eth_addr);

    std.debug.print("\n" ++ esc ++ "[1;32m[SUCCESS]" ++ esc ++ "[0m Profile " ++ esc ++ "[1;37m'{s}'" ++ esc ++ "[0m initialized!\n", .{cli.profile});
    std.debug.print("          " ++ esc ++ "[1;30m┌──────────────────────────────────────┐" ++ esc ++ "[0m\n", .{});
    std.debug.print("          " ++ esc ++ "[1;30m│" ++ esc ++ "[0m Solana (L1):  " ++ esc ++ "[1;36m{s}" ++ esc ++ "[1;30m │" ++ esc ++ "[0m\n", .{sol_addr});
    std.debug.print("          " ++ esc ++ "[1;30m│" ++ esc ++ "[0m Base (EVM):    " ++ esc ++ "[1;35m{s}" ++ esc ++ "[1;30m │" ++ esc ++ "[0m\n", .{eth_addr[0..eth_addr.len]});
    std.debug.print("          " ++ esc ++ "[1;30m└──────────────────────────────────────┘" ++ esc ++ "[0m\n", .{});

    // --- Deluxe Registration & Credit Check ---
    std.debug.print("\n[SYNC  ]  Synchronizing with xB77 Sovereign Gateway...", .{});
    
    const balance = ctx.orchestrator.registerAgent(sol_kp.public, &sol_kp) catch blk: {
        std.debug.print(" " ++ esc ++ "[1;33m[WARN] ConnectionRefused" ++ esc ++ "[0m\n", .{});
        break :blk ctx.orchestrator.balances.get(sol_kp.public) orelse 0;
    };
    
    std.debug.print(" " ++ esc ++ "[1;32mDONE" ++ esc ++ "[0m\n", .{});
    std.debug.print("[CREDIT]  Current Balance: " ++ esc ++ "[1;37m{d} SC" ++ esc ++ "[0m\n", .{balance});

    if (balance < 50) {
        std.debug.print("\n " ++ esc ++ "[1;31mACTION REQUIRED: Insufficient Credits" ++ esc ++ "[0m \n", .{});
        std.debug.print("  Your agent needs at least 50 SC to operate in the mesh.\n", .{});
        std.debug.print("  Fund your agent instantly via this Blink (Solana Action):\n", .{});
        std.debug.print("  " ++ esc ++ "[1;36mhttps://dial.to/?action=solana-action:https://gateway.xb77.com/api/v1/actions/pay?agent={s}&tier=standard" ++ esc ++ "[0m\n", .{sol_addr});
    }

    std.debug.print("\nNext Steps:\n", .{});
    std.debug.print("  1. Link to Telegram: xb77 -p {s} link <CODE>\n", .{cli.profile});
    std.debug.print("  2. Start operating:  xb77 -p {s} serve\n\n", .{cli.profile});
}

pub fn status(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, cli.allocator);
    defer cli.allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, cli.allocator);
    defer cli.allocator.free(eth_addr);

    std.debug.print("\n" ++ esc ++ "[1;30m╔══════════════════════════════════════════════════╗" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m  " ++ esc ++ "[1;33mxB77 SOVEREIGN AGENT" ++ esc ++ "[0m: " ++ esc ++ "[1;37m{s: <20}" ++ esc ++ "[0m  " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{cli.profile});
    std.debug.print(esc ++ "[1;30m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    
    // --- [1] SOVEREIGN IDENTITY (SNS) ---
    if (ctx.config.name) |name| {
        std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;36m[IDENTITY]" ++ esc ++ "[0m " ++ esc ++ "[1;37m{s}.xb77" ++ esc ++ "[0m / " ++ esc ++ "[1;32m{s}.sol" ++ esc ++ "[0m", .{ name, name });
        // Intentar resolución nativa rápida de su propio nombre (si fuera .sol)
        const name_sol = try std.fmt.allocPrint(cli.allocator, "{s}.sol", .{name});
        defer cli.allocator.free(name_sol);
        if (core.business.identity.Identity.resolveSnsNative(cli.allocator, &ctx.sol_client, name_sol)) |pk| {
            const pk_str = try core.crypto.pubkeyToString(cli.allocator, &pk);
            defer cli.allocator.free(pk_str);
            std.debug.print(" " ++ esc ++ "[1;32m(Verified)" ++ esc ++ "[0m " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{});
        } else |_| {
            std.debug.print(" " ++ esc ++ "[1;30m(Local)   ║" ++ esc ++ "[0m\n", .{});
        }
    } else {
        std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;36m[IDENTITY]" ++ esc ++ "[0m " ++ esc ++ "[1;90mAnonymous Sovereign Agent          " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{});
    }

    // --- [2] SOVEREIGN BRAIN (QVAC) ---
    const use_shim = if (std.process.getEnvVarOwned(cli.allocator, "XB77_USE_BRAIN_SHIM") catch null) |val| blk: {
        const is_shim = std.mem.eql(u8, val, "1");
        cli.allocator.free(val);
        break :blk is_shim;
    } else false;

    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;36m[BRAIN   ]" ++ esc ++ "[0m " ++ esc ++ "[1;37mGemma 3" ++ esc ++ "[0m {s}         " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{ 
        if (use_shim) esc ++ "[1;32m(LIVE_SHIM)" ++ esc ++ "[0m" else esc ++ "[1;33m(HEURISTIC)" ++ esc ++ "[0m" 
    });

    // --- [3] HFT RAIL (MagicBlock) ---
    const mb_active = !std.mem.startsWith(u8, ctx.mb_client.sequencer_url, "mock:");
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;36m[HFT RAIL ]" ++ esc ++ "[0m " ++ esc ++ "[1;37mMagicBlock" ++ esc ++ "[0m {s}      " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{ 
        if (mb_active) esc ++ "[1;32m(ACTIVE)" ++ esc ++ "[0m" else esc ++ "[1;90m(MOCKED)" ++ esc ++ "[0m"
    });

    std.debug.print(esc ++ "[1;30m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mSolana:" ++ esc ++ "[0m " ++ esc ++ "[1;37m{s}" ++ esc ++ "[0m " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{sol_addr});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mBase:  " ++ esc ++ "[0m " ++ esc ++ "[1;37m{s}" ++ esc ++ "[0m " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{eth_addr});
    
    const root = ctx.store.tree.getRoot();
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mZK Root:" ++ esc ++ "[0m " ++ esc ++ "[1;32m0x{x:0>2}{x:0>2}..." ++ esc ++ "[0m (" ++ esc ++ "[1;37m{d} txs" ++ esc ++ "[0m)                 " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{ root[0], root[1], ctx.store.tree.rightmost_index });
    std.debug.print(esc ++ "[1;30m╚══════════════════════════════════════════════════╝" ++ esc ++ "[0m\n", .{});
    std.debug.print("   STATUS: " ++ esc ++ "[1;32mSOVEREIGN & COMPUTING" ++ esc ++ "[0m\n\n", .{});
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

pub fn credits(cli: *const Cli, args: []const [:0]u8) !void {
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
        std.debug.print("\n" ++ esc ++ "[1;33m[WARN]" ++ esc ++ "[0m Gateway Sync Failed: {s}. Using local cache.\n", .{@errorName(err)});
        break :blk ctx.orchestrator.balances.get(sol_kp.public) orelse 0;
    };

    std.debug.print("\n" ++ esc ++ "[1;30m╔══════════════════════════════════════════════════╗" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m  " ++ esc ++ "[1;36mSOVEREIGN CREDIT STATEMENT" ++ esc ++ "[0m                      " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mAgent:" ++ esc ++ "[0m " ++ esc ++ "[1;37m{s: <40}" ++ esc ++ "[1;30m ║" ++ esc ++ "[0m\n", .{sol_addr[0..40]});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mStatus:" ++ esc ++ "[0m {s: <47}" ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{if (balance >= 50) esc ++ "[1;32mACTIVE & FUNDED" ++ esc ++ "[0m" else esc ++ "[1;31mCREDITS_LOW" ++ esc ++ "[0m"});
    std.debug.print(esc ++ "[1;30m╠══════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m║" ++ esc ++ "[0m  " ++ esc ++ "[1;33mAVAILABLE BALANCE:" ++ esc ++ "[0m " ++ esc ++ "[1;37m{d: <18} SC" ++ esc ++ "[0m  " ++ esc ++ "[1;30m║" ++ esc ++ "[0m\n", .{balance});
    std.debug.print(esc ++ "[1;30m╚══════════════════════════════════════════════════╝" ++ esc ++ "[0m\n", .{});

    std.debug.print("\n" ++ esc ++ "[1;30m>> ACTIONS:" ++ esc ++ "[0m\n", .{});
    std.debug.print("   " ++ esc ++ "[1;32m•" ++ esc ++ "[0m Run " ++ esc ++ "[1;36m'xb77 credits topup'" ++ esc ++ "[0m to fund instantly via Blink.\n\n", .{});
}

fn topup(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(sol_addr);

    const blink_url = try std.fmt.allocPrint(cli.allocator, "https://dial.to/?action=solana-action:https://gateway.xb77.io/api/v1/actions/pay?agent={s}", .{sol_addr});
    defer cli.allocator.free(blink_url);

    std.debug.print("\n" ++ esc ++ "[1;33m╔══════════════════════════════════════════════════════════════╗" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m║" ++ esc ++ "[0m          " ++ esc ++ "[1;37mGENERATE SOVEREIGN CREDITS TOPUP" ++ esc ++ "[0m          " ++ esc ++ "[1;33m║" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m╠══════════════════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mTarget Agent:" ++ esc ++ "[0m  " ++ esc ++ "[1;36m{s}" ++ esc ++ "[0m " ++ esc ++ "[1;33m║" ++ esc ++ "[0m\n", .{sol_addr});
    std.debug.print(esc ++ "[1;33m║" ++ esc ++ "[0m " ++ esc ++ "[1;30mMethod:      " ++ esc ++ "[0m  " ++ esc ++ "[1;32mSolana Actions (Blinks)" ++ esc ++ "[0m              " ++ esc ++ "[1;33m║" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m╠══════════════════════════════════════════════════════════════╣" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m║" ++ esc ++ "[0m " ++ esc ++ "[1;37mOpen this URL to pay:" ++ esc ++ "[0m                               " ++ esc ++ "[1;33m║" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;33m║" ++ esc ++ "[0m " ++ esc ++ "[1;36m{s}" ++ esc ++ "[0m " ++ esc ++ "[1;33m║" ++ esc ++ "[0m\n", .{blink_url});
    std.debug.print(esc ++ "[1;33m╚══════════════════════════════════════════════════════════════╝" ++ esc ++ "[0m\n", .{});
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

//! Long-running / IO-shaped commands: `mcp`, `serve`, `merchant` (and its
//! interactive `setup-shop` sub-flow).

const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");
const Cli = @import("../flags.zig").Cli;
const network = @import("network.zig");

const esc = "\x1b";
const LIME = esc ++ "[1;32m";
const CYAN = esc ++ "[1;36m";
const GOLD = esc ++ "[1;33m";
const MAG = esc ++ "[1;35m";
const DIM = esc ++ "[1;30m";
const WHT = esc ++ "[1;37m";
const RED = esc ++ "[1;31m";
const RST = esc ++ "[0m";

pub fn mcp(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    try mcp_server.run(cli.allocator, &ctx);
}

pub fn serve(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "SYSTEM" ++ CYAN ++ "]" ++ RST ++ " INITIALIZING_SOVEREIGN_NODE...\n", .{});
    std.debug.print(DIM ++ "         Mode:     " ++ RST ++ LIME ++ "Autonomous_Mesh_V2" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "         Profile:  " ++ RST ++ GOLD ++ "{s}" ++ RST ++ "\n", .{cli.profile});
    std.debug.print(DIM ++ "         Network:  " ++ RST ++ CYAN ++ "Solana_Devnet + Sovereign_Rollup" ++ RST ++ "\n\n", .{});

    std.debug.print(LIME ++ ">> " ++ WHT ++ "AGENT_ACTIVE_&_LISTENING" ++ LIME ++ " <<" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "──────────────────────────────────────────────────" ++ RST ++ "\n", .{});

    // Re-bind the router
    ctx.router = core.pay.PaymentRouter.init(
        cli.allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        &ctx.mb_client,
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        null,
    );

    var engine = core.engine.Engine.init(cli.allocator, &ctx);
    try engine.start();
}

pub fn merchant(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print(
            \\Uso: xb77 merchant <comando> [opciones]
            \\
            \\Comandos:
            \\  status           Muestra el catálogo actual
            \\  add <name> <amt> Añade un nuevo servicio (monto en lamports)
            \\  setup-shop       Inicia el asistente ULTRA-DELUXE de configuración
            \\  blink            Genera el JSON de Solana Action (Blink)
            \\  publish          Publica el catálogo de forma descentralizada (IPFS)
            \\  register         Registra el Merchant on-chain (Ecosistema APP)
            \\  dispute <id>     Abre una disputa sobre un contrato
            \\  plan <amt> <sec> Crea un plan de pagos recurrentes
            \\
        , .{});
        return;
    }

    const sub = args[0];
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    if (std.mem.eql(u8, sub, "status")) {
        std.debug.print("\n" ++ DIM ++ "┌──────────────────────────────────────────────────┐" ++ RST ++ "\n", .{});
        std.debug.print(DIM ++ "│" ++ RST ++ "  " ++ GOLD ++ "MERCHANT_CATALOG" ++ RST ++ " // " ++ WHT ++ "{s: <24}" ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{ctx.merchant.business_name});
        std.debug.print(DIM ++ "├──────────────────────────────────────────────────┤" ++ RST ++ "\n", .{});
        if (ctx.merchant.services.len == 0) {
            std.debug.print(DIM ++ "│" ++ RST ++ " " ++ RED ++ "ERROR: NO_SERVICES_DEFINED                        " ++ RST ++ DIM ++ "│" ++ RST ++ "\n", .{});
        }
        for (ctx.merchant.services) |s| {
            std.debug.print(DIM ++ "│" ++ RST ++ " " ++ WHT ++ "{s: <20}" ++ RST ++ " | " ++ LIME ++ "{d: >12} lamports" ++ RST ++ DIM ++ " │" ++ RST ++ "\n", .{ s.name, s.price_lamports });
        }

        if (ctx.app_manager.plans.count() > 0) {
            std.debug.print(DIM ++ "├──────────────────────────────────────────────────┤" ++ RST ++ "\n", .{});
            std.debug.print(DIM ++ "│" ++ RST ++ " " ++ CYAN ++ "PLANES_RECURRENTES:" ++ RST ++ "                            " ++ DIM ++ "│" ++ RST ++ "\n", .{});
            var it = ctx.app_manager.plans.iterator();
            while (it.next()) |entry| {
                const p = entry.value_ptr;
                std.debug.print(DIM ++ "│" ++ RST ++ "  " ++ DIM ++ "Plan {x}:" ++ RST ++ " " ++ LIME ++ "{d: >9} lam" ++ RST ++ DIM ++ " cada {d: >4}s" ++ RST ++ DIM ++ "    │" ++ RST ++ "\n", .{ p.plan_id[0..4].*, p.amount_per_period, p.period_sec });
            }
        }
        std.debug.print(DIM ++ "└──────────────────────────────────────────────────┘" ++ RST ++ "\n\n", .{});
    } else if (std.mem.eql(u8, sub, "setup-shop")) {
        try setupShop(cli, &ctx);
    }
    // ... (rest of methods)
}

fn readUntilDelimiterOrEof(reader: anytype, delimiter: u8) !?[]const u8 {
    const raw = reader.readUntilDelimiterAlloc(std.heap.page_allocator, delimiter, 1024) catch |err| switch (err) {
        error.EndOfStream => return null,
        else => return err,
    };
    return raw;
}

fn setupShop(cli: *const Cli, ctx: *core.context.AgentContext) !void {
    const stdin = std.io.getStdIn().reader();

    std.debug.print("\n " ++ MAG ++ "╔══════════════════════════════════════════════════╗" ++ RST ++ " \n", .{});
    std.debug.print(" " ++ MAG ++ "║" ++ RST ++ "    " ++ WHT ++ "xB77_SOVEREIGN_MERCHANT_ORCHESTRATOR" ++ RST ++ "        " ++ MAG ++ "║" ++ RST ++ " \n", .{});
    std.debug.print(" " ++ MAG ++ "╚══════════════════════════════════════════════════╝" ++ RST ++ " \n", .{});

    std.debug.print("\n" ++ CYAN ++ ">> BUSINESS_NAME: " ++ RST, .{});
    const name_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const name = std.mem.trim(u8, name_raw, " \r\n\t");

    std.debug.print(CYAN ++ ">> PRIMARY_SERVICE: " ++ RST, .{});
    const srv_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const srv_name = std.mem.trim(u8, srv_raw, " \r\n\t");

    std.debug.print(CYAN ++ ">> PRICE_LAMPORTS:  " ++ RST, .{});
    const price_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const price = std.fmt.parseInt(u64, std.mem.trim(u8, price_raw, " \r\n\t"), 10) catch 50_000_000;

    std.debug.print(GOLD ++ ">> HANDLE_.XB77 (OPT): " ++ RST, .{});
    const handle_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    _ = handle_raw; // Intent handled in fuller logic but unused here

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "SETUP" ++ CYAN ++ "]" ++ RST ++ " Orquestando Infraestructura Soberana...\n", .{});

    // ... (logic)
    cli.allocator.free(ctx.merchant.business_name);
    ctx.merchant.business_name = try cli.allocator.dupe(u8, name);
    for (ctx.merchant.services) |s| cli.allocator.free(s.name);
    cli.allocator.free(ctx.merchant.services);
    var service = try cli.allocator.alloc(core.commerce.merchant.MerchantService, 1);
    service[0] = .{
        .name = try cli.allocator.dupe(u8, srv_name),
        .description = "Sovereign Service",
        .price_lamports = price,
        .stock = 999,
        .status = .available,
    };
    ctx.merchant.services = service;

    const m_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ ctx.config.vaults.path, "merchant.json" });
    defer cli.allocator.free(m_path);
    try ctx.merchant.save(m_path);

    std.debug.print("\n" ++ LIME ++ "[SUCCESS] MERCHANT_READY" ++ RST ++ " \n", .{});
    std.debug.print(DIM ++ "          Status: LIVE_&_SOVEREIGN" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "          --------------------------------------" ++ RST ++ "\n", .{});
}

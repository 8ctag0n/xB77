//! Long-running / IO-shaped commands: `mcp`, `serve`, `merchant` (and its
//! interactive `setup-shop` sub-flow).

const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");
const Cli = @import("../flags.zig").Cli;

const RST  = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM  = "\x1b[2m";
const RED  = "\x1b[31m";
const LIME = "\x1b[32m";
const GOLD = "\x1b[33m";
const BLUE = "\x1b[34m";
const MAG  = "\x1b[35m";
const CYAN = "\x1b[36m";
const WHT  = "\x1b[37m";

pub fn mcp(cli: *const Cli) !void {
    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "MCP" ++ CYAN ++ "]" ++ RST ++ " Iniciando orquestador de agentes...\n", .{});
    
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    ctx.mesh_manager.store = &ctx.store;

    try mcp_server.run(cli.allocator, &ctx);
}

pub fn serve(cli: *const Cli) !void {
    std.debug.print("\n" ++ GOLD ++ "[" ++ WHT ++ "SERVE" ++ GOLD ++ "]" ++ RST ++ " Operación Autónoma 24/7 activada.\n", .{});
    
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    ctx.mesh_manager.store = &ctx.store;

    var engine = core.kernel.Engine.init(cli.allocator, &ctx);
    try engine.start();

    // Loop de vida infinita hasta SIGINT
    while (engine.is_running) {
        std.Io.sleep(std.Io.Threaded.global_single_threaded.io(), .{ .nanoseconds = @intCast(1 * std.time.ns_per_s) }, .awake) catch {};
    }
}

pub fn merchant(cli: *const Cli, args: []const [:0]const u8) !void {
    if (args.len < 1) {
        std.debug.print(
            \\Uso: xb77 merchant <comando> [opciones]
            \\
            \\Comandos:
            \\  status           Ver catálogo y estado comercial
            \\  setup-shop       Asistente interactivo de configuración
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
    } else if (std.mem.eql(u8, sub, "blink")) {
        try generateBlink(cli, &ctx);
    }
}

fn generateBlink(cli: *const Cli, ctx: *core.context.AgentContext) !void {
    const sol_addr = try ctx.vaults.ops.address(.solana, cli.allocator);
    defer cli.allocator.free(sol_addr);

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "BLINK" ++ CYAN ++ "]" ++ RST ++ " Generando Solana Action (Blink)...\n", .{});

    const json = try std.fmt.allocPrint(cli.allocator,
        \\{{
        \\  "icon": "https://xb77.io/assets/blink-icon.png",
        \\  "title": "{s}",
        \\  "description": "Purchase sovereign services via xB77 Agent Wire Protocol (AWP).",
        \\  "label": "Pay with Agent",
        \\  "links": {{
        \\    "actions": [
        \\      {{ "label": "Standard Tier", "href": "/api/v1/actions/pay?tier=std" }},
        \\      {{ "label": "Premium Tier", "href": "/api/v1/actions/pay?tier=premium" }}
        \\    ]
        \\  }}
        \\}}
    , .{ctx.merchant.business_name});
    defer cli.allocator.free(json);

    std.debug.print("\n{s}\n\n", .{json});
    std.debug.print(LIME ++ "[SUCCESS]" ++ RST ++ " Blink JSON generated. Distribute this URL to your users.\n", .{});
}

fn readLine(file: std.Io.File, buffer: []u8) ![]const u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    var pos: usize = 0;
    while (pos < buffer.len) {
        var byte_buf: [1]u8 = undefined;
        var bufs = [_][]u8{&byte_buf};
        const n = try file.readStreaming(io, &bufs);
        if (n == 0) break;
        if (byte_buf[0] == '\n') break;
        buffer[pos] = byte_buf[0];
        pos += 1;
    }
    return std.mem.trim(u8, buffer[0..pos], " \r\n\t");
}

fn setupShop(cli: *const Cli, ctx: *core.context.AgentContext) !void {
    const stdin_file = std.Io.File.stdin();
    var buf: [1024]u8 = undefined;

    std.debug.print("\n " ++ MAG ++ "╔══════════════════════════════════════════════════╗" ++ RST ++ " \n", .{});
    std.debug.print(" " ++ MAG ++ "║" ++ RST ++ "    " ++ WHT ++ "xB77_SOVEREIGN_MERCHANT_ORCHESTRATOR" ++ RST ++ "        " ++ MAG ++ "║" ++ RST ++ " \n", .{});
    std.debug.print(" " ++ MAG ++ "╚══════════════════════════════════════════════════╝" ++ RST ++ " \n", .{});

    std.debug.print("\n" ++ CYAN ++ ">> BUSINESS_NAME: " ++ RST, .{});
    const name = try readLine(stdin_file, &buf);

    std.debug.print(CYAN ++ ">> PRIMARY_SERVICE: " ++ RST, .{});
    const srv_name_raw = try readLine(stdin_file, &buf);
    const srv_name = try cli.allocator.dupe(u8, srv_name_raw);

    std.debug.print(CYAN ++ ">> PRICE_LAMPORTS:  " ++ RST, .{});
    const price_raw = try readLine(stdin_file, &buf);
    const price = std.fmt.parseInt(u64, price_raw, 10) catch 50_000_000;

    std.debug.print(GOLD ++ ">> HANDLE_.XB77 (OPT): " ++ RST, .{});
    _ = try readLine(stdin_file, &buf);

    std.debug.print("\n" ++ CYAN ++ "[" ++ WHT ++ "SETUP" ++ CYAN ++ "]" ++ RST ++ " Orquestando Infraestructura Soberana...\n", .{});

    cli.allocator.free(ctx.merchant.business_name);
    ctx.merchant.business_name = try cli.allocator.dupe(u8, name);
    for (ctx.merchant.services) |s| cli.allocator.free(s.name);
    cli.allocator.free(ctx.merchant.services);
    
    var services = try cli.allocator.alloc(core.commerce.merchant.MerchantService, 1);
    services[0] = .{
        .name = srv_name,
        .description = "Sovereign Service",
        .price_lamports = price,
        .stock = 999,
        .status = .available,
    };
    ctx.merchant.services = services;

    const m_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ ctx.config.vaults.path, "merchant.json" });
    defer cli.allocator.free(m_path);
    try ctx.merchant.save(m_path);

    std.debug.print("\n" ++ LIME ++ "[SUCCESS] MERCHANT_READY" ++ RST ++ " \n", .{});
    std.debug.print(DIM ++ "          Status: LIVE_&_SOVEREIGN" ++ RST ++ "\n", .{});
    std.debug.print(DIM ++ "          --------------------------------------" ++ RST ++ "\n", .{});
}

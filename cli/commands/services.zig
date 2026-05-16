//! Long-running / IO-shaped commands: `mcp`, `serve`, `merchant` (and its
//! interactive `setup-shop` sub-flow).

const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");
const Cli = @import("../flags.zig").Cli;
const network = @import("network.zig");
const esc = "\x1b";

pub fn mcp(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    try mcp_server.run(cli.allocator, &ctx);
}

pub fn serve(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    std.debug.print("\n" ++ esc ++ "[1;36m[SYSTEM]" ++ esc ++ "[0m Initializing Sovereign Node Engine...\n", .{});
    std.debug.print(esc ++ "[1;30m         Mode:     " ++ esc ++ "[1;32mAutonomous / Full-Stack" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m         Profile:  " ++ esc ++ "[1;33m{s}" ++ esc ++ "[0m\n", .{cli.profile});
    std.debug.print(esc ++ "[1;30m         Network:  " ++ esc ++ "[1;36mSolana Devnet + Mesh" ++ esc ++ "[0m\n\n", .{});

    std.debug.print(esc ++ "[1;32m>> AGENT ACTIVE & LISTENING <<" ++ esc ++ "[0m\n", .{});
    std.debug.print(esc ++ "[1;30m--------------------------------------------------" ++ esc ++ "[0m\n", .{});

    // Re-bind the router to ctx's stable address
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
        std.debug.print("\n--- {s} Catalog ---\n", .{ctx.merchant.business_name});
        if (ctx.merchant.services.len == 0) {
            std.debug.print("No services defined. Use 'xb77 merchant add' to start.\n", .{});
        }
        for (ctx.merchant.services) |s| {
            std.debug.print(" {s:<20} | {d:>12} lamports\n", .{ s.name, s.price_lamports });
        }

        if (ctx.app_manager.plans.count() > 0) {
            std.debug.print("\n--- Active Plans ---\n", .{});
            var it = ctx.app_manager.plans.iterator();
            while (it.next()) |entry| {
                const p = entry.value_ptr;
                std.debug.print("  Plan {x}: {d} lamports every {d}s\n", .{ p.plan_id[0..4].*, p.amount_per_period, p.period_sec });
            }
        }
    } else if (std.mem.eql(u8, sub, "add")) {
        if (args.len < 3) {
            std.debug.print("Uso: xb77 merchant add <nombre> <precio_lamports> [stock]\n", .{});
            return;
        }
        const name = args[1];
        const price = try std.fmt.parseInt(u64, args[2], 10);
        const stock = if (args.len > 3) try std.fmt.parseInt(u32, args[3], 10) else 10;

        std.debug.print("Añadiendo servicio: {s} ({d} lamports, stock: {d})...\n", .{ name, price, stock });

        var new_services = try cli.allocator.alloc(core.commerce.merchant.MerchantService, ctx.merchant.services.len + 1);
        @memcpy(new_services[0..ctx.merchant.services.len], ctx.merchant.services);
        new_services[ctx.merchant.services.len] = .{
            .name = try cli.allocator.dupe(u8, name),
            .description = "Service from CLI",
            .price_lamports = price,
            .stock = stock,
            .status = .available,
        };
        ctx.merchant.services = new_services;

        const m_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ ctx.config.vaults.path, "merchant.json" });
        defer cli.allocator.free(m_path);
        try ctx.merchant.save(m_path);

        std.debug.print(" Servicio añadido y guardado en {s}\n", .{m_path});
    } else if (std.mem.eql(u8, sub, "blink")) {
        const blink = try ctx.merchant.generateBlink(cli.allocator, "https://gateway.xb77.com");
        defer cli.allocator.free(blink);
        std.debug.print("\n--- Solana Action (Blink) Metadata ---\n{s}\n", .{blink});
    } else if (std.mem.eql(u8, sub, "publish")) {
        std.debug.print(" Iniciando publicación descentralizada (IPFS)...\n", .{});

        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(cli.allocator);
        try list.writer(cli.allocator).print("{any}", .{std.json.fmt(ctx.merchant, .{})});

        const cid = try ctx.ipfs_client.uploadState(list.items);
        std.debug.print(" Catálogo publicado en IPFS: {s}\n", .{cid});

        std.debug.print(" Anclando CID en el registro on-chain...", .{});
        const sig = try ctx.registry_manager.addCatalog(ctx.vaults.ops.sol_kp.public, cid, &ctx.vaults.ops.sol_kp);
        std.debug.print("\n Registro completado. Sig: {s}\n", .{sig});

        std.debug.print("  Anunciando a la red Mesh...\n", .{});
        try ctx.mesh_manager.tick();
        std.debug.print(" IP Protegida. Tu agente ahora es global.\n", .{});
    } else if (std.mem.eql(u8, sub, "register")) {
        // IDL-driven onchain registration (replaces the legacy RegistryManager path).
        const merchant_onchain = @import("merchant_onchain.zig");
        try merchant_onchain.register(cli, args[1..]);
    } else if (std.mem.eql(u8, sub, "dispute")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 merchant dispute <hire_id_hex>\n", .{});
            return;
        }
        std.debug.print(" Disputa abierta para contrato {s}.\n", .{args[1]});
    } else if (std.mem.eql(u8, sub, "plan")) {
        if (args.len < 3) {
            std.debug.print("Uso: xb77 merchant plan <monto_lamports> <segundos>\n", .{});
            return;
        }
        const amt = try std.fmt.parseInt(u64, args[1], 10);
        const sec = try std.fmt.parseInt(u64, args[2], 10);

        const plan = try ctx.app_manager.createPlan(.{ .chain = .solana, .symbol = "SOL" }, amt, sec, 12);
        const plan_id_hex = try core.security.crypto.bytesToHex(cli.allocator, &plan.plan_id);
        defer cli.allocator.free(plan_id_hex);

        std.debug.print("\n[MERCH ]  Recurring Plan created successfully!\n", .{});
        std.debug.print("          Plan ID: {s}\n", .{plan_id_hex});
        std.debug.print("          Terms:   {d} lamports every {d} seconds\n", .{ amt, sec });
    } else if (std.mem.eql(u8, sub, "setup-shop")) {
        try setupShop(cli, &ctx);
    }
}

fn readUntilDelimiterOrEof(reader: *std.io.Reader, delimiter: u8) !?[]const u8 {
    const raw = reader.takeDelimiterInclusive(delimiter) catch |err| switch (err) {
        error.EndOfStream => return null,
        else => return err,
    };
    if (raw.len > 0 and raw[raw.len - 1] == delimiter) {
        return raw[0 .. raw.len - 1];
    }
    return raw;
}

/// Interactive merchant onboarding. Exposed as the `merchant setup-shop`
/// sub-command. Calls into `network.deploy` at the end to sync with the
/// global edge.
fn setupShop(cli: *const Cli, ctx: *core.context.AgentContext) !void {
    const stdin_file = std.fs.File.stdin();
    var stdin_buf: [1024]u8 = undefined;
    var stdin_wrapper = stdin_file.reader(&stdin_buf);
    const stdin = &stdin_wrapper.interface;

    std.debug.print("\n xB77 ULTRA-DELUXE MERCHANT SETUP \n", .{});
    std.debug.print("--------------------------------------\n", .{});

    std.debug.print("Business Name: ", .{});
    const name_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const name = std.mem.trim(u8, name_raw, " \r\n\t");

    std.debug.print("Primary Service Name: ", .{});
    const srv_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const srv_name = std.mem.trim(u8, srv_raw, " \r\n\t");

    std.debug.print("Price (in lamports, e.g. 50000000): ", .{});
    const price_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const price = std.fmt.parseInt(u64, std.mem.trim(u8, price_raw, " \r\n\t"), 10) catch 50_000_000;

    std.debug.print("Claim your .xb77 handle (leave empty to skip): ", .{});
    const handle_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const handle = std.mem.trim(u8, handle_raw, " \r\n\t");

    std.debug.print("\n[SETUP ]  Orchestrating Sovereign Infrastructure...\n", .{});

    // Automatic Defaults: Facilitator and Registry
    if (ctx.config.facilitator == null) {
        ctx.config.facilitator = try cli.allocator.dupe(u8, "xB77infraTax11111111111111111111111111111");
    }
    if (ctx.config.registry_program_id == null) {
        ctx.config.registry_program_id = try cli.allocator.dupe(u8, "Reg111111111111111111111111111111111111111");
    }
    try ctx.config.save(cli.allocator, cli.config_path);

    // Free previously-owned strings before overwriting so the eventual
    // ctx.merchant.deinit() doesn't free literals.
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

    if (handle.len > 0) {
        std.debug.print("[SETUP ]   Claiming {s}.xb77... ", .{handle});
        const sol_kp = ctx.vaults.ops.sol_kp;
        const msg = try std.fmt.allocPrint(cli.allocator, "claim:{s}", .{handle});
        defer cli.allocator.free(msg);
        const sig = core.security.crypto.sign(msg, &sol_kp);

        const payload = .{ .agent_id = sol_kp.public, .name = handle, .signature = sig };
        var json_list = std.ArrayListUnmanaged(u8){};
        defer json_list.deinit(cli.allocator);
        try json_list.writer(cli.allocator).print("{any}", .{std.json.fmt(payload, .{})});

        var http_client = core.mesh.http.HttpClient.init(cli.allocator);
        _ = http_client.post("https://gateway.xb77.com/identity/claim", json_list.items) catch {
            std.debug.print(" Gateway unreachable, skipping claim.\n", .{});
        };
        ctx.config.name = try cli.allocator.dupe(u8, handle);
        try ctx.config.save(cli.allocator, cli.config_path);
        std.debug.print("DONE\n", .{});
    }

    std.debug.print("[SETUP ]  Syncing with Global Edge... ", .{});
    try network.deploy(cli, &[_][:0]u8{});
    std.debug.print("DONE\n", .{});

    std.debug.print("\n[SUCCESS] SHOP IS LIVE AND SOVEREIGN! \n", .{});
    if (ctx.config.name) |h| {
        std.debug.print("          Public Profile: https://gateway.xb77.com/p/{s}\n", .{h});
    }
    std.debug.print("          Blink Link:     https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/pay\n", .{});
    std.debug.print("          --------------------------------------\n", .{});
}

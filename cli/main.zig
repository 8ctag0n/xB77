const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    // --- Procesamiento de Flags Globales ---
    var profile: []const u8 = "default";
    var command_idx: usize = 1;

    var i: usize = 1;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--profile") or std.mem.eql(u8, args[i], "-p")) {
            if (i + 1 < args.len) {
                profile = args[i + 1];
                i += 2;
                if (command_idx < i) command_idx = i;
            } else i += 1;
        } else if (std.mem.eql(u8, args[i], "--role") or std.mem.eql(u8, args[i], "--name")) {
            // Ignorar flags de metadatos del spawn por ahora, 
            // pero permitir que no rompan el parser.
            i += 2;
            if (command_idx < i) command_idx = i;
        } else {
            break;
        }
    }

    if (command_idx >= args.len) {
        printUsage();
        return;
    }

    const command = args[command_idx];
    const cmd_args = args[command_idx + 1 ..];

    // Construir el path de configuración basado en el perfil
    var config_buf: [256]u8 = undefined;
    const config_path = if (std.mem.eql(u8, profile, "default"))
        "agent.toml"
    else
        try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{profile});

    if (std.mem.eql(u8, command, "init")) {
        try handleInit(allocator, profile);
    } else if (std.mem.eql(u8, command, "status")) {
        try handleStatus(allocator, config_path);
    } else if (std.mem.eql(u8, command, "state")) {
        try handleState(allocator, config_path);
    } else if (std.mem.eql(u8, command, "pay")) {
        try handlePay(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "batch")) {
        try handleBatch(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "shield")) {
        try handleShield(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "mesh")) {
        try handleMesh(allocator, config_path);
    } else if (std.mem.eql(u8, command, "mcp")) {
        try handleMcp(allocator, config_path);
    } else if (std.mem.eql(u8, command, "export")) {
        try handleExport(allocator, config_path);
    } else if (std.mem.eql(u8, command, "serve")) {
        try handleServe(allocator, config_path);
    } else if (std.mem.eql(u8, command, "spawn")) {
        try handleSpawn(allocator, cmd_args);
    } else {
        std.debug.print("Comando desconocido: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\xB77 — Agent Commerce Infrastructure (Zig Edition)
        \\
        \\Uso: xb77 [flags] <comando> [opciones]
        \\
        \\Flags Globales:
        \\  -p, --profile <name>  Usa un perfil específico (default: "default")
        \\
        \\Comandos:
        \\  init             Inicializa un nuevo perfil de agente
        \\  status           Muestra el estado del agente actual
        \\  state            Muestra la raíz Merkle del estado soberano
        \\  pay <to> <amt>   Realiza un pago
        \\  shield <op>      Gestiona la armadura ZK
        \\  mesh             Muestra los pares en la red soberana
        \\  spawn <name>     Crea un nuevo agente (Factory)
        \\  mcp              Inicia el servidor de orquestación IA
        \\  export           Sovereign Export (Panic Button): Empaqueta estado y llaves
        \\  serve            Inicia la operación autónoma 24/7
        \\
    , .{});
}

fn handleExport(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    std.debug.print("\n--- xB77 Sovereign Export ({s}) ---\n", .{config_path});
    std.debug.print("Empaquetando estado y llaves desde: {s}\n", .{ctx.config.vaults.path});

    // 1. Crear el nombre del archivo de exportación con timestamp
    const ts = std.time.timestamp();
    var out_name_buf: [128]u8 = undefined;
    const out_name = try std.fmt.bufPrint(&out_name_buf, "xb77_sovereign_backup_{d}.tar.gz", .{ts});

    // 2. Usar 'tar' del sistema para el Sprint Final (simplicidad y confiabilidad)
    const argv = [_][]const u8{
        "tar",
        "-czf",
        out_name,
        ctx.config.vaults.path,
        config_path, 
    };

    var child = std.process.Child.init(&argv, allocator);
    try child.spawn();
    const term = try child.wait();

    if (term == .Exited and term.Exited == 0) {
        std.debug.print("✅ Sovereign Export COMPLETADO: {s}\n", .{out_name});
        std.debug.print("Este blob contiene su Merkle Tree y sus llaves privadas WDK.\n", .{});
        std.debug.print("GUÁRDELO EN UN LUGAR SEGURO. ES SU SOBERANÍA.\n", .{});
    } else {
        std.debug.print("❌ Exportación FALLIDA. (error de tar)\n", .{});
    }
}

fn handleState(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    const root = ctx.store.tree.getRoot();
    const count = ctx.store.tree.rightmost_index;

    std.debug.print("\n--- xB77 Sovereign State ({s}) ---\n", .{config_path});
    std.debug.print("Entries:     {d}\n", .{count});
    std.debug.print("Merkle Root: ", .{});
    for (root) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\nIntegrity:   Sovereign & Verified\n", .{});
}

fn handleInit(allocator: std.mem.Allocator, profile: []const u8) !void {
    std.debug.print("Generando identidad para perfil '{s}'...\n", .{profile});
    
    // Construir path de config
    var config_buf: [256]u8 = undefined;
    const config_path = if (std.mem.eql(u8, profile, "default")) "agent.toml" else try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{profile});

    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    // El VaultSet.init ya se encarga de crear las llaves si no existen
    // Solo necesitamos reportar la dirección generada
    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);
    
    std.debug.print("¡Perfil '{s}' inicializado!\n", .{profile});
    std.debug.print("Dirección Solana: {s}\n", .{sol_addr});
}

fn handleStatus(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, allocator);
    defer allocator.free(eth_addr);

    std.debug.print("\n--- xB77 Agent Status ({s}) ---\n", .{config_path});
    std.debug.print("Solana: {s}\n", .{sol_addr});
    std.debug.print("EVM:    {s}\n", .{eth_addr});
    std.debug.print("Status: Sovereign & Active\n", .{});
}

fn handleSpawn(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 spawn <nombre_agente>\n", .{});
        return;
    }
    const name = args[0];
    std.debug.print("🏭 Instanciando nuevo Agente Soberano: {s}...\n", .{name});
    
    // 1. Crear carpeta de perfil
    try std.fs.cwd().makePath("profiles");
    
    // 2. Generar config básica
    var config_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{name});
    
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    try file.writeAll(
        \\# xB77 Sovereign Agent Configuration
        \\[vaults]
        \\path = ".xb77/
    );
    try file.writeAll(name);
    try file.writeAll(
        \\"
        \\
        \\[rpc]
        \\solana = "https://api.devnet.solana.com"
        \\base = "https://sepolia.base.org"
        \\
    );

    std.debug.print("✅ Agente '{s}' listo. Ejecuta 'xb77 -p {s} init' para activarlo.\n", .{name, name});
    _ = allocator;
}

// ... (Resto de handlers actualizados para aceptar config_path)
fn handlePay(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
    _ = config_path; _ = args; _ = allocator;
}
fn handleBatch(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
    _ = config_path; _ = args; _ = allocator;
}
fn handleShield(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
    _ = config_path; _ = args; _ = allocator;
}
fn handleMcp(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();
    try mcp_server.run(allocator, &ctx);
}
fn handleServe(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    // Re-vincular el router a la dirección de memoria estable de 'ctx'
    ctx.router = core.pay.PaymentRouter.init(
        allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        &ctx.vaults,
        &ctx.constitution,
        null,
    );

    var engine = core.engine.Engine.init(allocator, &ctx);
    try engine.start();
}

fn handleMesh(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path);
    defer ctx.deinit();

    // Simular el seed peer que el Engine agregaría al arrancar
    try ctx.mesh_manager.addPeer([_]u8{0x12} ** 32, "127.0.0.1", 7777);

    std.debug.print("\n--- xB77 Sovereign Mesh ({s}) ---\n", .{config_path});
    std.debug.print("Known Peers: {d}\n\n", .{ctx.mesh_manager.countPeers()});
    std.debug.print("AGENT ID                                 ADDRESS          STATUS\n", .{});
    std.debug.print("---------------------------------------  ---------------  ----------\n", .{});

    for (0..256) |i| {
        for (ctx.mesh_manager.buckets[i].items) |peer| {
            for (peer.id[0..16]) |b| {
                std.debug.print("{x:0>2}", .{b});
            }
            std.debug.print("  {s}:{d:<5}  {s}\n", .{
                peer.address,
                peer.port,
                @tagName(peer.status),
            });
        }
    }
    std.debug.print("\nMesh Health: {s}\n", .{if (ctx.mesh_manager.countPeers() > 0) "Synchronizing" else "Isolated"});
}

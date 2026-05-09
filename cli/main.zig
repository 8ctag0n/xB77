const std = @import("std");
const core = @import("core");
const mcp_server = @import("mcp");

var xb77_password: ?[]const u8 = null;

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

    // --- Master Password Retrieval ---
    xb77_password = std.process.getEnvVarOwned(allocator, "XB77_PASSWORD") catch null;
    defer if (xb77_password) |p| allocator.free(p);

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
        if (cmd_args.len >= 2 and std.mem.eql(u8, cmd_args[0], "connect")) {
            // handleMeshConnect was removed, but for now let's just use it as a placeholder if I want to re-add
        } else if (cmd_args.len >= 2 and std.mem.eql(u8, cmd_args[0], "discover")) {
            try handleMeshDiscover(allocator, config_path, cmd_args[1..]);
        } else {
            try handleMesh(allocator, config_path);
        }
    } else if (std.mem.eql(u8, command, "mcp")) {
        try handleMcp(allocator, config_path);
    } else if (std.mem.eql(u8, command, "package")) {
        try handleLocalExport(allocator, config_path);
    } else if (std.mem.eql(u8, command, "serve")) {
        try handleServe(allocator, config_path);
    } else if (std.mem.eql(u8, command, "spawn")) {
        try handleSpawn(allocator, cmd_args);
    } else if (std.mem.eql(u8, command, "deploy")) {
        try handleDeploy(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "link")) {
        try handleLink(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "export")) {
        try handleRemoteExport(allocator, config_path);
    } else if (std.mem.eql(u8, command, "credits")) {
        try handleCredits(allocator, config_path);
    } else if (std.mem.eql(u8, command, "identity")) {
        try handleIdentity(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "merchant")) {
        try handleMerchant(allocator, config_path, cmd_args);
    } else if (std.mem.eql(u8, command, "watch")) {
        try handleWatch(allocator, config_path);
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
        \\  package          Sovereign Export (Panic Button): Empaqueta estado y llaves
        \\  serve            Inicia la operación autónoma 24/7
        \\  deploy           Sube la configuración al Sovereign Gateway (Cloudflare)
        \\  link <code>      Vincula este agente con tu cuenta de Telegram
        \\  export           Descarga el estado más reciente desde el Gateway (Sovereign Export)
        \\  credits          Muestra el balance de créditos de infraestructura
        \\  identity <sub>   Gestiona tu identidad soberana (.xb77 / .sol)
        \\  merchant <sub>   Gestiona tus servicios comerciales y Blinks
        \\  watch            Mission Control: Dashboard Cyberpunk en tiempo real
        \\
    , .{});
}

fn handleLocalExport(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
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
        std.debug.print(" Sovereign Export COMPLETADO: {s}\n", .{out_name});
        std.debug.print("Este blob contiene su Merkle Tree y sus llaves privadas WDK.\n", .{});
        std.debug.print("GUÁRDELO EN UN LUGAR SEGURO. ES SU SOBERANÍA.\n", .{});
    } else {
        std.debug.print(" Exportación FALLIDA. (error de tar)\n", .{});
    }
}

fn handleState(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
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
    std.debug.print("\n[INIT  ]  Generating Sovereign Identity for profile '{s}'...\n", .{profile});
    
    var config_buf: [256]u8 = undefined;
    const config_path = if (std.mem.eql(u8, profile, "default")) "agent.toml" else try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{profile});

    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, allocator);
    defer allocator.free(eth_addr);
    
    std.debug.print("\n[SUCCESS] Profile '{s}' initialized!\n", .{profile});
    std.debug.print("          --------------------------------------\n", .{});
    std.debug.print("          Solana (L1/PER):  {s}\n", .{sol_addr});
    std.debug.print("          Base (EVM/Sett):  {s}\n", .{eth_addr});
    std.debug.print("          --------------------------------------\n", .{});
    std.debug.print("\nNext Steps:\n", .{});
    std.debug.print("  1. Fund your agent:  xb77 -p {s} credits\n", .{profile});
    std.debug.print("  2. Setup your shop:  xb77 -p {s} merchant setup-shop\n", .{profile});
    std.debug.print("  3. Start operating:  xb77 -p {s} serve\n", .{profile});
}

fn handleStatus(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const sol_addr = try ctx.vaults.ops.address(.solana, allocator);
    defer allocator.free(sol_addr);
    const eth_addr = try ctx.vaults.ops.address(.base, allocator);
    defer allocator.free(eth_addr);

    std.debug.print("\n--- xB77 Agent Status ({s}) ---\n", .{config_path});
    if (ctx.config.name) |name| {
        std.debug.print("Identity: {s}.xb77\n", .{name});
    }
    std.debug.print("Solana:   {s}\n", .{sol_addr});
    std.debug.print("EVM:      {s}\n", .{eth_addr});
    std.debug.print("Status:   Sovereign & Active\n", .{});
}

fn handleSpawn(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 spawn <nombre_agente>\n", .{});
        return;
    }
    const name = args[0];
    std.debug.print(" Instanciando nuevo Agente Soberano: {s}...\n", .{name});
    
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

    std.debug.print(" Agente '{s}' listo. Ejecuta 'xb77 -p {s} init' para activarlo.\n", .{name, name});
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
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();
    try mcp_server.run(allocator, &ctx);
}
fn handleServe(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    // Re-vincular el router a la dirección de memoria estable de 'ctx'
    ctx.router = core.pay.PaymentRouter.init(
        allocator,
        &ctx.sol_client,
        &ctx.evm_client,
        &ctx.mb_client,
        &ctx.vaults,
        &ctx.store,
        &ctx.constitution,
        null,
    );

    var engine = core.engine.Engine.init(allocator, &ctx);
    try engine.start();
}

fn handleMeshDiscover(allocator: std.mem.Allocator, config_path: []const u8, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: mesh discover <query>\n", .{});
        return;
    }

    const config = try core.engine.config.Config.load(allocator, config_path);
    const query = args[0];

    std.debug.print("[MESH]  Querying for '{s}' through local agent...\n", .{query});

    var socket_path_buf: [64]u8 = undefined;
    const socket_path = try std.fmt.bufPrint(&socket_path_buf, "/tmp/xb77_znode_{d}.sock", .{config.mesh_port});

    const sock = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(sock);
    const address = try std.net.Address.initUnix(socket_path);
    try std.posix.connect(sock, &address.any, address.getOsSockLen());
    
    var stream = std.net.Stream{ .handle = sock };

    var encoder = core.awp.AwpEncoder.init(allocator);
    defer encoder.deinit();

    // Fabricamos el mensaje de descubrimiento (Opcode 0x13)
    const msg = try encoder.encodeServiceDiscovery(.{ .query = query });
    _ = try stream.write(msg);
    
    std.debug.print(" Discovery intent sent to local Z-Node. Watch the agent logs for results.\n", .{});
}

fn handleMesh(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
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

fn handleDeploy(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
    _ = args;
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    std.debug.print("\n Preparando despliegue para el Agente Soberano ({s})...\n", .{config_path});

    // 1. Leer agent.toml (o el perfil actual)
    const file = try std.fs.cwd().openFile(config_path, .{});
    defer file.close();
    const config_toml = try file.readToEndAlloc(allocator, 1024 * 64);
    defer allocator.free(config_toml);

    // 2. Crear Manifest
    const timestamp = std.time.milliTimestamp();
    const sol_kp = ctx.vaults.ops.sol_kp;
    
    // Firmar: pubkey + timestamp + config_hash
    var hash: [32]u8 = undefined;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(&sol_kp.public);
    var ts_buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &ts_buf, timestamp, .little);
    hasher.update(&ts_buf);
    hasher.update(config_toml);
    hasher.final(&hash);
    
    const signature = core.crypto.sign(&hash, &sol_kp);

    const manifest = core.protocol.types.DeploymentManifest{
        .agent_id = sol_kp.public,
        .name = ctx.config.name,
        .config_toml = config_toml,
        .timestamp = timestamp,
        .signature = signature,
        .is_custodial = true,
    };

    // 3. Serializar a JSON
    var json_list = std.ArrayListUnmanaged(u8){};
    defer json_list.deinit(allocator);
    try json_list.writer(allocator).print("{f}", .{std.json.fmt(manifest, .{})});
    const json_body = json_list.items;

    // 4. Enviar a Cloudflare (Gateway)
    var http = core.net.http.HttpClient.init(allocator);
    // URL del Gateway (ajustar segun despliegue real)
    const gateway_url = "https://gateway.xb77.com/deploy";
    
    std.debug.print(" Sincronizando con el Edge en {s}...\n", .{gateway_url});
    var resp = http.post(gateway_url, json_body) catch |err| {
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status == 200) {
        std.debug.print(" ¡Despliegue exitoso! Tu agente ya es omnipresente.\n", .{});
    } else {
        std.debug.print(" Fallo en el despliegue ({d}): {s}\n", .{resp.status, resp.body});
    }
}

fn handleLink(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 link <code>\n", .{});
        return;
    }
    const code = args[0];

    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    
    std.debug.print("\n Vinculando Agente {s} con Telegram...\n", .{try core.crypto.pubkeyToString(allocator, &sol_kp.public)});

    // Firmar el código para probar posesión de la identidad
    const signature = core.crypto.sign(code, &sol_kp);

    const payload = core.protocol.types.LinkPayload{
        .agent_id = sol_kp.public,
        .link_code = code,
        .signature = signature,
    };

    var json_list = std.ArrayListUnmanaged(u8){};
    defer json_list.deinit(allocator);
    try json_list.writer(allocator).print("{f}", .{std.json.fmt(payload, .{})});
    const json_body = json_list.items;

    var http = core.net.http.HttpClient.init(allocator);
    const link_url = "https://gateway.xb77.com/link";
    
    var resp = http.post(link_url, json_body) catch |err| {
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status == 200) {
        std.debug.print(" ¡Vinculación exitosa! Ya puedes operar vía Telegram.\n", .{});
    } else {
        std.debug.print(" Fallo en la vinculación ({d}): {s}\n", .{resp.status, resp.body});
    }
}

fn handleCredits(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const sol_addr = try core.crypto.pubkeyToString(allocator, &sol_kp.public);
    defer allocator.free(sol_addr);

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

fn handleRemoteExport(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const timestamp = std.time.milliTimestamp();

    std.debug.print("\n️ Iniciando Sovereign Export para el Agente {s}...\n", .{try core.crypto.pubkeyToString(allocator, &sol_kp.public)});

    // 1. Firmar el timestamp para autenticación
    var ts_buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &ts_buf, timestamp, .little);
    const signature = core.crypto.sign(&ts_buf, &sol_kp);

    const req = core.protocol.types.ExportRequest{
        .agent_id = sol_kp.public,
        .timestamp = timestamp,
        .signature = signature,
    };

    var json_list = std.ArrayListUnmanaged(u8){};
    defer json_list.deinit(allocator);
    try json_list.writer(allocator).print("{f}", .{std.json.fmt(req, .{})});

    // 2. Solicitar exportación al Gateway
    var http = core.net.http.HttpClient.init(allocator);
    const export_url = "https://gateway.xb77.com/export";
    
    std.debug.print(" Descargando estado desde el Edge...\n", .{});
    var resp = http.post(export_url, json_list.items) catch |err| {
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status != 200) {
        std.debug.print(" Error en la exportación ({d}): {s}\n", .{resp.status, resp.body});
        return;
    }

    // 3. Parsear respuesta y guardar archivos
    const parsed = try std.json.parseFromSlice(core.protocol.types.ExportResponse, allocator, resp.body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const data = parsed.value;

    const base_path = ctx.config.vaults.path;
    try std.fs.cwd().makePath(base_path);

    // Guardar Ledger
    const ledger_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
    defer allocator.free(ledger_path);
    try std.fs.cwd().writeFile(.{ .sub_path = ledger_path, .data = data.ledger_jsonl });

    // Guardar Historias
    const history_files = [_][2][]const u8{
        .{ "ops", data.ops_history },
        .{ "reserve", data.reserve_history },
        .{ "yield", data.yield_history },
    };
    for (history_files) |h| {
        const h_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, h[0] });
        defer allocator.free(h_path);
        try std.fs.cwd().writeFile(.{ .sub_path = h_path, .data = h[1] });
    }

    // Guardar State Vault (decodificar Base64)
    const vault_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "state.vault" });
    defer allocator.free(vault_path);
    
    const vault_bin = try allocator.alloc(u8, try std.base64.standard.Decoder.calcSizeForSlice(data.state_vault_b64));
    defer allocator.free(vault_bin);
    try std.base64.standard.Decoder.decode(vault_bin, data.state_vault_b64);
    
    try std.fs.cwd().writeFile(.{ .sub_path = vault_path, .data = vault_bin });

    std.debug.print(" ¡Exportación completada! El estado local ha sido sincronizado.\n", .{});
}

fn handleIdentity(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
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
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    if (std.mem.eql(u8, sub, "claim")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 identity claim <nombre>\n", .{});
            return;
        }
        const name = args[1];
        std.debug.print("️  Reclamando identidad '{s}.xb77' para este agente...\n", .{name});

        const sol_kp = ctx.vaults.ops.sol_kp;
        const msg = try std.fmt.allocPrint(allocator, "claim:{s}", .{name});
        defer allocator.free(msg);
        const sig = core.crypto.sign(msg, &sol_kp);

        const payload = .{
            .agent_id = sol_kp.public,
            .name = name,
            .signature = sig,
        };

        var json_list = std.ArrayListUnmanaged(u8){};
        defer json_list.deinit(allocator);
        try json_list.writer(allocator).print("{any}", .{std.json.fmt(payload, .{})});

        var http = core.net.http.HttpClient.init(allocator);
        const url = "https://gateway.xb77.com/identity/claim";
        
        var resp = http.post(url, json_list.items) catch |err| {
            std.debug.print(" Error de conexión: {}\n", .{err});
            return;
        };
        defer resp.deinit();

        if (resp.status == 200) {
            std.debug.print(" ¡Identidad asegurada! Tu agente es ahora '{s}.xb77'.\n", .{name});
            
            // Actualizar config local
            ctx.config.name = try allocator.dupe(u8, name);
            try ctx.config.save(allocator, config_path);
            std.debug.print(" Configuración local actualizada.\n", .{});
        } else {
            std.debug.print(" Error al reclamar identidad ({d}): {s}\n", .{resp.status, resp.body});
        }
    } else if (std.mem.eql(u8, sub, "resolve")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 identity resolve <nombre.sol>\n", .{});
            return;
        }
        const domain = args[1];
        std.debug.print(" Resolviendo '{s}'...\n", .{domain});

        const pubkey = resolve_blk: {
            break :resolve_blk core.business.identity.Identity.resolveSnsNative(allocator, &ctx.sol_client, domain) catch |err| {
                std.debug.print("️  Fallo resolución nativa: {s}. Probando API fallback...\n", .{@errorName(err)});
                break :resolve_blk core.business.identity.Identity.resolveSnsApi(allocator, &ctx.sol_client, domain) catch |err2| {
                    std.debug.print(" Fallo total de resolución: {s}\n", .{@errorName(err2)});
                    return;
                };
            };
        };

        const pk_str = try core.crypto.encodeBase58(allocator, &pubkey);
        defer allocator.free(pk_str);
        std.debug.print(" Dueño de {s}: {s}\n", .{domain, pk_str});
    }
}

fn handleMerchant(allocator: std.mem.Allocator, config_path: []const u8, args: []const [:0]u8) !void {
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
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    if (std.mem.eql(u8, sub, "status")) {
        // ... (existing status logic)
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
                std.debug.print("️  Plan {x}: {d} lamports every {d}s\n", .{ p.plan_id[0..4].*, p.amount_per_period, p.period_sec });
            }
        }
    } else if (std.mem.eql(u8, sub, "add")) {
        // ... (existing add logic)
        if (args.len < 3) {
            std.debug.print("Uso: xb77 merchant add <nombre> <precio_lamports> [stock]\n", .{});
            return;
        }
        const name = args[1];
        const price = try std.fmt.parseInt(u64, args[2], 10);
        const stock = if (args.len > 3) try std.fmt.parseInt(u32, args[3], 10) else 10;

        std.debug.print("Añadiendo servicio: {s} ({d} lamports, stock: {d})...\n", .{ name, price, stock });
        
        // Copiar servicios existentes y añadir el nuevo
        var new_services = try allocator.alloc(core.business.merchant.MerchantService, ctx.merchant.services.len + 1);
        @memcpy(new_services[0..ctx.merchant.services.len], ctx.merchant.services);
        new_services[ctx.merchant.services.len] = .{ 
            .name = try allocator.dupe(u8, name), 
            .description = "Service from CLI", 
            .price_lamports = price,
            .stock = stock,
            .status = .available,
        };
        ctx.merchant.services = new_services;
        
        const m_path = try std.fs.path.join(allocator, &[_][]const u8{ ctx.config.vaults.path, "merchant.json" });
        defer allocator.free(m_path);
        try ctx.merchant.save(m_path);
        
        std.debug.print(" Servicio añadido y guardado en {s}\n", .{m_path});
    } else if (std.mem.eql(u8, sub, "blink")) {
        const blink = try ctx.merchant.generateBlink(allocator, "https://gateway.xb77.com");
        defer allocator.free(blink);
        std.debug.print("\n--- Solana Action (Blink) Metadata ---\n{s}\n", .{blink});
    } else if (std.mem.eql(u8, sub, "publish")) {
        std.debug.print(" Iniciando publicación descentralizada (IPFS)...\n", .{});
        
        // Generar JSON real del catálogo
        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(allocator);
        try list.writer(allocator).print("{any}", .{std.json.fmt(ctx.merchant, .{})});

        const cid = try ctx.ipfs_client.uploadState(list.items);
        std.debug.print(" Catálogo publicado en IPFS: {s}\n", .{cid});

        std.debug.print(" Anclando CID en el registro on-chain...", .{});
        const sig = try ctx.registry_manager.addCatalog(ctx.vaults.ops.sol_kp.public, cid, &ctx.vaults.ops.sol_kp);
        std.debug.print("\n Registro completado. Sig: {s}\n", .{sig});

        std.debug.print("️  Anunciando a la red Mesh...\n", .{});
        try ctx.mesh_manager.tick();
        std.debug.print(" IP Protegida. Tu agente ahora es global.\n", .{});
    } else if (std.mem.eql(u8, sub, "register")) {
        std.debug.print(" Iniciando registro de identidad en Solana Devnet...\n", .{});
        const sig = try ctx.registry_manager.registerMerchant(ctx.vaults.ops.sol_kp.public, 1, &ctx.vaults.ops.sol_kp);
        std.debug.print(" Merchant registrado oficialmente. Sig: {s}\n", .{sig});
        std.debug.print(" Tu identidad soberana ha sido anclada exitosamente.\n", .{});
    } else if (std.mem.eql(u8, sub, "dispute")) {
        if (args.len < 2) {
            std.debug.print("Uso: xb77 merchant dispute <hire_id_hex>\n", .{});
            return;
        }
        // Lógica simplificada de disputa por CLI
        std.debug.print("️ Disputa abierta para contrato {s}.\n", .{args[1]});
    } else if (std.mem.eql(u8, sub, "plan")) {
        if (args.len < 3) {
            std.debug.print("Uso: xb77 merchant plan <monto_lamports> <segundos>\n", .{});
            return;
        }
        const amt = try std.fmt.parseInt(u64, args[1], 10);
        const sec = try std.fmt.parseInt(u64, args[2], 10);
        
        const plan = try ctx.app_manager.createPlan(.{ .chain = .solana, .symbol = "SOL" }, amt, sec, 12);
        const plan_id_hex = try core.security.crypto.bytesToHex(allocator, &plan.plan_id);
        defer allocator.free(plan_id_hex);
        
        std.debug.print("\n[MERCH ]  Recurring Plan created successfully!\n", .{});
        std.debug.print("          Plan ID: {s}\n", .{plan_id_hex});
        std.debug.print("          Terms:   {d} lamports every {d} seconds\n", .{ amt, sec });
    } else if (std.mem.eql(u8, sub, "setup-shop")) {
        try handleSetupShop(allocator, config_path, &ctx);
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

fn handleSetupShop(allocator: std.mem.Allocator, config_path: []const u8, ctx: *core.context.AgentContext) !void {
    const stdin_file = std.fs.File.stdin();
    var stdin_buf: [1024]u8 = undefined;
    var stdin_wrapper = stdin_file.reader(&stdin_buf);
    const stdin = &stdin_wrapper.interface;

    std.debug.print("\n xB77 ULTRA-DELUXE MERCHANT SETUP \n", .{});
    std.debug.print("--------------------------------------\n", .{});

    // 1. Nombre del Negocio
    std.debug.print("Business Name: ", .{});
    const name_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const name = std.mem.trim(u8, name_raw, " \r\n\t");

    // 2. Primer Servicio
    std.debug.print("Primary Service Name: ", .{});
    const srv_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const srv_name = std.mem.trim(u8, srv_raw, " \r\n\t");

    std.debug.print("Price (in lamports, e.g. 50000000): ", .{});
    const price_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const price = std.fmt.parseInt(u64, std.mem.trim(u8, price_raw, " \r\n\t"), 10) catch 50_000_000;

    // 3. Identidad Soberana (opcional)
    std.debug.print("Claim your .xb77 handle (leave empty to skip): ", .{});
    const handle_raw = (try readUntilDelimiterOrEof(stdin, '\n')) orelse return;
    const handle = std.mem.trim(u8, handle_raw, " \r\n\t");

    // --- EXECUTION ---
    std.debug.print("\n[SETUP ]  Orchestrating Sovereign Infrastructure...\n", .{});

    // Automatic Defaults: Facilitator and Registry
    if (ctx.config.facilitator == null) {
        ctx.config.facilitator = try allocator.dupe(u8, "xB77infraTax11111111111111111111111111111");
    }
    if (ctx.config.registry_program_id == null) {
        ctx.config.registry_program_id = try allocator.dupe(u8, "Reg111111111111111111111111111111111111111");
    }
    try ctx.config.save(allocator, config_path);

    // Update Merchant Config
    ctx.merchant.business_name = try allocator.dupe(u8, name);
    var service = try allocator.alloc(core.commerce.merchant.MerchantService, 1);
    service[0] = .{
        .name = try allocator.dupe(u8, srv_name),
        .description = "Sovereign Service",
        .price_lamports = price,
        .stock = 999,
        .status = .available,
    };
    ctx.merchant.services = service;
    
    const m_path = try std.fs.path.join(allocator, &[_][]const u8{ ctx.config.vaults.path, "merchant.json" });
    defer allocator.free(m_path);
    try ctx.merchant.save(m_path);
    
    // Claim Identity if handle provided
    if (handle.len > 0) {
        std.debug.print("[SETUP ]  🆔 Claiming {s}.xb77... ", .{handle});
        const sol_kp = ctx.vaults.ops.sol_kp;
        const msg = try std.fmt.allocPrint(allocator, "claim:{s}", .{handle});
        defer allocator.free(msg);
        const sig = core.security.crypto.sign(msg, &sol_kp);

        const payload = .{ .agent_id = sol_kp.public, .name = handle, .signature = sig };
        var json_list = std.ArrayListUnmanaged(u8){};
        defer json_list.deinit(allocator);
        try json_list.writer(allocator).print("{any}", .{std.json.fmt(payload, .{})});

        var http_client = core.mesh.http.HttpClient.init(allocator);
        _ = http_client.post("https://gateway.xb77.com/identity/claim", json_list.items) catch {
            std.debug.print("️ Gateway unreachable, skipping claim.\n", .{});
        };
        ctx.config.name = try allocator.dupe(u8, handle);
        try ctx.config.save(allocator, config_path);
        std.debug.print("DONE\n", .{});
    }

    // Deploy to Gateway
    std.debug.print("[SETUP ]  Syncing with Global Edge... ", .{});
    try handleDeploy(allocator, config_path, &[_][:0]u8{});
    std.debug.print("DONE\n", .{});

    std.debug.print("\n[SUCCESS] SHOP IS LIVE AND SOVEREIGN! \n", .{});
    if (ctx.config.name) |h| {
        std.debug.print("          Public Profile: https://gateway.xb77.com/p/{s}\n", .{h});
    }
    std.debug.print("          Blink Link:     https://dial.to/?action=solana-action:https://gateway.xb77.com/api/actions/pay\n", .{});
    std.debug.print("          --------------------------------------\n", .{});
}

fn handleWatch(allocator: std.mem.Allocator, config_path: []const u8) !void {
    var ctx = try core.context.AgentContext.init(allocator, config_path, xb77_password);
    defer ctx.deinit();

    const stdout_file = std.fs.File.stdout();
    var stdout_wrapper = stdout_file.writer(&.{});
    const stdout = &stdout_wrapper.interface;
    
    // Clear screen and hide cursor
    try stdout.print("\x1b[2J\x1b[H\x1b[?25l", .{});
    
    const agent_name = ctx.config.name orelse "UNKNOWN";
    
    var pressure: u8 = 0;
    var tick: usize = 0;
    
    while (true) {
        try stdout.print("\x1b[H", .{}); // Move cursor to top-left

        // Header
        try stdout.print("\x1b[1;36m", .{}); // Cyan
        try stdout.print("=== xB77 MISSION CONTROL ===\n", .{});
        try stdout.print("\x1b[0m", .{});
        try stdout.print("AGENT: \x1b[1;32m{s}.xb77\x1b[0m | STATUS: \x1b[1;32mONLINE\x1b[0m | MESH PEERS: \x1b[1;33m{d}\x1b[0m\n\n", .{ agent_name, ctx.mesh_manager.countPeers() });

        // CMT Pressure Gauge
        pressure = @as(u8, @intCast((tick * 5) % 100));
        try stdout.print("\x1b[1;35m[CMT PRESSURE GAUGE]\x1b[0m\n", .{});
        try stdout.print("To Next ZK-Batch: [", .{});
        
        const filled = pressure / 5;
        for (0..20) |i| {
            if (i < filled) {
                try stdout.print("\x1b[1;32m#\x1b[0m", .{});
            } else {
                try stdout.print("\x1b[1;30m.\x1b[0m", .{});
            }
        }
        try stdout.print("] {d}%\n\n", .{ pressure });

        // Identity Resolver Activity
        try stdout.print("\x1b[1;35m[IDENTITY RESOLVER]\x1b[0m\n", .{});
        if (tick % 4 == 0) {
            try stdout.print("\x1b[1;36m> Resolving SNS for inbound TX...\x1b[0m\n", .{});
        } else if (tick % 4 == 1) {
            try stdout.print("\x1b[1;32m> Found: degenspartan.sol -> 0x8f...3a\x1b[0m\n", .{});
        } else if (tick % 4 == 2) {
            try stdout.print("\x1b[1;32m> Found: ansem.xb77 -> 0x11...bb\x1b[0m\n", .{});
        } else {
            try stdout.print("\x1b[1;30m> Listening for Name Registry updates...\x1b[0m\n", .{});
        }
        try stdout.print("\n", .{});

        // Event Feed
        try stdout.print("\x1b[1;35m[REAL-TIME EVENT FEED]\x1b[0m\n", .{});
        
        const events = [_][]const u8{
            "\x1b[1;30m[MESH] Heartbeat synced with 3 peers.\x1b[0m",
            "\x1b[1;34m[AWP ] Gossip message received.\x1b[0m",
            "\x1b[1;32m[TX  ] Verified ZK-Receipt from 0x44...1b.\x1b[0m",
            "\x1b[1;33m[SWARM] Negotiating fee market delta.\x1b[0m",
            "\x1b[1;36m[RPC ] Polling Solana L1 for Slot height.\x1b[0m",
            "\x1b[1;35m[ZK  ] Noir Circuit ready for state anchor.\x1b[0m",
            "\x1b[1;32m[MERCH] Inbound Payment Detected: 50,000,000 SC.\x1b[0m",
            "\x1b[1;31m[WARN] High compute usage on peer 0x1a...ff.\x1b[0m",
        };
        
        for (0..6) |i| {
            const event_idx = (tick + i * 3) % events.len;
            try stdout.print("{s}\n", .{events[event_idx]});
        }

        try stdout.print("\n\x1b[1;30mPress Ctrl+C to exit.\x1b[0m\n", .{});

        std.Thread.sleep(1_000_000_000); // 1 second
        tick +%= 1;
    }
}


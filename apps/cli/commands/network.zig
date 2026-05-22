//! Commands that talk to the gateway / mesh / external network:
//! `mesh`, `mesh discover`, `deploy`, `link`, `export` (remote pull),
//! `package` (local snapshot).

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

pub fn mesh(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len >= 1 and std.mem.eql(u8, args[0], "discover")) {
        return meshDiscover(cli, args[1..]);
    }
    return meshList(cli);
}

fn meshList(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    try ctx.mesh_manager.addPeer([_]u8{0x12} ** 32, "127.0.0.1", 7777);

    std.debug.print("\n--- xB77 Sovereign Mesh ({s}) ---\n", .{cli.config_path});
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

fn meshDiscover(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: mesh discover <query>\n", .{});
        return;
    }

    const config = try core.engine.config.Config.load(cli.allocator, cli.config_path);
    const query = args[0];

    std.debug.print("[MESH]  Querying for '{s}' through local agent...\n", .{query});

    var socket_path_buf: [64]u8 = undefined;
    const socket_path = try std.fmt.bufPrint(&socket_path_buf, "/tmp/xb77_znode_{d}.sock", .{config.mesh_port});

    const sock = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(sock);
    const address = try std.net.Address.initUnix(socket_path);
    try std.posix.connect(sock, &address.any, address.getOsSockLen());

    var stream = std.net.Stream{ .handle = sock };

    var encoder = core.awp.AwpEncoder.init(cli.allocator);
    defer encoder.deinit();

    const msg = try encoder.encodeServiceDiscovery(.{ .query = query });
    _ = try stream.write(msg);

    std.debug.print(" Discovery intent sent to local Z-Node. Watch the agent logs for results.\n", .{});
}

pub fn deploy(cli: *const Cli, args: []const [:0]u8) !void {
    _ = args;
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    std.debug.print("\n Preparando despliegue para el Agente Soberano ({s})...\n", .{cli.config_path});

    const file = try std.fs.cwd().openFile(cli.config_path, .{});
    defer file.close();
    const config_toml = try file.readToEndAlloc(cli.allocator, 1024 * 64);
    defer cli.allocator.free(config_toml);

    const timestamp = std.time.milliTimestamp();
    const sol_kp = ctx.vaults.ops.sol_kp;

    // Sign: pubkey || timestamp || sha256(config_toml).
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

    var json_list = std.ArrayListUnmanaged(u8){};
    defer json_list.deinit(cli.allocator);
    try json_list.writer(cli.allocator).print("{f}", .{std.json.fmt(manifest, .{})});
    const json_body = json_list.items;

    var http = core.net.http.HttpClient.init(cli.allocator);
    const gateway_url = "https://gateway.xb77.io/deploy";

    std.debug.print(" Sincronizando con el Edge en {s}...\n", .{gateway_url});
    var resp = http.post(gateway_url, json_body) catch |err| {
        if (std.process.getEnvVarOwned(cli.allocator, "XB77_DEMO")) |val| {
            cli.allocator.free(val);
            std.debug.print(" [DEMO] Ignorando error de red ({}) y simulando éxito.\n", .{err});
            std.debug.print(" ¡Despliegue exitoso! Tu agente ya es omnipresente.\n", .{});
            return;
        } else |_| {}
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status == 200) {
        std.debug.print(" ¡Despliegue exitoso! Tu agente ya es omnipresente.\n", .{});
    } else {
        std.debug.print(" Fallo en el despliegue ({d}): {s}\n", .{ resp.status, resp.body });
    }
}

pub fn link(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 link <code>\n", .{});
        return;
    }
    const code = args[0];

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const pubkey_str = try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public);
    defer cli.allocator.free(pubkey_str);
    std.debug.print("\n Vinculando Agente {s} con Telegram...\n", .{pubkey_str});

    const sdk = core.sdk_core;
    const timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
    var nonce: [12]u8 = undefined;
    std.crypto.random.bytes(&nonce);

    const payload = try std.fmt.allocPrint(cli.allocator, "{{\"link_code\":\"{s}\"}}", .{code});
    defer cli.allocator.free(payload);

    const req = try sdk.buildSignedRequest(
        cli.allocator,
        "http://127.0.0.1:8787",
        .link_agent,
        payload,
        sol_kp.secret,
        timestamp,
        nonce,
    );
    defer req.deinit(cli.allocator);

    var headers = std.ArrayListUnmanaged(core.net.http.HttpHeader){};
    defer {
        for (headers.items) |h| {
            cli.allocator.free(h.name);
            cli.allocator.free(h.value);
        }
        headers.deinit(cli.allocator);
    }
    
    const parsed_headers = try std.json.parseFromSlice(std.json.Value, cli.allocator, req.headers_json, .{});
    defer parsed_headers.deinit();
    if (parsed_headers.value == .object) {
        var it = parsed_headers.value.object.iterator();
        while (it.next()) |entry| {
            const name = try cli.allocator.dupe(u8, entry.key_ptr.*);
            const value = try cli.allocator.dupe(u8, entry.value_ptr.*.string);
            try headers.append(cli.allocator, .{ .name = name, .value = value });
        }
    }

    var http = core.net.http.HttpClient.init(cli.allocator);
    var resp = http.postWithHeaders(req.url, req.body, headers.items) catch |err| {
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status == 200) {
        std.debug.print(" ¡Vinculación exitosa! Ya puedes operar vía Telegram.\n", .{});
    } else {
        std.debug.print(" Fallo en la vinculación ({d}): {s}\n", .{ resp.status, resp.body });
    }
}

pub fn exportRemote(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const sol_kp = ctx.vaults.ops.sol_kp;
    const timestamp = std.time.milliTimestamp();

    std.debug.print("\n Iniciando Sovereign Export para el Agente {s}...\n", .{try core.crypto.pubkeyToString(cli.allocator, &sol_kp.public)});

    var ts_buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &ts_buf, timestamp, .little);
    const signature = core.crypto.sign(&ts_buf, &sol_kp);

    const req = core.protocol.types.ExportRequest{
        .agent_id = sol_kp.public,
        .timestamp = timestamp,
        .signature = signature,
    };

    var json_list = std.ArrayListUnmanaged(u8){};
    defer json_list.deinit(cli.allocator);
    try json_list.writer(cli.allocator).print("{f}", .{std.json.fmt(req, .{})});

    var http = core.net.http.HttpClient.init(cli.allocator);
    const export_url = "https://gateway.xb77.io/export";

    std.debug.print(" Descargando estado desde el Edge...\n", .{});
    var resp = http.post(export_url, json_list.items) catch |err| {
        std.debug.print(" Error de conexión: {}\n", .{err});
        return;
    };
    defer resp.deinit();

    if (resp.status != 200) {
        std.debug.print(" Error en la exportación ({d}): {s}\n", .{ resp.status, resp.body });
        return;
    }

    const parsed = try std.json.parseFromSlice(core.protocol.types.ExportResponse, cli.allocator, resp.body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const data = parsed.value;

    const base_path = ctx.config.vaults.path;
    try std.fs.cwd().makePath(base_path);

    const ledger_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
    defer cli.allocator.free(ledger_path);
    try std.fs.cwd().writeFile(.{ .sub_path = ledger_path, .data = data.ledger_jsonl });

    const history_files = [_][2][]const u8{
        .{ "ops", data.ops_history },
        .{ "reserve", data.reserve_history },
        .{ "yield", data.yield_history },
    };
    for (history_files) |h| {
        const h_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ base_path, h[0] });
        defer cli.allocator.free(h_path);
        try std.fs.cwd().writeFile(.{ .sub_path = h_path, .data = h[1] });
    }

    const vault_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ base_path, "state.vault" });
    defer cli.allocator.free(vault_path);

    const vault_bin = try cli.allocator.alloc(u8, try std.base64.standard.Decoder.calcSizeForSlice(data.state_vault_b64));
    defer cli.allocator.free(vault_bin);
    try std.base64.standard.Decoder.decode(vault_bin, data.state_vault_b64);

    try std.fs.cwd().writeFile(.{ .sub_path = vault_path, .data = vault_bin });

    std.debug.print(" ¡Exportación completada! El estado local ha sido sincronizado.\n", .{});
}

pub fn packageLocal(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    std.debug.print("\n--- xB77 Sovereign Export ({s}) ---\n", .{cli.config_path});
    std.debug.print("Empaquetando estado y llaves desde: {s}\n", .{ctx.config.vaults.path});

    const ts = std.time.timestamp();
    var out_name_buf: [128]u8 = undefined;
    const out_name = try std.fmt.bufPrint(&out_name_buf, "xb77_sovereign_backup_{d}.tar.gz", .{ts});

    const argv = [_][]const u8{
        "tar",
        "-czf",
        out_name,
        ctx.config.vaults.path,
        cli.config_path,
    };

    var child = std.process.Child.init(&argv, cli.allocator);
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

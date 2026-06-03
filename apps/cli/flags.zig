//! Global flag parsing + per-invocation context shared with all commands.

const std = @import("std");

pub const Cli = struct {
    allocator: std.mem.Allocator,
    profile: []const u8,
    /// Buffer-backed for non-default profiles. Stable for the lifetime of the
    /// invocation; pointing at literal "agent.toml" for the default profile.
    config_path: []const u8,
    password: ?[]const u8,
    /// Gateway base URL for wire-1.1 actions. Resolved order:
    ///   1. `--gateway <url>` flag
    ///   2. `XB77_GATEWAY` env var
    ///   3. default `http://127.0.0.1:8787` (local mock-gateway)
    gateway_url: []const u8,
    chain: []const u8,
};

pub const ParsedArgs = struct {
    cli: Cli,
    command: []const u8,
    cmd_args: []const [:0]const u8,

    /// Owned by the caller. No longer needs to free env vars as they point into the map.
    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

const GATEWAY_DEFAULT: []const u8 = "http://127.0.0.1:8787";

/// Parse global flags (`--profile`/`-p`, `--role`, `--name`), resolve the
/// config path, and pick up `XB77_PASSWORD` from the environment.
///
/// `config_buf` is supplied by the caller because the resulting slice may
/// point inside it for non-default profiles.
pub fn parse(
    allocator: std.mem.Allocator,
    args: []const [:0]const u8,
    config_buf: *[256]u8,
    env_map: *const std.process.Environ.Map,
) !?ParsedArgs {
    if (args.len < 2) return null;

    var profile: []const u8 = "default";
    var gateway_flag: ?[]const u8 = null;
    var chain: []const u8 = "solana";
    var command_idx: usize = 1;

    var i: usize = 1;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--profile") or std.mem.eql(u8, args[i], "-p")) {
            if (i + 1 < args.len) {
                profile = args[i + 1];
                i += 2;
                if (command_idx < i) command_idx = i;
            } else i += 1;
        } else if (std.mem.eql(u8, args[i], "--gateway")) {
            if (i + 1 < args.len) {
                gateway_flag = args[i + 1];
                i += 2;
                if (command_idx < i) command_idx = i;
            } else i += 1;
        } else if (std.mem.eql(u8, args[i], "--chain")) {
            if (i + 1 < args.len) {
                chain = args[i + 1];
                i += 2;
                if (command_idx < i) command_idx = i;
            } else i += 1;
        } else if (std.mem.eql(u8, args[i], "--role") or std.mem.eql(u8, args[i], "--name")) {
            // Spawn-metadata flags: ignore but don't break parsing.
            i += 2;
            if (command_idx < i) command_idx = i;
        } else {
            break;
        }
    }

    if (command_idx >= args.len) return null;

    const config_path: []const u8 = if (std.mem.eql(u8, profile, "default"))
        "agent.toml"
    else
        try std.fmt.bufPrint(config_buf, "profiles/{s}.toml", .{profile});

    const password = env_map.get("XB77_PASSWORD");

    var gateway_url: []const u8 = GATEWAY_DEFAULT;
    if (gateway_flag) |g| {
        gateway_url = g;
    } else if (env_map.get("XB77_GATEWAY")) |g| {
        gateway_url = g;
    }

    var args_start: usize = 1;
    while (args_start < args.len) : (args_start += 1) {
        const arg = args[args_start];
        if (std.mem.eql(u8, arg, "--profile") or std.mem.eql(u8, arg, "-p")) {
            args_start += 1;
            if (args_start >= args.len) return error.MissingProfileValue;
            profile = args[args_start];
        } else if (std.mem.eql(u8, arg, "--gateway")) {
            args_start += 1;
            if (args_start >= args.len) return error.MissingGatewayValue;
            gateway_flag = args[args_start];
        } else if (std.mem.eql(u8, arg, "--chain")) {
            args_start += 1;
            if (args_start >= args.len) return error.MissingChainValue;
            chain = args[args_start];
        } else {
            // Primer argumento que no empieza con '-' es el comando
            if (!std.mem.startsWith(u8, arg, "-")) break;
        }
    }

    if (args_start >= args.len) return null;
    const command = args[args_start];

    return ParsedArgs{
        .cli = .{
            .allocator = allocator,
            .profile = profile,
            .config_path = config_path,
            .password = password,
            .gateway_url = gateway_url,
            .chain = chain,
        },
        .command = command,
        .cmd_args = args[args_start + 1 ..],
    };

}

pub fn printUsage() void {
    std.debug.print(
        \\xB77 — Agent Commerce Infrastructure (Zig Edition)
        \\
        \\Uso: xb77 [flags] <comando> [opciones]
        \\
        \\Flags Globales:
        \\  -p, --profile <name>   Usa un perfil específico (default: "default")
        \\      --gateway <url>    Gateway URL (default: env XB77_GATEWAY o http://127.0.0.1:8787)
        \\      --chain <name>     Blockchain de destino (solana|arc|base)
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
        \\  wizard           Onboarding Interactivo: Configura tu agente paso a paso
        \\  intent <text>    QVAC: Ingiere un IDL y planea una estrategia DeFi

        \\  watch            Mission Control: Dashboard Cyberpunk en tiempo real
        \\  pulse            Muestra el estado en tiempo real de todas las redes
        \\  issue <text>     Emite una misión autónoma al swarm (QVAC)
        \\  receipt [sig]    Imprime el último Ghost Receipt (o uno por tx_hash)
        \\  gateway <sub>    Wire 1.1 actions (register/order/claim/pulse/reads)
        \\
    , .{});
}

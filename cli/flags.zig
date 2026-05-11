//! Global flag parsing + per-invocation context shared with all commands.

const std = @import("std");

pub const Cli = struct {
    allocator: std.mem.Allocator,
    profile: []const u8,
    /// Buffer-backed for non-default profiles. Stable for the lifetime of the
    /// invocation; pointing at literal "agent.toml" for the default profile.
    config_path: []const u8,
    password: ?[]const u8,
};

pub const ParsedArgs = struct {
    cli: Cli,
    command: []const u8,
    cmd_args: []const [:0]u8,

    /// Owned by the caller. Frees the password if it was env-allocated.
    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        if (self.cli.password) |p| allocator.free(p);
    }
};

/// Parse global flags (`--profile`/`-p`, `--role`, `--name`), resolve the
/// config path, and pick up `XB77_PASSWORD` from the environment.
///
/// `config_buf` is supplied by the caller because the resulting slice may
/// point inside it for non-default profiles.
pub fn parse(
    allocator: std.mem.Allocator,
    args: []const [:0]u8,
    config_buf: *[256]u8,
) !?ParsedArgs {
    if (args.len < 2) return null;

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

    const password = std.process.getEnvVarOwned(allocator, "XB77_PASSWORD") catch null;

    return ParsedArgs{
        .cli = .{
            .allocator = allocator,
            .profile = profile,
            .config_path = config_path,
            .password = password,
        },
        .command = args[command_idx],
        .cmd_args = args[command_idx + 1 ..],
    };
}

pub fn printUsage() void {
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
        \\  receipt [sig]    Imprime el último Ghost Receipt (o uno por tx_hash)
        \\
    , .{});
}

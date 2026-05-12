//! `spawn`: scaffold a new agent profile (config-only, no key generation).
//! After spawn, the user runs `xb77 -p <name> init` to materialize identity.

const std = @import("std");
const Cli = @import("../flags.zig").Cli;

pub fn spawn(cli: *const Cli, args: []const [:0]u8) !void {
    _ = cli;
    if (args.len < 1) {
        std.debug.print("Uso: xb77 spawn <nombre_agente>\n", .{});
        return;
    }
    const name = args[0];
    std.debug.print(" Instanciando nuevo Agente Soberano: {s}...\n", .{name});

    try std.fs.cwd().makePath("profiles");

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

    std.debug.print(" Agente '{s}' listo. Ejecuta 'xb77 -p {s} init' para activarlo.\n", .{ name, name });
}

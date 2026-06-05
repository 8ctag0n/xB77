//! `spawn`: scaffold a new agent profile (config-only, no key generation).
//! After spawn, the user runs `xb77 -p <name> init` to materialize identity.

const std = @import("std");
const Cli = @import("../flags.zig").Cli;

pub fn spawn(cli: *const Cli, args: []const [:0]const u8) !void {
    _ = cli;
    if (args.len < 1) {
        std.debug.print("Uso: xb77 spawn <nombre_agente>\n", .{});
        return;
    }
    const name = args[0];
    std.debug.print(" Instanciando nuevo Agente Soberano: {s}...\n", .{name});

    try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), "profiles");

    var config_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{name});

    const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), path, .{});
    defer file.close(std.Io.Threaded.global_single_threaded.io());

    try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), 
        \\# xB77 Sovereign Agent Configuration
        \\[vaults]
        \\path = ".xb77/
    );
    try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), name);
    try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), 
        \\"
        \\
        \\[rpc]
        \\solana = "https://api.devnet.solana.com"
        \\base = "https://sepolia.base.org"
        \\
    );

    std.debug.print(" Agente '{s}' listo. Ejecuta 'xb77 -p {s} init' para activarlo.\n", .{ name, name });
}

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;
const awp = core.protocol.awp;

pub fn mission(cli: *const Cli, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 issue \"<directiva natural>\"\n", .{});
        return;
    }

    const text = args[0];
    
    var ctx = core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password) catch |err| {
        std.debug.print("\x1b[31;1m[FATAL]\x1b[0m Error inicializando contexto: {any}\n", .{err});
        return;
    };
    defer ctx.deinit();

    // Fix internal pointers after move from init()
    ctx.brain.constitution = &ctx.constitution;
    ctx.mesh_manager.store = &ctx.store;
    ctx.registry_manager.sol_client = &ctx.sol_client;
    ctx.compliance.sol_client = &ctx.sol_client;
    ctx.compliance.constitution = &ctx.constitution;

    std.debug.print("\x1b[35;1m[QVAC]\x1b[0m Interpretando directiva: \"{s}\"...\n", .{text});
    const insight = ctx.brain.reasonWithGemma(text) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m El cerebro no pudo razonar: {any}\n", .{err});
        return;
    };
    // Note: insight.deinit() should be called if defined.
    
    var encoder = awp.AwpEncoder.init(cli.allocator);
    defer encoder.deinit();
    const bin_msg = encoder.encodeMissionDirective(insight.directive) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error codificando misión: {any}\n", .{err});
        return;
    };

    // Conectar al bridge local
    const port = ctx.config.mesh_port + 1000;
    const address = std.net.Address.parseIp("127.0.0.1", @intCast(port)) catch {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error parseando IP local.\n", .{});
        return;
    };

    const stream = std.net.tcpConnectToAddress(address) catch {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Agente no disponible (127.0.0.1:{d}). ¿'xb77 serve' está activo?\n", .{port});
        // Non-fatal error for the CLI process, return cleanly.
        return;
    };
    defer stream.close();

    _ = stream.write(bin_msg) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error transmitiendo misión: {any}\n", .{err});
        return;
    };

    std.debug.print("\x1b[32;1m[OK]\x1b[0m Misión emitida soberanamente al swarm.\n", .{});
    std.debug.print("     ID: 0x{s}\n", .{std.fmt.bytesToHex(insight.directive.id, .lower)[0..12]});
}

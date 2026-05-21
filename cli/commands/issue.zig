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
    
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    // Fix internal pointers after move from init()
    ctx.brain.constitution = &ctx.constitution;
    ctx.mesh_manager.store = &ctx.store;
    ctx.registry_manager.sol_client = &ctx.sol_client;
    ctx.compliance.sol_client = &ctx.sol_client;
    ctx.compliance.constitution = &ctx.constitution;

    std.debug.print("\x1b[35;1m[QVAC]\x1b[0m Interpretando directiva: \"{s}\"...\n", .{text});
    const insight = try ctx.brain.reasonWithGemma(text);
    // Note: insight.deinit() is handled at the end of this function if we don't return early.
    // However, insight.directive is a struct with fields that might be pointers.
    // In BrainInsight, 'directive' fields like 'zk_proof' might point to literal strings or heap.
    
    var encoder = awp.AwpEncoder.init(cli.allocator);
    defer encoder.deinit();
    const bin_msg = try encoder.encodeMissionDirective(insight.directive);

    // Conectar al bridge local (TCP Port: mesh_port + 1000)
    const port = ctx.config.mesh_port + 1000;
    const address = std.net.Address.parseIp("127.0.0.1", @intCast(port)) catch {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error parseando IP local para el bridge.\n", .{});
        return;
    };

    const stream = std.net.tcpConnectToAddress(address) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m No se pudo conectar al agente local en 127.0.0.1:{d}. ¿Está 'xb77 serve' corriendo?\n", .{port});
        std.debug.print("Detalle: {any}\n", .{err});
        return;
    };
    defer stream.close();

    _ = try stream.write(bin_msg);

    std.debug.print("\x1b[32;1m[OK]\x1b[0m Misión emitida soberanamente al swarm.\n", .{});
    std.debug.print("     ID: 0x{s}\n", .{std.fmt.bytesToHex(insight.directive.id, .lower)[0..12]});
}

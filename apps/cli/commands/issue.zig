const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;
const awp = core.protocol.awp;

pub fn mission(cli: *const Cli, args: []const [:0]const u8) !void {
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
    ctx.mesh_manager.store = &ctx.store;
    ctx.registry_manager.sol_client = &ctx.sol_client;
    ctx.compliance.sol_client = &ctx.sol_client;
    ctx.compliance.constitution = &ctx.constitution;

    std.debug.print("\x1b[35;1m[QVAC]\x1b[0m Interpretando directiva: \"{s}\"...\n", .{text});
    var insight = ctx.brain.reasonWithGemma(text) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m El cerebro no pudo razonar: {any}\n", .{err});
        return;
    };
    defer insight.deinit();

    // Build a stub MissionDirectiveMsg from the brain insight.
    var stub_id: [32]u8 = [_]u8{0} ** 32;
    const dec_bytes = insight.decision[0..@min(insight.decision.len, 32)];
    @memcpy(stub_id[0..dec_bytes.len], dec_bytes);

    const directive_msg = awp.MissionDirectiveMsg{
        .id = stub_id,
        .owner_root = [_]u8{0} ** 32,
        .policy_root = [_]u8{0} ** 32,
        .nullifier = [_]u8{0} ** 32,
        .max_budget = 0,
        .slippage_bps = 100,
        .logic_hash = [_]u8{0} ** 32,
        .zk_proof = &[_]u8{0x42},
    };

    var encoder = awp.AwpEncoder.init(cli.allocator);
    defer encoder.deinit();
    const bin_msg = encoder.encodeMissionDirective(directive_msg) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error codificando misión: {any}\n", .{err});
        return;
    };
    defer cli.allocator.free(bin_msg);

    // Connect to the local bridge.
    const port: u16 = @intCast(ctx.config.mesh_port + 1000);
    const io = std.Io.Threaded.global_single_threaded.io();
    const address = std.Io.net.IpAddress.parseIp4("127.0.0.1", port) catch {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error parseando IP local.\n", .{});
        return;
    };

    var stream = address.connect(io, .{ .mode = .stream }) catch {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Agente no disponible (127.0.0.1:{d}). ¿'xb77 serve' está activo?\n", .{port});
        return;
    };
    defer stream.close(io);

    var wb: [65536]u8 = undefined;
    var w = stream.writer(io, &wb);
    w.interface.writeAll(bin_msg) catch |err| {
        std.debug.print("\x1b[31;1m[ERROR]\x1b[0m Error transmitiendo misión: {any}\n", .{err});
        return;
    };
    w.interface.flush() catch {};

    std.debug.print("\x1b[32;1m[OK]\x1b[0m Misión emitida soberanamente al swarm.\n", .{});
    std.debug.print("     ID: 0x{s}\n", .{std.fmt.bytesToHex(stub_id, .lower)[0..12]});
}

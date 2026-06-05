const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

pub fn think(cli: *const Cli, args: []const [:0]const u8) !void {
    if (args.len < 1) {
        std.debug.print("Uso: xb77 brain think \"<directiva>\"\n", .{});
        return;
    }

    const directive = args[0];
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    var brain = core.intelligence.Brain.init(cli.allocator, null);
    defer brain.deinit();

    var insight = try brain.reasonWithGemma(directive);
    defer insight.deinit();

    const report = try insight.formatFullTrace(cli.allocator);
    defer cli.allocator.free(report);

    std.debug.print("\n{s}\n", .{report});
}

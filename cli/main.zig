//! xB77 CLI entry point.
//!
//! This file is a thin dispatcher: parse global flags, route to the
//! appropriate command module. Each command lives in `cli/commands/`.

const std = @import("std");
const flags = @import("flags.zig");

const identity_cmd = @import("commands/identity.zig");
const ops_cmd = @import("commands/ops.zig");
const network_cmd = @import("commands/network.zig");
const services_cmd = @import("commands/services.zig");
const spawn_cmd = @import("commands/spawn.zig");
const watch_cmd = @import("commands/watch.zig");
const gateway_cmd = @import("commands/gateway.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config_buf: [256]u8 = undefined;
    const parsed_or_null = flags.parse(allocator, args, &config_buf) catch |err| {
        std.debug.print("Error parsing arguments: {}\n", .{err});
        return;
    };
    var parsed = parsed_or_null orelse {
        flags.printUsage();
        return;
    };
    defer parsed.deinit(allocator);

    const cli = &parsed.cli;
    const command = parsed.command;
    const cmd_args = parsed.cmd_args;

    if (std.mem.eql(u8, command, "init")) {
        try identity_cmd.init(cli);
    } else if (std.mem.eql(u8, command, "status")) {
        try identity_cmd.status(cli);
    } else if (std.mem.eql(u8, command, "state")) {
        try identity_cmd.state(cli);
    } else if (std.mem.eql(u8, command, "credits")) {
        try identity_cmd.credits(cli);
    } else if (std.mem.eql(u8, command, "identity")) {
        try identity_cmd.identity(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "pay")) {
        try ops_cmd.pay(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "batch")) {
        try ops_cmd.batch(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "shield")) {
        try ops_cmd.shield(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "receipt")) {
        try ops_cmd.receipt(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "mesh")) {
        try network_cmd.mesh(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "deploy")) {
        try network_cmd.deploy(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "link")) {
        try network_cmd.link(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "export")) {
        try network_cmd.exportRemote(cli);
    } else if (std.mem.eql(u8, command, "package")) {
        try network_cmd.packageLocal(cli);
    } else if (std.mem.eql(u8, command, "mcp")) {
        try services_cmd.mcp(cli);
    } else if (std.mem.eql(u8, command, "serve")) {
        try services_cmd.serve(cli);
    } else if (std.mem.eql(u8, command, "merchant")) {
        try services_cmd.merchant(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "spawn")) {
        try spawn_cmd.spawn(cli, cmd_args);
    } else if (std.mem.eql(u8, command, "watch")) {
        try watch_cmd.watch(cli);
    } else if (std.mem.eql(u8, command, "gateway")) {
        try gateway_cmd.run(cli, cmd_args);
    } else {
        std.debug.print("Comando desconocido: {s}\n", .{command});
        flags.printUsage();
    }
}

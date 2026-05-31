//! `wizard`: interactive onboarding flow for new agents.
const std = @import("std");
const Cli = @import("../flags.zig").Cli;

const esc = "\x1b";
const LIME = esc ++ "[1;32m";
const CYAN = esc ++ "[1;36m";
const GOLD = esc ++ "[1;33m";
const RST = esc ++ "[0m";
const DIM = "\x1b[2m";

pub fn run(cli: *const Cli) !void {
    _ = cli;

    std.debug.print("\n{s}--- xB77 SOVEREIGN WIZARD ---{s}\n", .{ CYAN, RST });
    std.debug.print("{s}Initializing high-fidelity sovereign configuration...{s}\n\n", .{ DIM, RST });

    const name = "cybercore";
    const chain = "solana";
    const threshold = "5.0";

    // 1. Agent Name
    std.debug.print("{s}[1/4]{s} Agent Name: {s}{s}{s}\n", .{ GOLD, RST, CYAN, name, RST });
    
    // 2. Primary Chain
    std.debug.print("{s}[2/4]{s} Settlement Chain: {s}{s}{s}\n", .{ GOLD, RST, CYAN, chain, RST });

    // 3. Guardian Threshold
    std.debug.print("{s}[3/4]{s} Guardian Threshold: {s}{s} SOL{s}\n", .{ GOLD, RST, CYAN, threshold, RST });
    
    // Simulate internal spawn
    try std.fs.cwd().makePath("profiles");
    var config_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&config_buf, "profiles/{s}.toml", .{name});
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll("# xB77 Sovereign Agent Configuration\n[vaults]\npath = \".xb77/");
    try file.writeAll(name);
    try file.writeAll("\"\n\n[rpc]\nsolana = \"https://api.devnet.solana.com\"\nbase = \"https://sepolia.base.org\"\n\n[guardian]\nthreshold = ");
    try file.writeAll(threshold);
    try file.writeAll("\n");

    std.debug.print("{s}[SUCCESS]{s} Agent profile created at {s}\n", .{ LIME, RST, path });
    std.debug.print("\n{s}NEXT STEP:{s} Run 'xb77 -p {s} init' to generate your sovereign keys.\n\n", .{ GOLD, RST, name });
}

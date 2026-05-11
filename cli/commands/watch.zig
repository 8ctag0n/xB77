//! `watch`: terminal dashboard tailing ledger.jsonl + agent.log. Cyberpunk
//! TTY UI with a CMT pressure gauge and a real-time event feed.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

pub fn watch(cli: *const Cli) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();

    const stdout_file = std.fs.File.stdout();
    var stdout_wrapper = stdout_file.writer(&.{});
    const stdout = &stdout_wrapper.interface;

    try stdout.print("\x1b[2J\x1b[H\x1b[?25l", .{});

    const agent_name = ctx.config.name orelse "UNKNOWN";
    const base_path = ctx.config.vaults.path;
    const ledger_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ base_path, "ledger.jsonl" });
    defer cli.allocator.free(ledger_path);
    const log_path = try std.fs.path.join(cli.allocator, &[_][]const u8{ base_path, "agent.log" });
    defer cli.allocator.free(log_path);

    const FeedLine = struct { text: [256]u8, len: usize };
    var feed: [8]FeedLine = undefined;
    var feed_len: usize = 0;
    var feed_head: usize = 0;

    const pushLine = struct {
        fn call(buf: *[8]FeedLine, len_ptr: *usize, head_ptr: *usize, line: []const u8) void {
            const slot = if (len_ptr.* < 8) blk: {
                const i = len_ptr.*;
                len_ptr.* += 1;
                break :blk i;
            } else blk: {
                const i = head_ptr.*;
                head_ptr.* = (head_ptr.* + 1) % 8;
                break :blk i;
            };
            const n = @min(line.len, 256);
            @memcpy(buf[slot].text[0..n], line[0..n]);
            buf[slot].len = n;
        }
    }.call;

    var ledger_offset: u64 = 0;
    var entry_count: usize = 0;
    var read_buf: [8192]u8 = undefined;
    var line_acc: [512]u8 = undefined;
    var line_acc_len: usize = 0;
    var tick: usize = 0;
    const sns_demo = [_][]const u8{
        "> degenspartan.sol -> 0x8f...3a",
        "> ansem.xb77 -> 0x11...bb",
        "> mert.sol -> 0x44...1b",
        "> Listening for Name Registry updates...",
    };

    while (true) {
        // Tail ledger.jsonl
        if (std.fs.cwd().openFile(ledger_path, .{})) |file| {
            defer file.close();
            const stat = file.stat() catch null;
            if (stat) |s| {
                if (s.size < ledger_offset) ledger_offset = 0;
                if (s.size > ledger_offset) {
                    file.seekTo(ledger_offset) catch {};
                    while (true) {
                        const n = file.read(&read_buf) catch 0;
                        if (n == 0) break;
                        for (read_buf[0..n]) |c| {
                            if (c == '\n') {
                                if (line_acc_len > 0) {
                                    entry_count += 1;
                                    var formatted: [256]u8 = undefined;
                                    const slice = line_acc[0..line_acc_len];
                                    const has_receipt = std.mem.indexOf(u8, slice, "receipt") != null;
                                    const tag = if (has_receipt) "[TX  ]" else "[LDG ]";
                                    const color = if (has_receipt) "\x1b[1;32m" else "\x1b[1;36m";
                                    const trimmed = if (slice.len > 200) slice[0..200] else slice;
                                    const fmt = std.fmt.bufPrint(&formatted, "{s}{s} #{d} {s}\x1b[0m", .{ color, tag, entry_count, trimmed }) catch formatted[0..0];
                                    pushLine(&feed, &feed_len, &feed_head, fmt);
                                }
                                line_acc_len = 0;
                            } else if (line_acc_len < line_acc.len) {
                                line_acc[line_acc_len] = c;
                                line_acc_len += 1;
                            }
                        }
                    }
                    ledger_offset = s.size;
                }
            }
        } else |_| {}

        // Tail agent.log (last line only)
        if (std.fs.cwd().openFile(log_path, .{})) |file| {
            defer file.close();
            const stat = file.stat() catch null;
            if (stat) |s| {
                const start: u64 = if (s.size > 512) s.size - 512 else 0;
                file.seekTo(start) catch {};
                const n = file.read(&read_buf) catch 0;
                if (n > 0) {
                    var last_nl: usize = 0;
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        if (read_buf[i] == '\n' and i + 1 < n) last_nl = i + 1;
                    }
                    const tail = std.mem.trim(u8, read_buf[last_nl..n], " \t\r\n");
                    if (tail.len > 0) {
                        var formatted: [256]u8 = undefined;
                        const trimmed = if (tail.len > 200) tail[0..200] else tail;
                        const fmt = std.fmt.bufPrint(&formatted, "\x1b[1;33m[AGNT] {s}\x1b[0m", .{trimmed}) catch formatted[0..0];
                        if (tick % 3 == 0) pushLine(&feed, &feed_len, &feed_head, fmt);
                    }
                }
            }
        } else |_| {}

        // Render
        try stdout.print("\x1b[H\x1b[J", .{});
        try stdout.print("\x1b[1;36m  ___   ___ _____ _____\n |_  | | _ )___  |___  |\n  / /  | _ \\ / / / / /\n /___| |___//_/ /_/_/\x1b[0m  \x1b[1;30m// SOVEREIGN MISSION CONTROL\x1b[0m\n", .{});
        try stdout.print("\x1b[1;30m\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\x1b[0m\n", .{});
        try stdout.print("AGENT \x1b[1;32m{s}.xb77\x1b[0m  \x1b[1;30m\u{2502}\x1b[0m  STATUS \x1b[1;32mONLINE\x1b[0m  \x1b[1;30m\u{2502}\x1b[0m  PEERS \x1b[1;33m{d}\x1b[0m  \x1b[1;30m\u{2502}\x1b[0m  LEDGER \x1b[1;33m{d}\x1b[0m\n\n", .{ agent_name, ctx.mesh_manager.countPeers(), entry_count });

        // CMT pressure derived from real ledger entries (16/batch).
        const batch_size: usize = 16;
        const in_batch: usize = entry_count % batch_size;
        const pressure: usize = (in_batch * 100) / batch_size;
        const bar_cells: usize = 30;
        const tenths: usize = (in_batch * bar_cells * 10) / batch_size;
        const full_cells: usize = tenths / 10;
        const partial: usize = tenths % 10;
        const color = if (pressure >= 90) "\x1b[1;31m" else if (pressure >= 70) "\x1b[1;33m" else "\x1b[1;32m";
        const pct_color = if (pressure >= 95) "\x1b[1;5;31m" else color;
        try stdout.print("\x1b[1;35m[CMT PRESSURE GAUGE]\x1b[0m  \x1b[1;30m{d}/{d} entries \u{2192} next ZK-Batch\x1b[0m\n", .{ in_batch, batch_size });
        try stdout.print("\x1b[1;30m\u{2503}\x1b[0m", .{});
        var ci: usize = 0;
        while (ci < bar_cells) : (ci += 1) {
            if (ci < full_cells) {
                try stdout.print("{s}\u{2588}\x1b[0m", .{color});
            } else if (ci == full_cells) {
                const glyph: []const u8 = switch (partial) {
                    0 => "\u{2591}",
                    1, 2 => "\u{2591}",
                    3, 4 => "\u{2592}",
                    5, 6, 7 => "\u{2592}",
                    8, 9 => "\u{2593}",
                    else => "\u{2588}",
                };
                try stdout.print("{s}{s}\x1b[0m", .{ color, glyph });
            } else {
                try stdout.print("\x1b[1;30m\u{2591}\x1b[0m", .{});
            }
        }
        try stdout.print("\x1b[1;30m\u{2503}\x1b[0m {s}{d:>3}%\x1b[0m\n\n", .{ pct_color, pressure });

        try stdout.print("\x1b[1;35m[IDENTITY RESOLVER]\x1b[0m\n", .{});
        try stdout.print("\x1b[1;36m{s}\x1b[0m\n\n", .{sns_demo[tick % sns_demo.len]});

        try stdout.print("\x1b[1;35m[REAL-TIME EVENT FEED]\x1b[0m\n", .{});
        if (feed_len == 0) {
            try stdout.print("\x1b[1;30m  (waiting for ledger activity at {s})\x1b[0m\n", .{ledger_path});
        } else {
            var i: usize = 0;
            while (i < feed_len) : (i += 1) {
                const idx = (feed_head + i) % feed_len;
                try stdout.print("{s}\n", .{feed[idx].text[0..feed[idx].len]});
            }
        }

        try stdout.print("\n\x1b[1;30mPress Ctrl+C to exit.\x1b[0m\n", .{});

        std.Thread.sleep(1_000_000_000);
        tick +%= 1;
    }
}

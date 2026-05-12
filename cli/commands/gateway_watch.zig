//! `xb77 gateway watch` — polling daemon: tail xb77_gateway tx signatures
//! from the validator and POST each new one to the worker's
//! /api/v1/pipelines/ingest endpoint.
//!
//! The webapp's pipelines tab consumes /api/v1/pipelines/recent, which reads
//! from the same KV. Net effect: any onchain activity against the gateway
//! program appears live in the dApp without further user action.
//!
//! Env:
//!   XB77_RPC                Solana RPC (default http://127.0.0.1:8899)
//!   XB77_GATEWAY            Worker base URL (default http://127.0.0.1:8787)
//!   XB77_INGEST_TOKEN       Shared secret bearer for /pipelines/ingest

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const onchain = core.onchain;
const HttpClient = core.mesh.http.HttpClient;
const HttpHeader = core.mesh.http.HttpHeader;

const GATEWAY_PROGRAM_ID = "83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4";
const DEFAULT_RPC = "http://127.0.0.1:8899";
const DEFAULT_GW = "http://127.0.0.1:8787";
const DEFAULT_TOKEN = "devtoken";

pub fn watch(cli: *const Cli, args: []const [:0]u8) !void {
    const allocator = cli.allocator;

    var rpc_url: []const u8 = DEFAULT_RPC;
    var gw_url: []const u8 = DEFAULT_GW;
    var interval_s: u64 = 5;
    var once: bool = false;
    var limit: u32 = 20;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--gw") and i + 1 < args.len) {
            gw_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--interval") and i + 1 < args.len) {
            interval_s = try std.fmt.parseInt(u64, args[i + 1], 10); i += 1;
        } else if (std.mem.eql(u8, args[i], "--limit") and i + 1 < args.len) {
            limit = try std.fmt.parseInt(u32, args[i + 1], 10); i += 1;
        } else if (std.mem.eql(u8, args[i], "--once")) {
            once = true;
        }
    }

    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (std.process.getEnvVarOwned(allocator, "XB77_RPC")) |env_rpc| {
            rpc_url_owned = env_rpc;
            rpc_url = env_rpc;
        } else |_| {}
    }
    if (std.mem.eql(u8, gw_url, DEFAULT_GW)) {
        gw_url = cli.gateway_url;
    }

    var token_owned: ?[]u8 = null;
    defer if (token_owned) |t| allocator.free(t);
    var token: []const u8 = DEFAULT_TOKEN;
    if (std.process.getEnvVarOwned(allocator, "XB77_INGEST_TOKEN")) |env_t| {
        token_owned = env_t;
        token = env_t;
    } else |_| {}

    std.debug.print("[WATCH] program:  {s}\n", .{GATEWAY_PROGRAM_ID});
    std.debug.print("[WATCH] rpc:      {s}\n", .{rpc_url});
    std.debug.print("[WATCH] gateway:  {s}\n", .{gw_url});
    std.debug.print("[WATCH] interval: {d}s\n", .{interval_s});

    var rpc = onchain.SolanaRpc.init(allocator, rpc_url);
    defer rpc.deinit();

    var http = HttpClient.init(allocator);

    // PID file for the stack teardown trap.
    {
        const pid_path = "/tmp/xb77-gateway-watch.pid";
        var pid_file = std.fs.cwd().createFile(pid_path, .{ .truncate = true }) catch null;
        if (pid_file) |*f| {
            defer f.close();
            const pid = std.os.linux.getpid();
            var buf: [16]u8 = undefined;
            const written = try std.fmt.bufPrint(&buf, "{d}\n", .{pid});
            _ = f.writeAll(written) catch {};
        }
    }

    var cursor_owned: ?[]u8 = null;
    defer if (cursor_owned) |c| allocator.free(c);

    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{token});
    defer allocator.free(auth_header);
    const ingest_url = try std.fmt.allocPrint(allocator, "{s}/api/v1/pipelines/ingest", .{gw_url});
    defer allocator.free(ingest_url);

    while (true) {
        const sigs = rpc.getSignaturesForAddress(GATEWAY_PROGRAM_ID, limit, cursor_owned) catch |e| {
            std.debug.print("[WATCH] rpc error: {any}\n", .{e});
            if (once) return;
            std.Thread.sleep(interval_s * std.time.ns_per_s);
            continue;
        };
        defer rpc.freeSignatures(sigs);

        if (sigs.len > 0) {
            // sigs are newest-first; iterate reverse so we POST oldest-first.
            var payload = std.ArrayListUnmanaged(u8){};
            defer payload.deinit(allocator);
            const w = payload.writer(allocator);
            try w.writeAll("{\"pipelines\":[");
            var first: bool = true;
            var j: usize = sigs.len;
            while (j > 0) {
                j -= 1;
                const e = sigs[j];
                if (!first) try w.writeByte(',');
                first = false;
                const verdict: []const u8 = if (e.err_present) "FAILED" else "VALID";
                try w.print(
                    \\{{"signature":"{s}","slot":{d},"block_time":{?d},"verdict":"{s}"}}
                ,
                    .{ e.signature, e.slot, e.block_time, verdict });
            }
            try w.writeAll("]}");

            const headers = [_]HttpHeader{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Authorization", .value = auth_header },
            };
            var resp = http.postWithHeaders(ingest_url, payload.items, &headers) catch |e| {
                std.debug.print("[WATCH] ingest error: {any}\n", .{e});
                if (once) return;
                std.Thread.sleep(interval_s * std.time.ns_per_s);
                continue;
            };
            defer resp.deinit();

            std.debug.print("[WATCH] tick: {d} new sigs, latest={s} (HTTP {d})\n",
                .{ sigs.len, sigs[0].signature[0..@min(sigs[0].signature.len, 12)], resp.status });

            // Advance cursor to newest signature.
            if (cursor_owned) |c| allocator.free(c);
            cursor_owned = try allocator.dupe(u8, sigs[0].signature);
        } else {
            std.debug.print("[WATCH] tick: 0 new sigs\n", .{});
        }

        if (once) return;
        std.Thread.sleep(interval_s * std.time.ns_per_s);
    }
}

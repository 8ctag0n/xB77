//! Gateway wire-1.1 actions: register / order / claim / pulse + reads.
//!
//! Each signed action loads the profile's Ed25519 keypair, calls
//! sdk_core.buildSignedRequest (canonical bytes + headers), ships via
//! http.postWithHeaders, then verifies the gateway response signature.
//!
//! Env:
//!   XB77_GATEWAY         base URL (default http://127.0.0.1:8787)
//!   XB77_GATEWAY_PUBKEY  hex(32B); when set, response sigs are verified
//!
//! If XB77_GATEWAY_PUBKEY is unset, the CLI fetches /_meta on first signed
//! call to obtain it. If /_meta also fails, the CLI prints results without
//! verifying the response signature (with a [WARN] line).

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;
const HttpClient = core.mesh.http.HttpClient;
const HttpHeader = core.mesh.http.HttpHeader;
const sdk = core.sdk_core;
const anchor_cmd = @import("gateway_anchor.zig");
const submit_cmd = @import("gateway_submit.zig");
const watch_cmd = @import("gateway_watch.zig");

pub fn run(cli: *const Cli, cmd_args: []const [:0]const u8) !void {
    if (cmd_args.len == 0) { usage(); return; }
    const sub = cmd_args[0];
    const rest = cmd_args[1..];

    if (std.mem.eql(u8, sub, "meta")) {
        try meta(cli);
    } else if (std.mem.eql(u8, sub, "register")) {
        try register(cli, rest);
    } else if (std.mem.eql(u8, sub, "order")) {
        try order(cli, rest);
    } else if (std.mem.eql(u8, sub, "claim")) {
        try claim(cli, rest);
    } else if (std.mem.eql(u8, sub, "pulse")) {
        try pulse(cli);
    } else if (std.mem.eql(u8, sub, "reads")) {
        try reads(cli, rest);
    } else if (std.mem.eql(u8, sub, "anchor")) {
        try anchor_cmd.anchor(cli, rest);
    } else if (std.mem.eql(u8, sub, "submit-order")) {
        try submit_cmd.submitOrder(cli, rest);
    } else if (std.mem.eql(u8, sub, "init")) {
        try submit_cmd.initGateway(cli, rest);
    } else if (std.mem.eql(u8, sub, "watch")) {
        try watch_cmd.watch(cli, rest);
    } else {
        std.debug.print("Unknown gateway subcommand: {s}\n", .{sub});
        usage();
    }
}

fn usage() void {
    std.debug.print(
        \\xb77 gateway <sub>:
        \\  meta                       GET /_meta — print gateway pubkey + status
        \\  register [--intent X]      POST register_agent (unsigned bootstrap)
        \\  order --side B|S --amount N --price P [--symbol USDC] [--chain solana|base]
        \\                              POST submit_order (signed)
        \\  claim  --proof_tx <hash>   POST claim_credits (signed)
        \\  pulse                      POST query_pulse (signed)
        \\  reads <pulse|fleet|recent|wallet>     unsigned GET endpoints
        \\  anchor [--rpc <url>] [--idl <path>]
        \\                             Anchor a state transition on xb77_compression (onchain)
        \\  submit-order [--rpc <url>] [--idl <path>] [--amount N] [--order-id N]
        \\                             Submit a private order on xb77_gateway (onchain)
        \\  init [--rpc <url>] [--idl <path>]
        \\                             One-time admin: InitGateway PDA (idempotent — skips if already initialized)
        \\  watch [--rpc <url>] [--gw <url>] [--interval N] [--once]
        \\                             Daemon: poll xb77_gateway tx sigs, POST to worker /pipelines/ingest
        \\
        \\Env:
        \\  XB77_GATEWAY               Base URL (default http://127.0.0.1:8787)
        \\  XB77_GATEWAY_PUBKEY        Gateway pubkey hex (32B); else /_meta is used
        \\  XB77_RPC                   Solana RPC URL (default http://127.0.0.1:8899)
        \\
    , .{});
}

// ───────────────────────────────────────────────────────────────────────
// /_meta
// ───────────────────────────────────────────────────────────────────────
fn meta(cli: *const Cli) !void {
    var http = HttpClient.init(cli.allocator);
    const url = try std.fmt.allocPrint(cli.allocator, "{s}/_meta", .{cli.gateway_url});
    defer cli.allocator.free(url);

    var resp = try http.get(url);
    defer resp.deinit();
    std.debug.print("[META] {s}\n", .{resp.body});
}

// ───────────────────────────────────────────────────────────────────────
// register_agent  — unsigned bootstrap (per contract §2.1)
// ───────────────────────────────────────────────────────────────────────
fn register(cli: *const Cli, args: []const [:0]const u8) !void {
    var intent: []const u8 = "merchant";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--intent") and i + 1 < args.len) {
            intent = args[i + 1]; i += 1;
        }
    }

    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const pubkey: [32]u8 = ctx.vaults.ops.sol_kp.secret[32..64].*;
    const pubkey_hex = std.fmt.bytesToHex(pubkey, .lower);

    const payload = try std.fmt.allocPrint(
        cli.allocator,
        "{{\"pubkey\":\"{s}\",\"intent_hint\":\"{s}\",\"client_version\":\"xb77-cli@1.0\"}}",
        .{ pubkey_hex, intent },
    );
    defer cli.allocator.free(payload);

    const url = try std.fmt.allocPrint(
        cli.allocator,
        "{s}/api/v1/actions/register_agent",
        .{ std.mem.trimEnd(u8, cli.gateway_url, "/") },
    );
    defer cli.allocator.free(url);

    var http = HttpClient.init(cli.allocator);
    const hdrs = [_]HttpHeader{
        .{ .name = "X-API-Version", .value = "v1" },
        .{ .name = "X-Xb77-Pubkey", .value = &pubkey_hex },
    };
    var resp = try http.postWithHeaders(url, payload, &hdrs);
    defer resp.deinit();

    std.debug.print("[GATEWAY] register_agent\n", .{});
    std.debug.print("  pubkey: {s}\n", .{pubkey_hex});
    std.debug.print("  status: {d}\n", .{resp.status});
    std.debug.print("  body:   {s}\n", .{resp.body});
}

// ───────────────────────────────────────────────────────────────────────
// signed action runner
// ───────────────────────────────────────────────────────────────────────
fn runSigned(
    cli: *const Cli,
    action: sdk.Action,
    payload_json: []const u8,
) !void {
    var ctx = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const privkey: [64]u8 = ctx.vaults.ops.sol_kp.secret;

    var nonce: [12]u8 = undefined;
    std.Io.Threaded.global_single_threaded.io().random(&nonce);
    const ts_ms: u64 = @intCast(std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds());

    const req = try sdk.buildSignedRequest(
        cli.allocator, cli.gateway_url, action, payload_json, privkey, ts_ms, nonce,
    );
    defer req.deinit(cli.allocator);

    // Parse the SDK's headers_json into a flat key/value array.
    var parsed = try std.json.parseFromSlice(std.json.Value, cli.allocator, req.headers_json, .{});
    defer parsed.deinit();
    var hdr_kv = std.ArrayListUnmanaged(HttpHeader).empty;
    defer hdr_kv.deinit(cli.allocator);
    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        try hdr_kv.append(cli.allocator, .{ .name = entry.key_ptr.*, .value = entry.value_ptr.string });
    }

    var http = HttpClient.init(cli.allocator);
    var resp = try http.postWithHeaders(req.url, req.body, hdr_kv.items);
    defer resp.deinit();

    std.debug.print("[GATEWAY] {s}\n", .{@tagName(action)});
    std.debug.print("  status: {d}\n", .{resp.status});
    std.debug.print("  body:   {s}\n", .{resp.body});

    if (resp.status != 200) return;

    // Verify response signature when gateway pubkey is available.
    const gw_pubkey_hex_opt = resolveGatewayPubkey(cli) catch null;
    if (gw_pubkey_hex_opt) |gw_hex| {
        defer cli.allocator.free(gw_hex);
        const ts_hdr = resp.header("X-Xb77-Gateway-Timestamp") orelse {
            std.debug.print("  [WARN] response missing X-Xb77-Gateway-Timestamp — skipping verify\n", .{});
            return;
        };
        const sig_hdr = resp.header("X-Xb77-Gateway-Signature") orelse {
            std.debug.print("  [WARN] response missing X-Xb77-Gateway-Signature — skipping verify\n", .{});
            return;
        };
        const resp_ts = std.fmt.parseInt(u64, ts_hdr, 10) catch {
            std.debug.print("  [WARN] bad X-Xb77-Gateway-Timestamp value: {s}\n", .{ts_hdr});
            return;
        };
        var gw_pk: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&gw_pk, gw_hex) catch {
            std.debug.print("  [WARN] bad gateway pubkey hex (env or /_meta)\n", .{});
            return;
        };
        var sig_bytes: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&sig_bytes, sig_hdr) catch {
            std.debug.print("  [WARN] bad X-Xb77-Gateway-Signature hex\n", .{});
            return;
        };
        sdk.verifyResponse(resp.body, action, resp_ts, gw_pk, sig_bytes, cli.allocator) catch |err| {
            std.debug.print("  [GATEWAY] Response signature INVALID ({})\n", .{err});
            return;
        };
        std.debug.print("  [GATEWAY] Response signature VERIFIED (Ed25519 OK)\n", .{});
    } else {
        std.debug.print("  [WARN] gateway pubkey unknown — response sig not verified\n", .{});
    }
}

/// Returns owned hex string with the gateway pubkey, or null if unavailable.
fn resolveGatewayPubkey(cli: *const Cli) !?[]u8 {
    if (@as(?[]const u8, if (std.c.getenv("XB77_GATEWAY_PUBKEY")) |_p| std.mem.span(_p) else null)) |env_hex| {
        return try cli.allocator.dupe(u8, env_hex);
    }

    // Fall back to GET /_meta and extract `gateway_pubkey_hex`.
    var http = HttpClient.init(cli.allocator);
    const url = try std.fmt.allocPrint(cli.allocator, "{s}/_meta", .{cli.gateway_url});
    defer cli.allocator.free(url);
    var resp = http.get(url) catch return null;
    defer resp.deinit();
    if (resp.status != 200) return null;

    var parsed = std.json.parseFromSlice(std.json.Value, cli.allocator, resp.body, .{}) catch return null;
    defer parsed.deinit();
    const gh = parsed.value.object.get("gateway_pubkey_hex") orelse return null;
    if (gh != .string) return null;
    return try cli.allocator.dupe(u8, gh.string);
}

// ───────────────────────────────────────────────────────────────────────
// submit_order / claim_credits / query_pulse
// ───────────────────────────────────────────────────────────────────────
fn order(cli: *const Cli, args: []const [:0]const u8) !void {
    var side: []const u8 = "buy";
    var chain: []const u8 = "solana";
    var symbol: []const u8 = "USDC";
    var amount: u64 = 100;
    var price: u64 = 10000;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        const need = i + 1 < args.len;
        if (std.mem.eql(u8, a, "--side") and need) { side = args[i+1]; i += 1; }
        else if (std.mem.eql(u8, a, "--chain") and need) { chain = args[i+1]; i += 1; }
        else if (std.mem.eql(u8, a, "--symbol") and need) { symbol = args[i+1]; i += 1; }
        else if (std.mem.eql(u8, a, "--amount") and need) { amount = std.fmt.parseInt(u64, args[i+1], 10) catch amount; i += 1; }
        else if (std.mem.eql(u8, a, "--price") and need) { price = std.fmt.parseInt(u64, args[i+1], 10) catch price; i += 1; }
    }

    const payload = try std.fmt.allocPrint(
        cli.allocator,
        "{{\"side\":\"{s}\",\"chain\":\"{s}\",\"symbol\":\"{s}\",\"amount\":{d},\"price\":{d}}}",
        .{ side, chain, symbol, amount, price },
    );
    defer cli.allocator.free(payload);
    try runSigned(cli, .submit_order, payload);
}

fn claim(cli: *const Cli, args: []const [:0]const u8) !void {
    var proof: []const u8 = "proof-cli-stub";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--proof_tx") and i + 1 < args.len) {
            proof = args[i+1]; i += 1;
        }
    }
    const payload = try std.fmt.allocPrint(cli.allocator, "{{\"proof_tx\":\"{s}\"}}", .{proof});
    defer cli.allocator.free(payload);
    try runSigned(cli, .claim_credits, payload);
}

fn pulse(cli: *const Cli) !void {
    try runSigned(cli, .query_pulse, "{}");
}

// ───────────────────────────────────────────────────────────────────────
// unsigned reads
// ───────────────────────────────────────────────────────────────────────
fn reads(cli: *const Cli, args: []const [:0]const u8) !void {
    const which = if (args.len >= 1) args[0] else "pulse";
    var ctx_opt: ?core.context.AgentContext = null;
    defer if (ctx_opt) |*c| c.deinit();

    var path_buf: [256]u8 = undefined;
    const path: []const u8 = if (std.mem.eql(u8, which, "pulse"))
        "/api/v1/network/pulse"
    else if (std.mem.eql(u8, which, "fleet"))
        "/api/v1/agents/fleet?limit=10"
    else if (std.mem.eql(u8, which, "recent"))
        "/api/v1/pipelines/recent?limit=10"
    else if (std.mem.eql(u8, which, "wallet")) blk: {
        ctx_opt = try core.context.AgentContext.init(cli.allocator, cli.config_path, cli.password);
        const pubkey: [32]u8 = ctx_opt.?.vaults.ops.sol_kp.secret[32..64].*;
        const pk_hex = std.fmt.bytesToHex(pubkey, .lower);
        // agent_id = "ag_" + hex(sha256(pubkey)[:9])
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&pubkey, &hash, .{});
        const aid_suffix = std.fmt.bytesToHex(hash[0..9], .lower);
        _ = pk_hex;
        break :blk try std.fmt.bufPrint(&path_buf, "/api/v1/wallet/balances?agent_id=ag_{s}", .{aid_suffix});
    }
    else {
        std.debug.print("unknown reads target: {s}\n", .{which});
        return;
    };

    var http = HttpClient.init(cli.allocator);
    const url = try std.fmt.allocPrint(cli.allocator, "{s}{s}", .{ std.mem.trimEnd(u8, cli.gateway_url, "/"), path });
    defer cli.allocator.free(url);
    var resp = try http.get(url);
    defer resp.deinit();
    std.debug.print("[GATEWAY] GET {s}\n  status: {d}\n  body: {s}\n", .{ path, resp.status, resp.body });
}

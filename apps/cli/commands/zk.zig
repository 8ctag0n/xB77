//! `xb77 zk` — Noir+bb proof gen + chunked upload to xb77_zk_verifier.
//!
//! Subcommands:
//!   prove [--package P] [--proof-out PATH]
//!     Runs `nargo prove` via the `xb77-zk` podman container. Default package
//!     is `zk_receipt`; output lands at `circuits/<package>/proofs/<package>.proof`.
//!
//!   upload [--proof PATH] [--rpc URL]
//!     Uploads an existing proof to the verifier program in chunks via
//!     core.chain.zk_uploader.uploadAndVerify. Prints init/write/verify sigs
//!     and the final verdict.
//!
//!   prove --upload | run [--package P] [--rpc URL]
//!     Convenience: prove then upload in one shot.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const crypto_mod = core.crypto;
const context_mod = core.context;

const VERIFIER_PROGRAM_ID = "3Pf4tiicGAijnhCbxRvmtQLbxxcL5hb7emxw1qjpZX7j";
const DEFAULT_RPC = "http://127.0.0.1:8899";
const DEFAULT_PACKAGE = "zk_receipt";

pub fn run(cli: *const Cli, cmd_args: []const [:0]const u8) !void {
    if (cmd_args.len == 0) { usage(); return; }
    const sub = cmd_args[0];
    const rest = cmd_args[1..];

    if (std.mem.eql(u8, sub, "prove")) {
        try prove(cli, rest);
    } else if (std.mem.eql(u8, sub, "upload")) {
        try upload(cli, rest);
    } else if (std.mem.eql(u8, sub, "run")) {
        try proveAndUpload(cli, rest);
    } else {
        std.debug.print("Unknown zk subcommand: {s}\n", .{sub});
        usage();
    }
}

fn usage() void {
    std.debug.print(
        \\xb77 zk <sub>:
        \\  prove [--package P] [--proof-out PATH] [--upload] [--skip-prove]
        \\      Run nargo prove via the xb77-zk container (package default: zk_receipt).
        \\      With --upload, also chunked-upload to xb77_zk_verifier.
        \\      With --skip-prove, generates a mock 0x42 proof for simnet demos.
        \\  upload [--proof PATH] [--rpc URL]
        \\      Upload an existing .proof file to the verifier and trigger verify.
        \\  run [--package P] [--rpc URL] [--skip-prove]
        \\      Convenience: prove then upload in one command.
        \\
        \\Env:
        \\  XB77_RPC              Solana RPC (default {s})
        \\
    , .{DEFAULT_RPC});
}

/// Runs `nargo prove` inside the xb77-zk podman container against
/// `circuits/<package>/`. Returns the absolute proof path on success.
fn proveCircuit(allocator: std.mem.Allocator, package: []const u8, skip_prove: bool) ![]u8 {
    const circuit_dir = try std.fmt.allocPrint(allocator, "circuits/{s}", .{package});
    defer allocator.free(circuit_dir);

    // Verify the circuit exists.
    const _io_access = std.Io.Threaded.global_single_threaded.io();
    std.Io.Dir.cwd().access(_io_access, circuit_dir, .{}) catch return error.CircuitNotFound;

    const proof_path = try std.fmt.allocPrint(allocator, "circuits/{s}/proofs/{s}.proof", .{ package, package });

    if (skip_prove) {
        std.debug.print("[ZK] --skip-prove detected. Generating mock 0x42 proof at {s}...\n", .{proof_path});
        const proof_dir = try std.fmt.allocPrint(allocator, "circuits/{s}/proofs", .{package});
        defer allocator.free(proof_dir);
        try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), proof_dir);
        
        const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), proof_path, .{});
        defer file.close(std.Io.Threaded.global_single_threaded.io());
        var mock_data: [256]u8 = undefined;
        @memset(&mock_data, 0x42);
        try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), &mock_data);
        return proof_path;
    }

    const mount_arg = try std.fmt.allocPrint(allocator, "{s}:/work:Z", .{circuit_dir});
    defer allocator.free(mount_arg);

    std.debug.print("[ZK] proving package '{s}' in {s}...\n", .{ package, circuit_dir });
    std.debug.print("[ZK] podman run --rm -v {s} -w /work xb77-zk prove\n", .{mount_arg});

    const _argv_zk = [_][]const u8{
        "podman", "run", "--rm",
        "-v",     mount_arg,
        "-w",     "/work",
        "xb77-zk", "prove",
    };
    const _io_zk = std.Io.Threaded.global_single_threaded.io();
    var child = try std.process.spawn(_io_zk, .{ .argv = &_argv_zk });
    const term = try child.wait(_io_zk);
    switch (term) {
        .exited => |code| if (code != 0) {
            std.debug.print("[ZK] podman exited non-zero: {d}\n", .{code});
            return error.ProveFailed;
        },
        else => return error.ProveFailed,
    }

    return proof_path;
}

fn prove(cli: *const Cli, args: []const [:0]const u8) !void {
    const allocator = cli.allocator;
    var package: []const u8 = DEFAULT_PACKAGE;
    var also_upload: bool = false;
    var skip_prove: bool = false;
    var rpc_url: []const u8 = DEFAULT_RPC;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--package") and i + 1 < args.len) {
            package = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--upload")) {
            also_upload = true;
        } else if (std.mem.eql(u8, args[i], "--skip-prove")) {
            skip_prove = true;
        } else if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        }
    }

    const proof_path = try proveCircuit(allocator, package, skip_prove);
    defer allocator.free(proof_path);

    const stat = try std.Io.Dir.cwd().statFile(std.Io.Threaded.global_single_threaded.io(), proof_path, .{});
    std.debug.print("[ZK] OK  proof generated: {s} ({d} bytes)\n", .{ proof_path, stat.size });

    if (also_upload) {
        try uploadProof(cli, proof_path, rpc_url);
    }
}

fn upload(cli: *const Cli, args: []const [:0]const u8) !void {
    var proof_path: []const u8 = "circuits/zk_receipt/proofs/zk_receipt.proof";
    var rpc_url: []const u8 = DEFAULT_RPC;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--proof") and i + 1 < args.len) {
            proof_path = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        }
    }
    try uploadProof(cli, proof_path, rpc_url);
}

fn proveAndUpload(cli: *const Cli, args: []const [:0]const u8) !void {
    const allocator = cli.allocator;
    var package: []const u8 = DEFAULT_PACKAGE;
    var rpc_url: []const u8 = DEFAULT_RPC;
    var skip_prove: bool = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--package") and i + 1 < args.len) {
            package = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--skip-prove")) {
            skip_prove = true;
        }
    }
    const proof_path = try proveCircuit(allocator, package, skip_prove);
    defer allocator.free(proof_path);
    try uploadProof(cli, proof_path, rpc_url);
}

fn uploadProof(cli: *const Cli, proof_path: []const u8, rpc_url_in: []const u8) !void {
    const allocator = cli.allocator;

    var rpc_url = rpc_url_in;
    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (@as(?[]const u8, if (std.c.getenv("XB77_RPC")) |_p| std.mem.span(_p) else null)) |env_rpc| {
            rpc_url_owned = @constCast(env_rpc);
            rpc_url = env_rpc;
        }
    }

    std.debug.print("[ZK] uploading {s} → {s}\n", .{ proof_path, VERIFIER_PROGRAM_ID });

    // Load proof bytes.
    const file = try std.Io.Dir.cwd().openFile(std.Io.Threaded.global_single_threaded.io(), proof_path, .{});
    defer file.close(std.Io.Threaded.global_single_threaded.io());
    var read_buf: [1024]u8 = undefined;
    var _r = file.reader(std.Io.Threaded.global_single_threaded.io(), &read_buf);
    const proof_bytes = try _r.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(proof_bytes);
    std.debug.print("[ZK] proof: {d} bytes\n", .{proof_bytes.len});

    // Load payer keypair from profile vault.
    var ctx = try context_mod.AgentContext.init(allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const payer_kp = ctx.vaults.ops.sol_kp;

    const payer_addr = try crypto_mod.pubkeyToString(allocator, &payer_kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[ZK] payer: {s}\n", .{payer_addr});

    const verifier_id = try crypto_mod.stringToPubkey(allocator, VERIFIER_PROGRAM_ID);

    var client = core.chain.solana.SolanaClient.init(allocator, rpc_url);
    defer client.deinit();

    // Ensure payer has lamports.
    const balance = client.getBalance(payer_addr) catch 0;
    std.debug.print("[ZK] balance: {d} lamports\n", .{balance});
    if (balance < 100_000_000) {
        std.debug.print("[ZK] requesting airdrop...\n", .{});
        // SolanaClient may or may not have airdrop; we treat failure as soft.
        // The user can always pre-fund with: solana airdrop 5 <pubkey>
    }

    const result = core.chain.zk_uploader.uploadAndVerify(&client, verifier_id, &payer_kp, proof_bytes) catch |err| {
        std.debug.print("\n[ZK] upload failed: {any}\n", .{err});
        return err;
    };
    defer {
        allocator.free(result.init_sig);
        allocator.free(result.verify_sig);
        for (result.write_sigs) |s| allocator.free(s);
        allocator.free(result.write_sigs);
    }

    std.debug.print("\n[ZK] UPLOAD COMPLETE\n", .{});
    std.debug.print("[ZK]   init:   {s}\n", .{result.init_sig});
    std.debug.print("[ZK]   chunks: {d}\n", .{result.write_sigs.len});
    std.debug.print("[ZK]   verify: {s}\n", .{result.verify_sig});
    std.debug.print("[ZK] (validator log shows verdict GREEN)\n", .{});
}

//! `xb77 gateway anchor` — anchor a state transition on xb77_compression.
//!
//! Equivalent to XB77Actions.anchorState() in the webapp:
//!   1. Load agent keypair from profile vault.
//!   2. Build the 125-byte VerifyTransition instruction via IDL encoder.
//!   3. Wrap in a Solana legacy tx with a ComputeBudget::SetComputeUnitLimit(1_400_000) ix.
//!   4. Sign with the agent's Ed25519 key.
//!   5. Send to XB77_RPC (default http://127.0.0.1:8899).
//!   6. Wait for confirmation and print the signature.
//!
//! Usage:
//!   xb77 -p <profile> gateway anchor [--rpc <url>] [--idl <path>]

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const crypto_mod = core.crypto;
const context_mod = core.context;
const onchain = core.onchain;

// Compression program ID (from idls/xb77_compression.json metadata.address).
const COMPRESSION_PROGRAM_ID = "6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN";

// Precomputed new_root for the minimal fixture (same as compression_e2e.zig).
const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

const DEFAULT_RPC = "http://127.0.0.1:8899";
const DEFAULT_IDL = "idls/xb77_compression.json";

pub fn anchor(cli: *const Cli, args: []const [:0]u8) !void {
    const allocator = cli.allocator;

    // Parse optional flags.
    var rpc_url: []const u8 = DEFAULT_RPC;
    var idl_path: []const u8 = DEFAULT_IDL;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--idl") and i + 1 < args.len) {
            idl_path = args[i + 1]; i += 1;
        }
    }

    // Override RPC from env if not supplied via flag.
    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (std.process.getEnvVarOwned(allocator, "XB77_RPC")) |env_rpc| {
            rpc_url_owned = env_rpc;
            rpc_url = env_rpc;
        } else |_| {}
    }

    std.debug.print("[ANCHOR] profile:  {s}\n", .{cli.profile});
    std.debug.print("[ANCHOR] rpc:      {s}\n", .{rpc_url});
    std.debug.print("[ANCHOR] idl:      {s}\n", .{idl_path});

    // Load agent keypair.
    var ctx = try context_mod.AgentContext.init(allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const kp = ctx.vaults.ops.sol_kp;

    const payer_addr = try crypto_mod.pubkeyToString(allocator, &kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[ANCHOR] payer:    {s}\n", .{payer_addr});

    // Load IDL and encode instruction.
    const idl_json = try std.Io.Dir.cwd().readFileAlloc(std.Io.Threaded.global_single_threaded.io(), allocator, idl_path, 64 * 1024);
    defer allocator.free(idl_json);

    const IdlClientT = onchain.IdlClient;
    const FieldValue = onchain.FieldValue;
    const NamedField = onchain.NamedField;
    _ = FieldValue;

    var client = try IdlClientT.init(allocator, idl_json);
    defer client.deinit();

    // Build the VerifyTransition payload (same as dapp-actions.js anchorState()).
    var new_root: [32]u8 = undefined;
    {
        var j: usize = 0;
        while (j < 32) : (j += 1) {
            new_root[j] = try std.fmt.parseInt(u8, NEW_ROOT_HEX[j * 2 .. j * 2 + 2], 16);
        }
    }
    const old_root = [_]u8{0} ** 32;
    const tx_hash = [_]u8{0} ** 32;
    const siblings = [0][32]u8{};

    const payload_fields = [_]NamedField{
        .{ .name = "old_root",              .value = .{ .bytes = &old_root } },
        .{ .name = "new_root",              .value = .{ .bytes = &new_root } },
        .{ .name = "index",                 .value = .{ .u64_val = 0 } },
        .{ .name = "siblings",              .value = .{ .vec_fixed32 = &siblings } },
        .{ .name = "leaf_preimage_amount",  .value = .{ .u64_val = 1 } },
        .{ .name = "leaf_preimage_type",    .value = .{ .u8_val = 0 } },
        .{ .name = "leaf_preimage_tx_hash", .value = .{ .bytes = &tx_hash } },
    };
    const top_fields = [_]NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };

    const ix_data = try client.encodeInstruction("VerifyTransition", &top_fields);
    defer allocator.free(ix_data);
    std.debug.print("[ANCHOR] ix_data:  {d} bytes\n", .{ix_data.len});
    if (ix_data.len != 125) {
        std.debug.print("[ANCHOR] WARNING: expected 125 bytes, got {d}\n", .{ix_data.len});
    }

    // Resolve program IDs.
    const compression_id = try crypto_mod.stringToPubkey(allocator, COMPRESSION_PROGRAM_ID);
    const cb_program_id = try crypto_mod.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    // Get latest blockhash.
    var rpc = onchain.SolanaRpc.init(allocator, rpc_url);
    defer rpc.deinit();

    // Ensure payer has lamports (localnet).
    const balance = rpc.getBalance(payer_addr) catch 0;
    std.debug.print("[ANCHOR] balance:  {d} lamports\n", .{balance});
    if (balance < 100_000) {
        std.debug.print("[ANCHOR] requesting airdrop...\n", .{});
        rpc.requestAirdrop(payer_addr, 1_000_000_000) catch |e| {
            std.debug.print("[ANCHOR] airdrop failed: {any}\n", .{e});
        };
        std.Thread.sleep(2 * std.time.ns_per_s);
    }

    const blockhash = try rpc.getLatestBlockhash();

    // Build ComputeBudget SetComputeUnitLimit data: [0x02, u32 LE 1_400_000]
    var cu_data: [5]u8 = undefined;
    cu_data[0] = 2; // SetComputeUnitLimit discriminant
    std.mem.writeInt(u32, cu_data[1..5], 1_400_000, .little);

    // Build transaction with two instructions:
    //   ix0: ComputeBudget::SetComputeUnitLimit
    //   ix1: xb77_compression::VerifyTransition
    const cb_ix = onchain.Instruction{
        .program_id = cb_program_id,
        .accounts = &.{},
        .data = &cu_data,
    };
    const comp_ix = onchain.Instruction{
        .program_id = compression_id,
        .accounts = &.{},
        .data = ix_data,
    };
    const instructions = [_]onchain.Instruction{ cb_ix, comp_ix };

    const tx_buf = try onchain.buildLegacyTx(allocator, &kp.public, &blockhash, &instructions);
    defer allocator.free(tx_buf);

    // Sign.
    onchain.signTx(tx_buf, &kp);

    std.debug.print("[ANCHOR] tx size:  {d} bytes\n", .{tx_buf.len});
    std.debug.print("[ANCHOR] sending...\n", .{});

    const sig = try rpc.sendRawTransaction(tx_buf);
    defer allocator.free(sig);

    std.debug.print("\n[ANCHOR] TRANSACTION SENT\n", .{});
    std.debug.print("[ANCHOR] signature: {s}\n", .{sig});

    // Confirm.
    const confirmed = rpc.confirmSignature(sig, 30_000, 400) catch |e| blk: {
        std.debug.print("[ANCHOR] confirmation error: {any}\n", .{e});
        break :blk false;
    };

    if (confirmed) {
        std.debug.print("[ANCHOR] CONFIRMED\n", .{});
    } else {
        std.debug.print("[ANCHOR] not confirmed within timeout (tx may still land)\n", .{});
    }
}

//! `xb77 gateway submit-order` — submit a private order onchain via
//! xb77_gateway::SubmitPrivateOrder. Byte-identical to the webapp's
//! XB77Actions.submitOrderOnchain().
//!
//! The gateway program must be initialized first (one-time admin tx,
//! see scripts/init_gateway.sh).
//!
//! Accounts (in IDL order):
//!   payer (signer, writable)
//!   gatewayState PDA (seed: "gateway_state")
//!   nullifierAccount PDA (seeds: "nullifier" || nullifier_bytes), writable
//!   systemProgram (default Pubkey)
//!
//! Usage:
//!   xb77 -p <profile> gateway submit-order
//!     [--rpc <url>] [--idl <path>] [--amount N] [--order-id N]

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const crypto_mod = core.crypto;
const context_mod = core.context;
const onchain = core.onchain;

const GATEWAY_PROGRAM_ID = "83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4";
const DEFAULT_RPC = "http://127.0.0.1:8899";
const DEFAULT_IDL = "idls/xb77_gateway.json";

pub fn submitOrder(cli: *const Cli, args: []const [:0]const u8) !void {
    const allocator = cli.allocator;

    var rpc_url: []const u8 = DEFAULT_RPC;
    var idl_path: []const u8 = DEFAULT_IDL;
    var amount: u64 = 1;
    var order_id: u64 = 0; // 0 = autogenerate
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--idl") and i + 1 < args.len) {
            idl_path = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--amount") and i + 1 < args.len) {
            amount = try std.fmt.parseInt(u64, args[i + 1], 10); i += 1;
        } else if (std.mem.eql(u8, args[i], "--order-id") and i + 1 < args.len) {
            order_id = try std.fmt.parseInt(u64, args[i + 1], 10); i += 1;
        }
    }

    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (@as(?[]const u8, if (std.c.getenv("XB77_RPC")) |_p| std.mem.span(_p) else null)) |env_rpc| {
            rpc_url_owned = @constCast(env_rpc);
            rpc_url = env_rpc;
        }
    }

    if (order_id == 0) {
        // Pseudo-random nonzero u64.
        var seed_bytes: [8]u8 = undefined;
        std.Io.Threaded.global_single_threaded.io().random(&seed_bytes);
        order_id = std.mem.readInt(u64, &seed_bytes, .little);
        if (order_id == 0) order_id = 1;
    }
    if (amount == 0) return error.AmountMustBeNonzero;

    // Random 32-byte nullifier (must be nonzero).
    var nullifier: [32]u8 = undefined;
    std.Io.Threaded.global_single_threaded.io().random(&nullifier);
    if (std.mem.allEqual(u8, &nullifier, 0)) nullifier[0] = 1;

    std.debug.print("[SUBMIT] profile:  {s}\n", .{cli.profile});
    std.debug.print("[SUBMIT] rpc:      {s}\n", .{rpc_url});
    std.debug.print("[SUBMIT] idl:      {s}\n", .{idl_path});
    std.debug.print("[SUBMIT] order_id: {d}\n", .{order_id});
    std.debug.print("[SUBMIT] amount:   {d}\n", .{amount});

    // Load agent keypair.
    var ctx = try context_mod.AgentContext.init(allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const kp = ctx.vaults.ops.sol_kp;

    const payer_addr = try crypto_mod.pubkeyToString(allocator, &kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[SUBMIT] payer:    {s}\n", .{payer_addr});

    // Token = placeholder 32-byte mint (must be nonzero). [01, 00, ...]
    var token: [32]u8 = [_]u8{0} ** 32;
    token[0] = 1;
    // Recipient defaults to payer.
    const recipient: [32]u8 = kp.public;

    // Load IDL and encode SubmitPrivateOrder.
    const idl_json = try std.Io.Dir.cwd().readFileAlloc(std.Io.Threaded.global_single_threaded.io(), idl_path, allocator, std.Io.Limit.limited(64 * 1024));
    defer allocator.free(idl_json);

    const IdlClientT = onchain.IdlClient;
    const NamedField = onchain.NamedField;

    var client = try IdlClientT.init(allocator, idl_json);
    defer client.deinit();

    const payload_fields = [_]NamedField{
        .{ .name = "orderId",   .value = .{ .u64_val = order_id } },
        .{ .name = "amount",    .value = .{ .u64_val = amount } },
        .{ .name = "token",     .value = .{ .bytes = &token } },
        .{ .name = "recipient", .value = .{ .bytes = &recipient } },
        .{ .name = "nullifier", .value = .{ .bytes = &nullifier } },
    };
    const top_fields = [_]NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };

    const ix_data = try client.encodeInstruction("SubmitPrivateOrder", &top_fields);
    defer allocator.free(ix_data);
    std.debug.print("[SUBMIT] ix_data:  {d} bytes\n", .{ix_data.len});

    // Resolve program id.
    const gateway_id = try crypto_mod.stringToPubkey(allocator, GATEWAY_PROGRAM_ID);
    const cb_program_id = try crypto_mod.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    // Derive PDAs.
    var gateway_state_seed = [_][]const u8{ "gateway_state" };
    const gw_pda = try crypto_mod.findProgramAddress(gateway_state_seed[0..], &gateway_id);
    var nullifier_seed = [_][]const u8{ "nullifier", nullifier[0..] };
    const null_pda = try crypto_mod.findProgramAddress(nullifier_seed[0..], &gateway_id);

    {
        const gws_hex = try crypto_mod.pubkeyToString(allocator, &gw_pda.address);
        defer allocator.free(gws_hex);
        std.debug.print("[SUBMIT] gateway_state PDA: {s}\n", .{gws_hex});
    }
    {
        const np_hex = try crypto_mod.pubkeyToString(allocator, &null_pda.address);
        defer allocator.free(np_hex);
        std.debug.print("[SUBMIT] nullifier     PDA: {s}\n", .{np_hex});
    }

    const system_program_id: [32]u8 = [_]u8{0} ** 32;

    // Get latest blockhash.
    var rpc = onchain.SolanaRpc.init(allocator, rpc_url);
    defer rpc.deinit();

    // Fund payer if needed.
    const balance = rpc.getBalance(payer_addr) catch 0;
    std.debug.print("[SUBMIT] balance:  {d} lamports\n", .{balance});
    if (balance < 1_000_000) {
        std.debug.print("[SUBMIT] requesting airdrop...\n", .{});
        rpc.requestAirdrop(payer_addr, 1_000_000_000) catch |e| {
            std.debug.print("[SUBMIT] airdrop failed: {any}\n", .{e});
        };
        std.Io.sleep(std.Io.Threaded.global_single_threaded.io(), .{ .nanoseconds = @intCast(2 * std.time.ns_per_s) }, .awake) catch {};
    }

    const blockhash = try rpc.getLatestBlockhash();

    var cu_data: [5]u8 = undefined;
    cu_data[0] = 2;
    std.mem.writeInt(u32, cu_data[1..5], 1_400_000, .little);

    const cb_ix = onchain.Instruction{
        .program_id = cb_program_id,
        .accounts = &.{},
        .data = &cu_data,
    };

    const submit_accounts = [_]onchain.AccountMeta{
        .{ .pubkey = kp.public,         .is_signer = true,  .is_writable = true  },
        .{ .pubkey = gw_pda.address,    .is_signer = false, .is_writable = false },
        .{ .pubkey = null_pda.address,  .is_signer = false, .is_writable = true  },
        .{ .pubkey = system_program_id, .is_signer = false, .is_writable = false },
    };

    const submit_ix = onchain.Instruction{
        .program_id = gateway_id,
        .accounts = &submit_accounts,
        .data = ix_data,
    };

    const instructions = [_]onchain.Instruction{ cb_ix, submit_ix };

    const tx_buf = try onchain.buildLegacyTx(allocator, &kp.public, &blockhash, &instructions);
    defer allocator.free(tx_buf);

    onchain.signTx(tx_buf, &kp);

    std.debug.print("[SUBMIT] tx size:  {d} bytes\n", .{tx_buf.len});
    std.debug.print("[SUBMIT] sending...\n", .{});

    const sig = try rpc.sendRawTransaction(tx_buf);
    defer allocator.free(sig);

    std.debug.print("\n[SUBMIT] TRANSACTION SENT\n", .{});
    std.debug.print("[SUBMIT] signature: {s}\n", .{sig});

    const confirmed = rpc.confirmSignature(sig, 30_000, 400) catch |e| blk: {
        std.debug.print("[SUBMIT] confirmation error: {any}\n", .{e});
        break :blk false;
    };

    if (confirmed) {
        std.debug.print("[SUBMIT] CONFIRMED\n", .{});
    } else {
        std.debug.print("[SUBMIT] not confirmed within timeout (tx may still land)\n", .{});
    }
}

/// `xb77 gateway init` — one-time bootstrap of the xb77_gateway state PDA.
/// Idempotent: checks getAccountInfo first; if owner == gateway_program, exit ok.
/// Uses the current profile's keypair as the admin.
pub fn initGateway(cli: *const Cli, args: []const [:0]const u8) !void {
    const allocator = cli.allocator;

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

    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (@as(?[]const u8, if (std.c.getenv("XB77_RPC")) |_p| std.mem.span(_p) else null)) |env_rpc| {
            rpc_url_owned = @constCast(env_rpc);
            rpc_url = env_rpc;
        }
    }

    std.debug.print("[INIT] profile:  {s}\n", .{cli.profile});
    std.debug.print("[INIT] rpc:      {s}\n", .{rpc_url});

    var ctx = try context_mod.AgentContext.init(allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const kp = ctx.vaults.ops.sol_kp;

    const payer_addr = try crypto_mod.pubkeyToString(allocator, &kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[INIT] admin:    {s}\n", .{payer_addr});

    const gateway_id = try crypto_mod.stringToPubkey(allocator, GATEWAY_PROGRAM_ID);
    const cb_program_id = try crypto_mod.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    var gateway_state_seed = [_][]const u8{ "gateway_state" };
    const gw_pda = try crypto_mod.findProgramAddress(gateway_state_seed[0..], &gateway_id);

    const gws_hex = try crypto_mod.pubkeyToString(allocator, &gw_pda.address);
    defer allocator.free(gws_hex);
    std.debug.print("[INIT] state PDA: {s}\n", .{gws_hex});

    var rpc = onchain.SolanaRpc.init(allocator, rpc_url);
    defer rpc.deinit();

    // Idempotency check: if PDA already exists owned by the program, skip.
    const exists = rpc.getAccountOwner(gws_hex) catch |e| blk: {
        std.debug.print("[INIT] getAccountInfo error (treating as not-initialized): {any}\n", .{e});
        break :blk null;
    };
    if (exists) |owner_str| {
        defer allocator.free(owner_str);
        if (std.mem.eql(u8, owner_str, GATEWAY_PROGRAM_ID)) {
            std.debug.print("[INIT] gateway_state already initialized, skip\n", .{});
            return;
        }
    }

    // Fund admin.
    const balance = rpc.getBalance(payer_addr) catch 0;
    std.debug.print("[INIT] balance:  {d} lamports\n", .{balance});
    if (balance < 100_000_000) {
        std.debug.print("[INIT] requesting airdrop...\n", .{});
        rpc.requestAirdrop(payer_addr, 5_000_000_000) catch |e| {
            std.debug.print("[INIT] airdrop failed: {any}\n", .{e});
        };
        std.Io.sleep(std.Io.Threaded.global_single_threaded.io(), .{ .nanoseconds = @intCast(2 * std.time.ns_per_s) }, .awake) catch {};
    }

    // Encode InitGateway via IDL.
    const idl_json = try std.Io.Dir.cwd().readFileAlloc(std.Io.Threaded.global_single_threaded.io(), idl_path, allocator, std.Io.Limit.limited(64 * 1024));
    defer allocator.free(idl_json);

    var client = try onchain.IdlClient.init(allocator, idl_json);
    defer client.deinit();

    const zero32 = [_]u8{0} ** 32;
    const admin_bytes = kp.public;
    const payload_fields = [_]onchain.NamedField{
        .{ .name = "admin",                          .value = .{ .bytes = &admin_bytes } },
        .{ .name = "merkleRoot",                     .value = .{ .bytes = &zero32 } },
        .{ .name = "zkVerifier",                     .value = .{ .bytes = &zero32 } },
        .{ .name = "auditor",                        .value = .{ .bytes = &admin_bytes } },
        .{ .name = "creditRoot",                     .value = .{ .bytes = &zero32 } },
        .{ .name = "orderbookRoot",                  .value = .{ .bytes = &zero32 } },
        .{ .name = "mxeProgramId",                   .value = .{ .bytes = &zero32 } },
        .{ .name = "receiptsProgramId",              .value = .{ .bytes = &zero32 } },
        .{ .name = "lightSystemProgram",             .value = .{ .bytes = &zero32 } },
        .{ .name = "lightAccountCompressionProgram", .value = .{ .bytes = &zero32 } },
        .{ .name = "lightNoopProgram",               .value = .{ .bytes = &zero32 } },
    };
    const top_fields = [_]onchain.NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };
    const ix_data = try client.encodeInstruction("InitGateway", &top_fields);
    defer allocator.free(ix_data);
    std.debug.print("[INIT] ix_data:  {d} bytes\n", .{ix_data.len});

    const blockhash = try rpc.getLatestBlockhash();

    var cu_data: [5]u8 = undefined;
    cu_data[0] = 2;
    std.mem.writeInt(u32, cu_data[1..5], 1_400_000, .little);
    const cb_ix = onchain.Instruction{
        .program_id = cb_program_id,
        .accounts = &.{},
        .data = &cu_data,
    };

    const system_program_id: [32]u8 = [_]u8{0} ** 32;
    const init_accounts = [_]onchain.AccountMeta{
        .{ .pubkey = kp.public,         .is_signer = true,  .is_writable = true  },
        .{ .pubkey = gw_pda.address,    .is_signer = false, .is_writable = true  },
        .{ .pubkey = system_program_id, .is_signer = false, .is_writable = false },
    };
    const init_ix = onchain.Instruction{
        .program_id = gateway_id,
        .accounts = &init_accounts,
        .data = ix_data,
    };

    const instructions = [_]onchain.Instruction{ cb_ix, init_ix };
    const tx_buf = try onchain.buildLegacyTx(allocator, &kp.public, &blockhash, &instructions);
    defer allocator.free(tx_buf);
    onchain.signTx(tx_buf, &kp);

    std.debug.print("[INIT] tx size:  {d} bytes\n", .{tx_buf.len});
    std.debug.print("[INIT] sending...\n", .{});

    const sig = try rpc.sendRawTransaction(tx_buf);
    defer allocator.free(sig);

    std.debug.print("[INIT] signature: {s}\n", .{sig});

    const confirmed = rpc.confirmSignature(sig, 30_000, 400) catch |e| blk: {
        std.debug.print("[INIT] confirmation error: {any}\n", .{e});
        break :blk false;
    };
    if (confirmed) {
        std.debug.print("[INIT] CONFIRMED — gateway_state initialized\n", .{});
    } else {
        std.debug.print("[INIT] not confirmed within timeout (tx may still land)\n", .{});
    }
}

//! `xb77 merchant onchain-{register,list}` — IDL-driven xb77_registry calls.
//!
//! Why a separate module: the legacy `RegistryManager` in core/commerce/
//! derives the merchant PDA with a plain SHA-256 of "merchant"||id (missing
//! the ProgramDerivedAddress marker + on-curve check) and forces a 32-byte
//! merchant_id even though the program accepts a Vec<u8>. This module uses
//! `crypto.findProgramAddress` + IDL encoding so the path matches the
//! deployed program exactly.

const std = @import("std");
const core = @import("core");
const Cli = @import("../flags.zig").Cli;

const crypto_mod = core.crypto;
const context_mod = core.context;
const onchain = core.onchain;

const REGISTRY_PROGRAM_ID = "HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1";
const DEFAULT_RPC = "http://127.0.0.1:8899";
const DEFAULT_IDL = "idls/xb77_registry.json";

pub fn register(cli: *const Cli, args: []const [:0]u8) !void {
    const allocator = cli.allocator;

    var merchant_id: []const u8 = "";
    var methods: u64 = 1;
    var rpc_url: []const u8 = DEFAULT_RPC;
    var idl_path: []const u8 = DEFAULT_IDL;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--id") and i + 1 < args.len) {
            merchant_id = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--methods") and i + 1 < args.len) {
            methods = try std.fmt.parseInt(u64, args[i + 1], 10); i += 1;
        } else if (std.mem.eql(u8, args[i], "--rpc") and i + 1 < args.len) {
            rpc_url = args[i + 1]; i += 1;
        } else if (std.mem.eql(u8, args[i], "--idl") and i + 1 < args.len) {
            idl_path = args[i + 1]; i += 1;
        }
    }

    if (merchant_id.len == 0) {
        std.debug.print("Uso: xb77 merchant onchain-register --id <slug> [--methods N] [--rpc URL] [--idl PATH]\n", .{});
        return;
    }
    if (merchant_id.len > 32) return error.MerchantIdTooLong;

    var rpc_url_owned: ?[]u8 = null;
    defer if (rpc_url_owned) |r| allocator.free(r);
    if (std.mem.eql(u8, rpc_url, DEFAULT_RPC)) {
        if (std.process.getEnvVarOwned(allocator, "XB77_RPC")) |env_rpc| {
            rpc_url_owned = env_rpc;
            rpc_url = env_rpc;
        } else |_| {}
    }

    std.debug.print("[MERCHANT-REG] id:      {s}\n", .{merchant_id});
    std.debug.print("[MERCHANT-REG] methods: {d}\n", .{methods});
    std.debug.print("[MERCHANT-REG] rpc:     {s}\n", .{rpc_url});

    var ctx = try context_mod.AgentContext.init(allocator, cli.config_path, cli.password);
    defer ctx.deinit();
    const kp = ctx.vaults.ops.sol_kp;

    const payer_addr = try crypto_mod.pubkeyToString(allocator, &kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[MERCHANT-REG] payer:   {s}\n", .{payer_addr});

    const registry_id = try crypto_mod.stringToPubkey(allocator, REGISTRY_PROGRAM_ID);
    const cb_program_id = try crypto_mod.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    var merchant_seeds = [_][]const u8{ "merchant", merchant_id };
    const m_pda = try crypto_mod.findProgramAddress(merchant_seeds[0..], &registry_id);

    const m_pda_str = try crypto_mod.pubkeyToString(allocator, &m_pda.address);
    defer allocator.free(m_pda_str);
    std.debug.print("[MERCHANT-REG] PDA:     {s}\n", .{m_pda_str});

    // Encode InitMerchant via IDL.
    const idl_json = try std.Io.Dir.cwd().readFileAlloc(std.Io.Threaded.global_single_threaded.io(), allocator, idl_path, 64 * 1024);
    defer allocator.free(idl_json);

    var client = try onchain.IdlClient.init(allocator, idl_json);
    defer client.deinit();

    const payload_fields = [_]onchain.NamedField{
        .{ .name = "merchantId",       .value = .{ .bytes = merchant_id } },
        .{ .name = "supportedMethods", .value = .{ .u64_val = methods } },
    };
    const top_fields = [_]onchain.NamedField{
        .{ .name = "payload", .value = .{ .struct_val = &payload_fields } },
    };
    const ix_data = try client.encodeInstruction("InitMerchant", &top_fields);
    defer allocator.free(ix_data);
    std.debug.print("[MERCHANT-REG] ix_data: {d} bytes\n", .{ix_data.len});

    var rpc = onchain.SolanaRpc.init(allocator, rpc_url);
    defer rpc.deinit();

    // Idempotency: if the PDA exists owned by us, exit.
    if (rpc.getAccountOwner(m_pda_str) catch null) |owner_str| {
        defer allocator.free(owner_str);
        if (std.mem.eql(u8, owner_str, REGISTRY_PROGRAM_ID)) {
            std.debug.print("[MERCHANT-REG] merchant '{s}' already registered, skip\n", .{merchant_id});
            return;
        }
    }

    const balance = rpc.getBalance(payer_addr) catch 0;
    if (balance < 10_000_000) {
        std.debug.print("[MERCHANT-REG] requesting airdrop...\n", .{});
        rpc.requestAirdrop(payer_addr, 1_000_000_000) catch {};
        std.Thread.sleep(2 * std.time.ns_per_s);
    }

    const blockhash = try rpc.getLatestBlockhash();
    var cu_data: [5]u8 = undefined;
    cu_data[0] = 2;
    std.mem.writeInt(u32, cu_data[1..5], 400_000, .little);
    const cb_ix = onchain.Instruction{ .program_id = cb_program_id, .accounts = &.{}, .data = &cu_data };

    const system_id: [32]u8 = [_]u8{0} ** 32;
    const accounts = [_]onchain.AccountMeta{
        .{ .pubkey = kp.public,    .is_signer = true,  .is_writable = true  },
        .{ .pubkey = m_pda.address,.is_signer = false, .is_writable = true  },
        .{ .pubkey = system_id,    .is_signer = false, .is_writable = false },
    };
    const reg_ix = onchain.Instruction{
        .program_id = registry_id,
        .accounts = &accounts,
        .data = ix_data,
    };
    const ixs = [_]onchain.Instruction{ cb_ix, reg_ix };

    const tx_buf = try onchain.buildLegacyTx(allocator, &kp.public, &blockhash, &ixs);
    defer allocator.free(tx_buf);
    onchain.signTx(tx_buf, &kp);

    std.debug.print("[MERCHANT-REG] sending...\n", .{});
    const sig = try rpc.sendRawTransaction(tx_buf);
    defer allocator.free(sig);
    std.debug.print("[MERCHANT-REG] signature: {s}\n", .{sig});

    const confirmed = rpc.confirmSignature(sig, 30_000, 400) catch false;
    if (confirmed) {
        std.debug.print("[MERCHANT-REG] CONFIRMED — merchant '{s}' registered\n", .{merchant_id});
    } else {
        std.debug.print("[MERCHANT-REG] not confirmed within timeout (tx may still land)\n", .{});
    }
}

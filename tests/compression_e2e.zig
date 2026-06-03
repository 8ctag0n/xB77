const std = @import("std");
const core = @import("core");
const types = core.types;
const crypto = core.crypto;
const solana = core.solana;
const tx_mod = core.tx;

const COMPRESSION_PROGRAM_ID = "6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN";
const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

fn envOr(map: *const std.process.Environ.Map, allocator: std.mem.Allocator, name: []const u8, default: []const u8) ![]u8 {
    if (map.get(name)) |val| {
        return try allocator.dupe(u8, val);
    }
    return try allocator.dupe(u8, default);
}

fn loadKeypair(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !types.Keypair {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    
    var read_buffer: [1024]u8 = undefined;
    var reader = file.reader(io, &read_buffer);
    const raw = try reader.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(raw);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();

    const arr = parsed.value.array;
    if (arr.items.len != 64) return error.InvalidKeypairLength;

    var kp: types.Keypair = undefined;
    for (arr.items, 0..) |item, i| kp.secret[i] = @intCast(item.integer);
    @memcpy(&kp.public, kp.secret[32..64]);
    return kp;
}

fn hexDecode32(hex: []const u8, out: *[32]u8) !void {
    if (hex.len != 64) return error.InvalidHexLength;
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        out[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
}

fn buildInstructionData(allocator: std.mem.Allocator) ![]u8 {
    var new_root: [32]u8 = undefined;
    try hexDecode32(NEW_ROOT_HEX, &new_root);

    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    // disc u32 LE = 0 (VerifyTransition variant)
    var disc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &disc_buf, 0, .little);
    try buf.appendSlice(allocator, &disc_buf);

    // old_root [32] — verify_transition() ignores this, send zeros
    try buf.appendNTimes(allocator, 0, 32);
    // new_root [32]
    try buf.appendSlice(allocator, &new_root);
    
    // index u64 LE = 0
    var idx_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &idx_buf, 0, .little);
    try buf.appendSlice(allocator, &idx_buf);
    
    // siblings len u64 LE = 0 (empty vec)
    try buf.appendSlice(allocator, &idx_buf);
    
    // amount u64 LE = 1
    var amt_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &amt_buf, 1, .little);
    try buf.appendSlice(allocator, &amt_buf);
    
    // type u8 = 0
    try buf.append(allocator, 0);
    // tx_hash [32] = zeros
    try buf.appendNTimes(allocator, 0, 32);

    const out = try buf.toOwnedSlice(allocator);
    std.debug.assert(out.len == 125);
    return out;
}

fn buildCompressionTx(
    allocator: std.mem.Allocator,
    signer: types.Pubkey,
    program_id: types.Pubkey,
    instruction_data: []const u8,
    recent_blockhash: types.Hash,
    cu_limit: u32,
) ![]u8 {
    const cb_program = try crypto.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    // Signatures (1 placeholder, filled by signTx)
    try tx_mod.appendCompactU16(allocator, &buf, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // Message header: 1 signer, 0 readonly signed, 2 readonly unsigned (program + cb_program)
    try buf.append(allocator, 1);
    try buf.append(allocator, 0);
    try buf.append(allocator, 2);

    // Account keys: signer (writable signer), program (readonly), cb_program (readonly)
    try tx_mod.appendCompactU16(allocator, &buf, 3);
    try buf.appendSlice(allocator, &signer);
    try buf.appendSlice(allocator, &program_id);
    try buf.appendSlice(allocator, &cb_program);

    // Recent blockhash
    try buf.appendSlice(allocator, &recent_blockhash);

    // Instructions (2)
    try tx_mod.appendCompactU16(allocator, &buf, 2);

    // ix0: ComputeBudget SetComputeUnitLimit
    try buf.append(allocator, 2); // program idx
    try tx_mod.appendCompactU16(allocator, &buf, 0); // accounts
    try tx_mod.appendCompactU16(allocator, &buf, 5); // data len
    try buf.append(allocator, 2); // discriminant
    var limit_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &limit_buf, cu_limit, .little);
    try buf.appendSlice(allocator, &limit_buf);

    // ix1: compression VerifyTransition
    try buf.append(allocator, 1);
    try tx_mod.appendCompactU16(allocator, &buf, 0);
    try tx_mod.appendCompactU16(allocator, &buf, @intCast(instruction_data.len));
    try buf.appendSlice(allocator, instruction_data);

    return buf.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    std.debug.print("\n=== xB77 COMPRESSION E2E (Zig) ===\n", .{});

    const rpc_url = try envOr(init.environ_map, allocator, "XB77_RPC", "http://127.0.0.1:8899");
    defer allocator.free(rpc_url);
    const keypair_path = try envOr(init.environ_map, allocator, "PAYER_KEYPAIR", "/home/exp1/.config/solana/xb77-deploy.json");
    defer allocator.free(keypair_path);

    std.debug.print("[E2E] RPC:           {s}\n", .{rpc_url});
    std.debug.print("[E2E] payer keypair: {s}\n", .{keypair_path});

    const payer_kp = try loadKeypair(io, allocator, keypair_path);
    const payer_addr = try crypto.pubkeyToString(allocator, &payer_kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[E2E] payer pubkey:  {s}\n", .{payer_addr});

    var sol_client = solana.SolanaClient.init(allocator, rpc_url);
    defer sol_client.deinit();

    const blockhash = try sol_client.getLatestBlockhash();
    const prog_pk = try crypto.stringToPubkey(allocator, COMPRESSION_PROGRAM_ID);
    const ix_data = try buildInstructionData(allocator);
    defer allocator.free(ix_data);

    const tx_bytes = try buildCompressionTx(allocator, payer_kp.public, prog_pk, ix_data, blockhash, 300_000);
    defer allocator.free(tx_bytes);

    const signed_tx = try solana.signTx(allocator, tx_bytes, &payer_kp);
    defer allocator.free(signed_tx);

    const sig = try sol_client.sendTransaction(signed_tx);
    std.debug.print("\n[E2E] Tx Sent! Signature: {s}\n", .{sig});
    std.debug.print("[E2E] Waiting for confirmation (10s)...\n", .{});
    
    try std.Io.sleep(io, .{ .nanoseconds = 10 * 1000 * 1000 * 1000 }, .awake);

    const status = try sol_client.getSignatureStatus(sig);
    std.debug.print("[E2E] Confirmation status: {any}\n", .{status});
}

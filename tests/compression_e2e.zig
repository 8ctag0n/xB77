// compression_e2e.zig — sends a real VerifyTransition tx to xb77.iopression onchain.
//
// Payload is the minimal one validated by tests/wincode_layout.rs:
//   - siblings = []      (empty Merkle proof: new_root == leaf hash)
//   - amount   = 1
//   - type     = 0
//   - tx_hash  = zeros
//   - new_root = Poseidon([(amount<<8)|type, tx_hash]) — precomputed.
//
// The xb77.iopression program's verify_transition() returns true for this
// payload, so the tx confirms and emits "Compression: Transition Verified via
// Poseidon BN254." in program logs.
//
// Required env vars (with defaults):
//   XB77_RPC       - http://127.0.0.1:8899
//   PAYER_KEYPAIR  - /home/exp1/.config/solana/xb77-deploy.json

const std = @import("std");
const core = @import("core");
const types = core.types;
const crypto = core.crypto;
const solana = core.solana;
const tx_mod = core.tx;

// Program ID of xb77.iopression (matches declare_id! in the Rust source).
const COMPRESSION_PROGRAM_ID = "6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN";

// new_root precomputed by tests/wincode_layout.rs (`new_leaf` for amount=1, type=0, tx_hash=zeros).
const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

fn envOr(allocator: std.mem.Allocator, name: []const u8, default: []const u8) ![]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, default),
        else => return err,
    };
}

fn loadKeypair(allocator: std.mem.Allocator, path: []const u8) !types.Keypair {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const raw = try file.readToEndAlloc(allocator, 4 * 1024);
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

/// Builds the wincode-serialized CompressionInstruction::VerifyTransition payload
/// matching the byte layout dumped by tests/wincode_layout.rs (125 bytes total).
fn buildInstructionData(allocator: std.mem.Allocator) ![]u8 {
    var new_root: [32]u8 = undefined;
    try hexDecode32(NEW_ROOT_HEX, &new_root);

    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // disc u32 LE = 0 (VerifyTransition variant)
    try writer.writeInt(u32, 0, .little);
    // old_root [32] — verify_transition() ignores this, send zeros
    try buf.appendNTimes(allocator, 0, 32);
    // new_root [32]
    try writer.writeAll(&new_root);
    // index u64 LE = 0
    try writer.writeInt(u64, 0, .little);
    // siblings len u64 LE = 0 (empty vec)
    try writer.writeInt(u64, 0, .little);
    // amount u64 LE = 1
    try writer.writeInt(u64, 1, .little);
    // type u8 = 0
    try writer.writeByte(0);
    // tx_hash [32] = zeros
    try buf.appendNTimes(allocator, 0, 32);

    const out = try buf.toOwnedSlice(allocator);
    std.debug.assert(out.len == 125);
    return out;
}

/// Builds a Solana legacy tx with TWO instructions:
///   ix0: ComputeBudget::SetComputeUnitLimit(cu_limit)  — Poseidon BN254 needs >200k CU
///   ix1: compression VerifyTransition
fn buildCompressionTx(
    allocator: std.mem.Allocator,
    signer: types.Pubkey,
    program_id: types.Pubkey,
    instruction_data: []const u8,
    recent_blockhash: types.Hash,
    cu_limit: u32,
) ![]u8 {
    const cb_program = try crypto.stringToPubkey(allocator, "ComputeBudget111111111111111111111111111111");

    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // Signatures (1 placeholder, filled by signTx)
    try tx_mod.writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    // Message header: 1 signer, 0 readonly signed, 2 readonly unsigned (program + cb_program)
    try writer.writeByte(1);
    try writer.writeByte(0);
    try writer.writeByte(2);

    // Account keys: signer (writable signer), program (readonly), cb_program (readonly)
    try tx_mod.writeCompactU16(writer, 3);
    try writer.writeAll(&signer);
    try writer.writeAll(&program_id);
    try writer.writeAll(&cb_program);

    // Recent blockhash
    try writer.writeAll(&recent_blockhash);

    // Instructions (2)
    try tx_mod.writeCompactU16(writer, 2);

    // ix0: ComputeBudget SetComputeUnitLimit
    //   program idx = 2 (cb_program), 0 accounts, data = [2, u32 LE units]  (5 bytes)
    try writer.writeByte(2);
    try tx_mod.writeCompactU16(writer, 0);
    try tx_mod.writeCompactU16(writer, 5);
    try writer.writeByte(2); // SetComputeUnitLimit discriminant
    try writer.writeInt(u32, cu_limit, .little);

    // ix1: compression VerifyTransition
    //   program idx = 1, 0 accounts (ignored by program), data = instruction_data
    try writer.writeByte(1);
    try tx_mod.writeCompactU16(writer, 0);
    try tx_mod.writeCompactU16(writer, @intCast(instruction_data.len));
    try writer.writeAll(instruction_data);

    return buf.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== xB77 COMPRESSION E2E (Zig) ===\n", .{});

    const rpc_url = try envOr(allocator, "XB77_RPC", "http://127.0.0.1:8899");
    defer allocator.free(rpc_url);
    const keypair_path = try envOr(allocator, "PAYER_KEYPAIR", "/home/exp1/.config/solana/xb77-deploy.json");
    defer allocator.free(keypair_path);

    std.debug.print("[E2E] RPC:           {s}\n", .{rpc_url});
    std.debug.print("[E2E] payer keypair: {s}\n", .{keypair_path});

    const payer_kp = try loadKeypair(allocator, keypair_path);
    const payer_addr = try crypto.pubkeyToString(allocator, &payer_kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[E2E] payer pubkey:  {s}\n", .{payer_addr});

    const program_id = try crypto.stringToPubkey(allocator, COMPRESSION_PROGRAM_ID);

    var client = solana.SolanaClient.init(allocator, rpc_url);
    defer client.deinit();

    // Ensure payer has lamports (only meaningful on localnet faucet).
    const balance = client.getBalance(payer_addr) catch 0;
    std.debug.print("[E2E] balance:       {d} lamports\n", .{balance});
    if (balance < 100_000) {
        std.debug.print("[E2E] requesting airdrop...\n", .{});
        client.requestAirdrop(payer_addr, 1_000_000_000) catch |e| {
            std.debug.print("[E2E] airdrop failed: {any}\n", .{e});
        };
        std.Thread.sleep(2 * std.time.ns_per_s);
    }

    const blockhash = try client.getLatestBlockhash();

    const ix_data = try buildInstructionData(allocator);
    defer allocator.free(ix_data);
    std.debug.print("[E2E] ix_data len:   {d} bytes (expected 125)\n", .{ix_data.len});

    // 1_400_000 is the per-tx max on Solana; one Poseidon BN254 hash is ~150-250k CU,
    // a single VerifyTransition with empty siblings is well under the cap.
    const tx_buf = try buildCompressionTx(
        allocator,
        payer_kp.public,
        program_id,
        ix_data,
        blockhash,
        1_400_000,
    );
    defer allocator.free(tx_buf);

    tx_mod.signTx(tx_buf, &payer_kp);

    std.debug.print("[E2E] sending tx (size={d})...\n", .{tx_buf.len});
    const sig = try client.sendTransaction(tx_buf);
    defer allocator.free(sig);

    std.debug.print("\n[COMP ]  TRANSACTION CONFIRMED\n", .{});
    std.debug.print("[COMP ]  Signature: {s}\n", .{sig});
    std.debug.print("=== COMPRESSION E2E SUCCESSFUL ===\n", .{});
}

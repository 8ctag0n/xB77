const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const tx_mod = @import("../protocol/tx.zig");
const solana = @import("solana.zig");

const TAG_INIT: u8 = 0;
const TAG_WRITE: u8 = 1;
const TAG_VERIFY: u8 = 2;

/// Per-tx chunk size. The Solana raw tx limit is 1232 B; 900 B leaves headroom
/// for the message header (sigs + accounts + blockhash + ix metadata + tag + offset).
pub const CHUNK_SIZE: usize = 900;

/// Buffer-PDA seed prefix shared with the on-chain xb77_zk_verifier program.
const SEED_BUF: []const u8 = "proof_buf";

/// System program pubkey (32 zero bytes).
const SYSTEM_PROGRAM: types.Pubkey = [_]u8{0} ** 32;

pub const UploadResult = struct {
    buffer_pda: types.Pubkey,
    bump: u8,
    salt: [8]u8,
    init_sig: []u8,
    verify_sig: []u8,
    /// Each chunk's tx signature, in order. Caller owns the slice + each entry.
    write_sigs: [][]u8,
};

/// Uploads `proof_bytes` to the verifier program's PDA buffer in chunks and
/// fires the verify ix. Mirrors `onchain/clients/zk_client/src/main.rs` 1:1.
pub fn uploadAndVerify(
    client: *solana.SolanaClient,
    verifier_program_id: types.Pubkey,
    payer_kp: *const types.Keypair,
    proof_bytes: []const u8,
) !UploadResult {
    const allocator = client.allocator;

    // Salt = first 8 bytes of a fresh blockhash. Buys us a unique PDA per run
    // so we never collide with a leftover buffer from a prior session.
    const bh0 = try client.getLatestBlockhash();
    var salt: [8]u8 = undefined;
    @memcpy(&salt, bh0[0..8]);

    // PDA derivation: seeds = ["proof_buf", payer.pubkey, salt]
    var seeds: [3][]const u8 = .{
        SEED_BUF,
        payer_kp.public[0..],
        salt[0..],
    };
    const pda = try crypto.findProgramAddress(seeds[0..], &verifier_program_id);

    const verifier_str = try crypto.pubkeyToString(allocator, &verifier_program_id);
    defer allocator.free(verifier_str);
    std.debug.print("\n[ZK-UP] verifier: {s}", .{verifier_str});
    std.debug.print("\n[ZK-UP] proof: {d} bytes, chunks of {d}", .{ proof_bytes.len, CHUNK_SIZE });
    const pda_str = try crypto.pubkeyToString(allocator, &pda.address);
    defer allocator.free(pda_str);
    std.debug.print("\n[ZK-UP] buffer PDA: {s} (bump={d})", .{ pda_str, pda.bump });

    // 1) INIT
    const init_sig = try sendInit(client, verifier_program_id, payer_kp, pda.address, salt, @intCast(proof_bytes.len));
    std.debug.print("\n[ZK-UP] init sig: {s}", .{init_sig});

    // 2) WRITE chunks
    var write_sigs = std.ArrayListUnmanaged([]u8){};
    errdefer {
        for (write_sigs.items) |s| allocator.free(s);
        write_sigs.deinit(allocator);
    }

    var offset: usize = 0;
    while (offset < proof_bytes.len) {
        const end = @min(offset + CHUNK_SIZE, proof_bytes.len);
        const sig = try sendWrite(
            client,
            verifier_program_id,
            payer_kp,
            pda.address,
            @intCast(offset),
            proof_bytes[offset..end],
        );
        std.debug.print("\n[ZK-UP] write {d}..{d} sig: {s}", .{ offset, end, sig });
        try write_sigs.append(allocator, sig);
        offset = end;
    }

    // 3) VERIFY
    const verify_sig = try sendVerify(client, verifier_program_id, payer_kp, pda.address);
    std.debug.print("\n[ZK-UP] verify sig: {s}", .{verify_sig});
    std.debug.print("\n[ZK-UP] (see validator logs for [ZK-JUDGE] verdict)\n", .{});

    return .{
        .buffer_pda = pda.address,
        .bump = pda.bump,
        .salt = salt,
        .init_sig = init_sig,
        .verify_sig = verify_sig,
        .write_sigs = try write_sigs.toOwnedSlice(allocator),
    };
}

// ---------------------------------------------------------------------------
// Per-instruction tx senders. Each one builds a legacy Solana tx with the
// account ordering required by Solana's message format:
//   writable signers > readonly signers > writable non-signers > readonly non-signers
// ---------------------------------------------------------------------------

fn sendInit(
    client: *solana.SolanaClient,
    program_id: types.Pubkey,
    payer_kp: *const types.Keypair,
    buffer_pda: types.Pubkey,
    salt: [8]u8,
    proof_len: u32,
) ![]u8 {
    const allocator = client.allocator;
    const blockhash = try client.getLatestBlockhash();

    // ix data: [TAG_INIT, salt(8), proof_len_le(4)]
    var ix_data: [1 + 8 + 4]u8 = undefined;
    ix_data[0] = TAG_INIT;
    @memcpy(ix_data[1..9], &salt);
    std.mem.writeInt(u32, ix_data[9..13], proof_len, .little);

    // Accounts: payer(s,w), buffer(w), system_program(r), program(r)
    const accounts = [_]types.Pubkey{ payer_kp.public, buffer_pda, SYSTEM_PROGRAM, program_id };
    const num_readonly_unsigned: u8 = 2; // system_program + program
    const program_idx: u8 = 3;
    const ix_account_idxs = [_]u8{ 0, 1, 2 };

    return try buildAndSend(allocator, client, payer_kp, blockhash, accounts[0..], num_readonly_unsigned, program_idx, ix_account_idxs[0..], ix_data[0..]);
}

fn sendWrite(
    client: *solana.SolanaClient,
    program_id: types.Pubkey,
    payer_kp: *const types.Keypair,
    buffer_pda: types.Pubkey,
    offset: u32,
    chunk: []const u8,
) ![]u8 {
    const allocator = client.allocator;
    const blockhash = try client.getLatestBlockhash();

    // ix data: [TAG_WRITE, offset_le(4), chunk...]
    const ix_data = try allocator.alloc(u8, 1 + 4 + chunk.len);
    defer allocator.free(ix_data);
    ix_data[0] = TAG_WRITE;
    std.mem.writeInt(u32, ix_data[1..5], offset, .little);
    @memcpy(ix_data[5..], chunk);

    // Accounts: payer(s,w), buffer(w), program(r)
    const accounts = [_]types.Pubkey{ payer_kp.public, buffer_pda, program_id };
    const num_readonly_unsigned: u8 = 1;
    const program_idx: u8 = 2;
    const ix_account_idxs = [_]u8{ 0, 1 };

    return try buildAndSend(allocator, client, payer_kp, blockhash, accounts[0..], num_readonly_unsigned, program_idx, ix_account_idxs[0..], ix_data);
}

fn sendVerify(
    client: *solana.SolanaClient,
    program_id: types.Pubkey,
    payer_kp: *const types.Keypair,
    buffer_pda: types.Pubkey,
) ![]u8 {
    const allocator = client.allocator;
    const blockhash = try client.getLatestBlockhash();

    const ix_data = [_]u8{TAG_VERIFY};

    // Accounts: payer(s,w), buffer(r), program(r)  -- buffer is readonly here.
    // Layout requires writable signers > readonly signers > writable non-signers
    // > readonly non-signers. With the buffer readonly + no writable non-signers,
    // it sits next to program in the readonly-unsigned tail.
    const accounts = [_]types.Pubkey{ payer_kp.public, buffer_pda, program_id };
    const num_readonly_unsigned: u8 = 2;
    const program_idx: u8 = 2;
    const ix_account_idxs = [_]u8{ 0, 1 };

    return try buildAndSend(allocator, client, payer_kp, blockhash, accounts[0..], num_readonly_unsigned, program_idx, ix_account_idxs[0..], ix_data[0..]);
}

/// Generic legacy-tx builder + sender. One instruction, single signer = payer.
fn buildAndSend(
    allocator: std.mem.Allocator,
    client: *solana.SolanaClient,
    payer_kp: *const types.Keypair,
    blockhash: types.Hash,
    accounts: []const types.Pubkey,
    num_readonly_unsigned: u8,
    program_idx: u8,
    ix_account_idxs: []const u8,
    ix_data: []const u8,
) ![]u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // 1 signature, reserved.
    try tx_mod.writeCompactU16(writer, 1);
    try buf.appendNTimes(allocator, 0, 64);

    const message_start = buf.items.len;

    // Message header.
    try writer.writeByte(1); // num_required_signatures
    try writer.writeByte(0); // num_readonly_signed
    try writer.writeByte(num_readonly_unsigned);

    // Account keys (compact-array).
    try tx_mod.writeCompactU16(writer, @intCast(accounts.len));
    for (accounts) |k| try buf.appendSlice(allocator, &k);

    // Recent blockhash.
    try buf.appendSlice(allocator, &blockhash);

    // 1 instruction.
    try tx_mod.writeCompactU16(writer, 1);
    try writer.writeByte(program_idx);

    // Account indices for this ix.
    try tx_mod.writeCompactU16(writer, @intCast(ix_account_idxs.len));
    for (ix_account_idxs) |i| try writer.writeByte(i);

    // Ix data.
    try tx_mod.writeCompactU16(writer, @intCast(ix_data.len));
    try buf.appendSlice(allocator, ix_data);

    // Sign over the message slice and patch into the signature slot.
    const message = buf.items[message_start..];
    const signature = crypto.sign(message, payer_kp);
    @memcpy(buf.items[1..65], &signature);

    const sig = try client.sendTransaction(buf.items);
    // Poll until the validator has actually applied the tx; otherwise the
    // next ix's preflight simulates against stale state (e.g. the buffer
    // PDA created by INIT looks "not yet existing" to WRITE preflight, and
    // the program returns AccountDataTooSmall).
    try waitForConfirmation(client, sig);
    return sig;
}

const CONFIRM_POLL_MS: u64 = 250;
const CONFIRM_TIMEOUT_MS: u64 = 30_000;

fn waitForConfirmation(client: *solana.SolanaClient, signature: []const u8) !void {
    const allocator = client.allocator;
    var elapsed: u64 = 0;
    while (elapsed < CONFIRM_TIMEOUT_MS) {
        const payload = try std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","id":1,"method":"getSignatureStatuses","params":[["{s}"], {{"searchTransactionHistory":true}}]}}
        , .{signature});
        defer allocator.free(payload);

        var response = try client.http_client.post(client.endpoint, payload);
        defer response.deinit();

        if (std.json.parseFromSlice(std.json.Value, allocator, response.body, .{ .ignore_unknown_fields = true })) |parsed| {
            defer parsed.deinit();
            if (parsed.value.object.get("result")) |result| {
                if (result.object.get("value")) |value| {
                    const arr = value.array;
                    if (arr.items.len > 0 and arr.items[0] == .object) {
                        const status = arr.items[0].object;
                        if (status.get("err")) |err_v| {
                            if (err_v != .null) {
                                std.debug.print("\n[ZK-UP] tx {s} failed: {any}", .{ signature, err_v });
                                return error.TransactionFailed;
                            }
                        }
                        if (status.get("confirmationStatus")) |cs| {
                            if (cs == .string and (std.mem.eql(u8, cs.string, "confirmed") or std.mem.eql(u8, cs.string, "finalized"))) {
                                return;
                            }
                        }
                    }
                }
            }
        } else |_| {}

        std.Thread.sleep(CONFIRM_POLL_MS * std.time.ns_per_ms);
        elapsed += CONFIRM_POLL_MS;
    }
    return error.ConfirmationTimeout;
}

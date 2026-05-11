// End-to-end runner for the Zig-native zk_uploader.
//
// Mirrors what onchain/clients/zk_client (the Rust fallback) does, but using
// core/chain/zk_uploader.zig. Designed to run against a local Agave validator
// with the xb77_zk_verifier program already deployed.
//
// Required env vars:
//   VERIFIER_PROGRAM_ID  - base58 pubkey of the deployed verifier
// Optional env vars (with defaults):
//   RPC_URL              - http://127.0.0.1:8899
//   PROOF_PATH           - circuits/zk_receipt/proofs/zk_receipt.proof
//   PAYER_KEYPAIR        - /tmp/xb77_payer.json   (Solana CLI JSON format)

const std = @import("std");
const core = @import("core");
const solana = core.solana;
const types = core.types;
const crypto = core.crypto;
const zk_uploader = core.chain.zk_uploader;

fn envOr(allocator: std.mem.Allocator, name: []const u8, default: []const u8) ![]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, default),
        else => return err,
    };
}

/// Loads a Solana CLI-style keypair: a JSON array of 64 bytes, where the
/// first 32 are the ed25519 seed and the last 32 are the public key.
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
    for (arr.items, 0..) |item, i| {
        kp.secret[i] = @intCast(item.integer);
    }
    @memcpy(&kp.public, kp.secret[32..64]);
    return kp;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    std.debug.print("\n=== xB77 ZK UPLOAD E2E (Zig) ===\n", .{});

    const rpc_url = try envOr(allocator, "RPC_URL", "http://127.0.0.1:8899");
    defer allocator.free(rpc_url);
    const proof_path = try envOr(allocator, "PROOF_PATH", "circuits/zk_receipt/proofs/zk_receipt.proof");
    defer allocator.free(proof_path);
    const keypair_path = try envOr(allocator, "PAYER_KEYPAIR", "/tmp/xb77_payer.json");
    defer allocator.free(keypair_path);
    const verifier_id_str = std.process.getEnvVarOwned(allocator, "VERIFIER_PROGRAM_ID") catch {
        std.debug.print("[E2E]  VERIFIER_PROGRAM_ID env var is required\n", .{});
        return error.MissingVerifierProgramId;
    };
    defer allocator.free(verifier_id_str);

    std.debug.print("[E2E] RPC:           {s}\n", .{rpc_url});
    std.debug.print("[E2E] verifier:      {s}\n", .{verifier_id_str});
    std.debug.print("[E2E] proof file:    {s}\n", .{proof_path});
    std.debug.print("[E2E] payer keypair: {s}\n", .{keypair_path});

    const verifier_id = try crypto.stringToPubkey(allocator, verifier_id_str);
    const payer_kp = try loadKeypair(allocator, keypair_path);
    const payer_addr = try crypto.pubkeyToString(allocator, &payer_kp.public);
    defer allocator.free(payer_addr);
    std.debug.print("[E2E] payer pubkey:  {s}\n", .{payer_addr});

    const proof_file = try std.fs.cwd().openFile(proof_path, .{});
    defer proof_file.close();
    const proof_bytes = try proof_file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(proof_bytes);
    std.debug.print("[E2E] proof bytes:   {d}\n", .{proof_bytes.len});

    var client = solana.SolanaClient.init(allocator, rpc_url);
    defer client.deinit();

    const balance = client.getBalance(payer_addr) catch |err| {
        std.debug.print("[E2E]  getBalance failed: {any}\n", .{err});
        return err;
    };
    std.debug.print("[E2E] payer balance: {d} lamports\n", .{balance});
    if (balance == 0) {
        std.debug.print("[E2E]  payer has 0 SOL; airdrop and retry\n", .{});
        return error.PayerNotFunded;
    }

    const result = zk_uploader.uploadAndVerify(&client, verifier_id, &payer_kp, proof_bytes) catch |err| {
        std.debug.print("\n[E2E]  uploadAndVerify failed: {any}\n", .{err});
        return err;
    };
    defer {
        allocator.free(result.init_sig);
        allocator.free(result.verify_sig);
        for (result.write_sigs) |s| allocator.free(s);
        allocator.free(result.write_sigs);
    }

    std.debug.print("\n[E2E]  uploadAndVerify completed\n", .{});
    std.debug.print("[E2E]    init:   {s}\n", .{result.init_sig});
    std.debug.print("[E2E]    chunks: {d}\n", .{result.write_sigs.len});
    std.debug.print("[E2E]    verify: {s}\n", .{result.verify_sig});
    std.debug.print("[E2E] (validator logs should show [ZK-JUDGE] verdict: GREEN)\n", .{});
}

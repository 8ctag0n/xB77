const std = @import("std");
const core = @import("core");
const solana = core.solana;
const types = core.types;
const crypto = core.crypto;
const zk_uploader = core.chain.zk_uploader;

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
    var kp: types.Keypair = undefined;
    for (arr.items, 0..) |item, i| kp.secret[i] = @intCast(item.integer);
    @memcpy(&kp.public, kp.secret[32..64]);
    return kp;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    std.debug.print("\n=== xB77 ZK PROOF UPLOADER E2E ===\n", .{});

    const rpc_url = try envOr(init.environ_map, allocator, "RPC_URL", "http://127.0.0.1:8899");
    defer allocator.free(rpc_url);
    const keypair_path = try envOr(init.environ_map, allocator, "PAYER_KEYPAIR", "/home/exp1/.config/solana/xb77-deploy.json");
    defer allocator.free(keypair_path);

    const payer_kp = try loadKeypair(io, allocator, keypair_path);
    
    var sol_client = solana.SolanaClient.init(allocator, rpc_url);
    defer sol_client.deinit();

    // 1. Cargar una prueba mock (Groth16 de 128 bytes)
    var mock_proof: [128]u8 = [_]u8{0x42} ** 128;
    
    std.debug.print("[E2E] Iniciando subida de prueba ZK (128 bytes)...\n", .{});
    const verifier_program_id = try crypto.stringToPubkey(allocator, "73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3");
    const result = try zk_uploader.uploadAndVerify(&sol_client, verifier_program_id, &payer_kp, &mock_proof);
    
    const pda_str = try crypto.pubkeyToString(allocator, &result.buffer_pda);
    defer allocator.free(pda_str);
    std.debug.print("[E2E] ✅ Prueba subida con éxito!\n", .{});
    std.debug.print("[E2E] PDA de la prueba: {s}\n", .{pda_str});
}

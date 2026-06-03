const std = @import("std");
const core = @import("core");
const store = core.store;
const types = core.types;
const solana = core.solana;
const tx = core.tx;
const crypto = core.crypto;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    std.debug.print("\n=== xB77 SOVEREIGN ANCHOR E2E TEST ===", .{});

    // 1. Generar la identidad del Agente
    const agent_kp = crypto.generateKeypair();
    const agent_address = try crypto.encodeBase58(allocator, &agent_kp.public);
    defer allocator.free(agent_address);
    std.debug.print("\n[AGENT ]  Identity Generated: {s}", .{agent_address});

    // 2. Levantar el Sovereign Store (Memoria Persistente)
    const test_path = "./.test_e2e_anchor";
    defer std.Io.Dir.cwd().deleteTree(std.Io.Threaded.global_single_threaded.io(), test_path) catch {};
    
    var s = try store.Store.init(allocator, test_path);
    defer s.deinit();

    // Generar actividad en el Agente para alterar el estado del árbol
    try s.record(.{
        .timestamp = 100,
        .chain = .solana,
        .entry_type = .match,
        .description = "Agent Onboarding",
        .tx_hash = "local_init",
    });
    
    const root = s.tree.getRoot();
    const root_hex = std.fmt.bytesToHex(root, .lower);
    std.debug.print("\n[STATE ]  Sovereign Root generated: 0x{s}", .{root_hex});

    // 3. Conexión al Validador
    const endpoint = "http://127.0.0.1:8899";
    var client = solana.SolanaClient.init(allocator, endpoint);
    defer client.deinit();

    // 4. Pedir Fondeo (Airdrop) y esperar confirmación
    try client.requestAirdrop(agent_address, 1_000_000_000); // 1 SOL
    std.debug.print("\n[SOLANA]  Waiting for airdrop confirmation...", .{});
    
    var balance: u64 = 0;
    var retries: usize = 0;
    while (retries < 10) : (retries += 1) {
        std.Thread.sleep(1 * std.time.ns_per_s);
        balance = try client.getBalance(agent_address);
        if (balance > 0) break;
        std.debug.print(".", .{});
    }

    std.debug.print("\n[SOLANA]  Agent Balance: {d} lamports", .{balance});
    if (balance == 0) return error.FundingFailed;

    // 5. Armar la Transacción Soberana
    std.debug.print("\n[SOLANA]  Preparing Sovereign Anchor Transaction...", .{});
    const blockhash = try client.getLatestBlockhash();
    
    // Nuestro "Data Availability" por ahora: un Memo con la raíz firmada
    const memo_data = try std.fmt.allocPrint(allocator, "xB77 Anchor: 0x{s}", .{root_hex});
    defer allocator.free(memo_data);

    const tx_buf = try tx.buildMemoTx(allocator, agent_kp.public, memo_data, blockhash);
    defer allocator.free(tx_buf);

    // Firmar la transacción in-place
    tx.signTx(tx_buf, &agent_kp);

    // 6. Enviar a la blockchain
    const tx_signature = try client.sendTransaction(tx_buf);
    defer allocator.free(tx_signature);
    
    std.debug.print("\n[SOLANA]  TRANSACTION SENT!", .{});
    std.debug.print("\n[SOLANA]  Signature: {s}", .{tx_signature});
    std.debug.print("\n=== E2E TEST SUCCESSFUL ===\n", .{});
}

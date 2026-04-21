const std = @import("std");
const core = @import("core");
const tx = core.tx;
const crypto = core;
const types = core.types;

test "EVM: Build EIP-1559 Transaction" {
    const allocator = std.testing.allocator;
    
    const kp = try crypto.generateEthKeypair();
    const to_addr = [_]u8{0x12, 0x34} ++ ([_]u8{0} ** 18);
    
    const eth_tx = tx.EthEip1559Tx{
        .chain_id = 1,
        .nonce = 0,
        .max_priority_fee_per_gas = 1000000000, // 1 gwei
        .max_fee_per_gas = 2000000000, // 2 gwei
        .gas_limit = 21000,
        .to = to_addr,
        .value = 1000000000000000000, // 1 ETH
        .data = &[_]u8{},
    };
    
    const signed_tx = try tx.buildEthEip1559Tx(allocator, eth_tx, &kp);
    defer allocator.free(signed_tx);
    
    try std.testing.expect(signed_tx[0] == 0x02);
    try std.testing.expect(signed_tx.len > 100);
}

test "Solana: Build Simple Transfer" {
    const allocator = std.testing.allocator;
    
    const from = [_]u8{1} ** 32;
    const to = [_]u8{2} ** 32;
    const blockhash = [_]u8{3} ** 32;
    
    const tx_bytes = try tx.buildTransferTx(allocator, from, to, 1000, blockhash);
    defer allocator.free(tx_bytes);
    
    // Verificaciones básicas de la estructura Solana
    try std.testing.expect(tx_bytes[0] == 1); // 1 firma
    try std.testing.expect(tx_bytes.len > 100);
    
    // El blockhash debería estar en una posición predecible (después del header y las keys)
    // 1 (num_sigs) + 64 (sig) + 3 (header) + 1 (num_keys) + (num_keys * 32)
    // Para simple transfer: 3 keys (from, to, system_program)
    const expected_blockhash_pos = 1 + 64 + 3 + 1 + (3 * 32);
    try std.testing.expectEqualSlices(u8, &blockhash, tx_bytes[expected_blockhash_pos .. expected_blockhash_pos + 32]);
}

test "Solana: Build Multi-Transfer with Priority Fee" {
    const allocator = std.testing.allocator;
    
    const from = [_]u8{1} ** 32;
    const to1 = [_]u8{2} ** 32;
    const to2 = [_]u8{4} ** 32;
    const blockhash = [_]u8{3} ** 32;
    
    const transfers = [_]tx.Transfer{
        .{ .to = to1, .lamports = 1000 },
        .{ .to = to2, .lamports = 500 },
    };
    
    const tx_bytes = try tx.buildMultiTransferTx(allocator, from, &transfers, blockhash, 10000);
    defer allocator.free(tx_bytes);
    
    try std.testing.expect(tx_bytes[0] == 1);
    
    // Debería haber 5 keys: from, to1, to2, system_program, compute_budget
    try std.testing.expect(tx_bytes[1 + 64 + 3] == 5);
}

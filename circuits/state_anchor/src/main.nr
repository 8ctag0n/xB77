use dep::std;

fn main(
    initial_root: pub Field,
    final_root: pub Field,
    indices: [u64; 5],
    
    // Pre-images of new_leaves
    amounts: [u64; 5],
    entry_types: [u8; 5],
    tx_hashes: [Field; 5],

    siblings: [[Field; 14]; 5],

    // Public Output for Solana (Total Infra Tax Verification)
    total_tax_collected: pub u64
) {
    let mut current_tax: u64 = 0;
    let mut current_root = initial_root;

    for i in 0..5 {
        // 1. Verify and accumulate Infra Tax (2.011%)
        current_tax += (amounts[i] * 2011) / 100000;

        // 2. Reconstruct new_leaf from pre-image.
        // Pack amount (64 bits) and entry_type (8 bits): (amount << 8) | entry_type.
        // Computed in Field arithmetic (Noir has no u128); since entry_type < 256
        // this equals amount*256 + entry_type bit-for-bit (matches store.zig poseidonHash).
        let amount_combined = (amounts[i] as Field) * 256 + (entry_types[i] as Field);
        let new_leaf = std::hash::poseidon::bn254::hash_2([amount_combined, tx_hashes[i]]);

        // 3. Verify transition: current_root must have an empty leaf at indices[i]
        // (In xB77 Sovereign CMT, appends always replace an empty leaf)
        let mut check_old_root = 0; // Empty leaf is Field 0
        for j in 0..14 {
            let bit = (indices[i] >> (j as u8)) & 1;
            if bit == 1 {
                check_old_root = std::hash::poseidon::bn254::hash_2([siblings[i][j], check_old_root]);
            } else {
                check_old_root = std::hash::poseidon::bn254::hash_2([check_old_root, siblings[i][j]]);
            }
        }
        assert(check_old_root == current_root);

        // 4. Compute next root with the new leaf
        let mut next_root = new_leaf;
        for j in 0..14 {
            let bit = (indices[i] >> (j as u8)) & 1;
            if bit == 1 {
                next_root = std::hash::poseidon::bn254::hash_2([siblings[i][j], next_root]);
            } else {
                next_root = std::hash::poseidon::bn254::hash_2([next_root, siblings[i][j]]);
            }
        }
        current_root = next_root;
    }

    // Final Verifications
    assert(current_root == final_root);
    assert(current_tax == total_tax_collected);
}

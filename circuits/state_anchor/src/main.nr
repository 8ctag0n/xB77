use dep::std;

fn main(
    old_root: pub Field,
    new_root: pub Field,
    index: pub u64,
    old_leaf: Field,
    
    // Pre-image of new_leaf (Sovereign Entry)
    amount: u64,
    entry_type: u8,
    tx_hash_preimage: Field,

    siblings: [Field; 14],

    // Public Output for Solana (Infra Tax Verification)
    tax_collected: pub u64
) {
    // 1. Verify Infra Tax (2.011%)
    // En Noir, la división de enteros trunca como en Zig.
    assert(tax_collected == (amount * 2011) / 100000);

    // 2. Reconstruct new_leaf from pre-image
    // El empaquetamiento debe coincidir exactamente con store.zig
    let amount_combined = ((amount as u128) << 8 | (entry_type as u128)) as Field;
    let new_leaf = std::hash::poseidon::bn254::hash_2([amount_combined, tx_hash_preimage]);

    // 3. Verify old_leaf was in old_root
    let mut current_old = old_leaf;
    for i in 0..14 {
        let bit = (index >> (i as u8)) & 1;
        if bit == 1 {
            current_old = std::hash::poseidon::bn254::hash_2([siblings[i], current_old]);
        } else {
            current_old = std::hash::poseidon::bn254::hash_2([current_old, siblings[i]]);
        }
    }
    assert(current_old == old_root);

    // 4. Verify new_leaf is in new_root with the same siblings
    let mut current_new = new_leaf;
    for i in 0..14 {
        let bit = (index >> (i as u8)) & 1;
        if bit == 1 {
            current_new = std::hash::poseidon::bn254::hash_2([siblings[i], current_new]);
        } else {
            current_new = std::hash::poseidon::bn254::hash_2([current_new, siblings[i]]);
        }
    }
    assert(current_new == new_root);
}

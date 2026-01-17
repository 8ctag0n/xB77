use dep::poseidon::poseidon::bn254::hash_2 as poseidon_hash;

fn main(
    root: pub Field, 
    order_id: pub Field,
    nullifier: pub Field,
    agent_secret: Field, 
    agent_salt: Field,
    merkle_path: [Field; 3], 
    merkle_index: Field
) {
    let index_u32 = merkle_index as u32;
    assert(index_u32 < 8);

    let leaf = poseidon_hash([agent_secret, agent_salt]);
    let computed_nullifier = poseidon_hash([agent_secret, order_id]);
    
    let mut current = leaf;

    for i in 0..3 {
        let path_bit = (index_u32 >> i) & 1;
        let elem = merkle_path[i];
        if path_bit == 0 {
            current = poseidon_hash([current, elem]);
        } else {
            current = poseidon_hash([elem, current]);
        }
    }

    if nullifier != 0 {
        assert(nullifier == computed_nullifier);
    }
    assert(current == root);
}

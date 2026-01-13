use dep::std::hash::poseidon::bn254::hash_2;

fn main(
    root: pub Field, 
    agent_secret: Field, 
    agent_salt: Field,
    merkle_path: [Field; 3], 
    merkle_index: Field
) {
    let index_u32 = merkle_index as u32;
    assert(index_u32 < 8);

    let leaf = hash_2([agent_secret, agent_salt]);
    
    let mut current = leaf;

    for i in 0..3 {
        let path_bit = (index_u32 >> i) & 1;
        let elem = merkle_path[i];
        if path_bit == 0 {
            current = hash_2([current, elem]);
        } else {
            current = hash_2([elem, current]);
        }
    }

    assert(current == root);
}

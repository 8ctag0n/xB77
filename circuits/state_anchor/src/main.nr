use dep::std;

fn main(
    root: pub Field,
    index: pub u64,
    leaf: Field,
    siblings: [Field; 14]
) {
    let mut current = leaf;

    for i in 0..14 {
        let bit = (index >> (i as u8)) & 1;
        
        // Poseidon hash_2: recibe [Field; 2] y devuelve un Field
        // Es exactamente lo que hace nuestro Poseidon.hash2(a, b) en Zig
        if bit == 1 {
            current = std::hash::poseidon::bn254::hash_2([siblings[i], current]);
        } else {
            current = std::hash::poseidon::bn254::hash_2([current, siblings[i]]);
        }
    }

    assert(current == root);
}

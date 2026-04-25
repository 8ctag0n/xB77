use dep::std;

fn main(
    root: pub [u8; 32],
    index: pub u64,
    leaf: [u8; 32],
    siblings: [[u8; 32]; 14]
) {
    let mut current = leaf;

    for i in 0..14 {
        let bit = (index >> (i as u8)) & 1;
        
        let mut input = [0; 64];
        if bit == 1 {
            for j in 0..32 {
                input[j] = siblings[i][j];
                input[j + 32] = current[j];
            }
        } else {
            for j in 0..32 {
                input[j] = current[j];
                input[j + 32] = siblings[i][j];
            }
        }
        
        current = std::hash::keccak256(input, 64);
    }

    assert(current == root);
}

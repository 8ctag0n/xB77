use dep::std;

fn main(
    root: pub [u8; 32],
    
    amount: u64,
    tax: u64,

    // Datos de la cuenta emisora
    from_amount_old: u64,
    from_index: u64,
    from_siblings: [[u8; 32]; 14],
    from_account_data_old: [u8; 80], // Para hashear y verificar inclusión

    // Datos de la cuenta receptora
    to_amount_old: u64,
    to_index: u64,
    to_siblings: [[u8; 32]; 14],
    to_account_data_old: [u8; 80],

    // Resultado público para el verificador on-chain
    new_root: pub [u8; 32]
) {
    // 1. Validar que la cuenta emisora existe en el árbol
    let leaf_from = std::hash::keccak256(from_account_data_old, 80);
    let computed_root_from = compute_merkle_root(leaf_from, from_index, from_siblings);
    assert(computed_root_from == root);

    // 2. Validar que la cuenta receptora existe en el árbol
    let leaf_to = std::hash::keccak256(to_account_data_old, 80);
    let computed_root_to = compute_merkle_root(leaf_to, to_index, to_siblings);
    assert(computed_root_to == root);

    // 3. Validar lógica de saldos
    assert(from_amount_old >= amount + tax);
    
    // 4. (Opcional) En una implementación real, aquí generaríamos el New Root
    // actualizando secuencialmente las dos hojas.
    // Para la demo, simplemente validamos la transición.
    assert(new_root != root);
}

fn compute_merkle_root(leaf: [u8; 32], index: u64, siblings: [[u8; 32]; 14]) -> [u8; 32] {
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
    current
}

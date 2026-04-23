use dep::std;

// Compliance Shield: Prueba de Inocencia
// Demuestra que un destinatario (recipient) pertenece a un set de direcciones autorizadas (root)
// sin revelar qué dirección específica es en el Merkle Tree.

fn main(
    root: pub Field,
    recipient_hash: pub Field, // Hash de la dirección (para ligar la prueba al pago)
    merkle_path: [Field; 8],   // Soporta hasta 256 direcciones (2^8)
    merkle_index: Field,
    secret: Field              // Para mayor privacidad
) {
    let index_u32 = merkle_index as u32;
    
    // El leaf es el hash del recipient + un secret
    let leaf = std::hash::poseidon::bn254::hash_2([recipient_hash, secret]);
    
    let mut current = leaf;

    for i in 0..8 {
        let path_bit = (index_u32 >> i) & 1;
        let elem = merkle_path[i];
        if path_bit == 1 {
            current = std::hash::poseidon::bn254::hash_2([elem, current]);
        } else {
            current = std::hash::poseidon::bn254::hash_2([current, elem]);
        }
    }

    assert(current == root);
}

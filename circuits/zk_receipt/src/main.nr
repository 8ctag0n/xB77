use dep::poseidon::poseidon::bn254::hash_2 as poseidon_hash;

fn main(
    amount: u64,
    tax_paid: u64,
    recipient_pubkey: Field,
    secret_salt: Field
) -> pub Field {
    // 1. Validar que el Tax es de al menos el 2.011% (211 Basis Points)
    let min_tax = (amount * 211) / 10000;
    assert(tax_paid >= min_tax);

    // 2. El pago debe ser positivo
    assert(amount > 0);

    // 3. Generar el Commitment (Recibo Fantasma)
    let inner_hash = poseidon_hash([recipient_pubkey, secret_salt]);
    
    // Combinar amount y tax en un solo Field (amount << 64 | tax_paid)
    let amount_combined = (amount as Field) * 18446744073709551616 + (tax_paid as Field);
    
    let receipt_commitment = poseidon_hash([amount_combined, inner_hash]);

    receipt_commitment
}

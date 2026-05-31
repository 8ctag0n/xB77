use dep::poseidon::poseidon::bn254::hash_2 as poseidon_hash;

// Ghost Receipt Circuit for Arc Network
// Proves a 2.011% tax was paid while keeping the amount hidden.
fn main(
    amount: u64,
    tax_paid: u64,
    recipient_address: Field, // EVM address as Field
    secret_salt: Field
) -> pub Field {
    // 1. Validate 2.011% tax (2011/100000)
    let min_tax = (amount * 2011) / 100000;
    assert(tax_paid >= min_tax);

    // 2. Amount must be positive
    assert(amount > 0);

    // 3. Generate Commitment for Arc Settlement
    let inner_hash = poseidon_hash([recipient_address, secret_salt]);
    
    let amount_combined = (amount as Field) * 18446744073709551616 + (tax_paid as Field);
    
    let receipt_commitment = poseidon_hash([amount_combined, inner_hash]);

    receipt_commitment
}

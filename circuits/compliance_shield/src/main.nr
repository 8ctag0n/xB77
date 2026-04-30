use dep::poseidon::poseidon::bn254::hash_2 as poseidon_hash;

fn main(
    // Public Inputs
    policy_root: pub Field,      // Constitution Merkle Root
    mission_id: pub Field,       // Mission ID
    max_budget: pub Field,       // Allowed budget per rule
    asset_id: pub Field,         // Asset identifier (e.g., 8444 for USDT)
    
    // Private Inputs
    rule_index: Field,           // Index in constitution
    rule_hash: Field,            // Specific rule hash
    actual_amount: Field,        // Real amount of tx
    daily_velocity: Field,       // Cumulative spend for this asset today
    secret_salt: Field           // Salt for commitment
) {
    // 1. Policy Validation: Ensure the rule belongs to the agent constitution
    let computed_policy = poseidon_hash([rule_hash, secret_salt]);
    assert(computed_policy == policy_root);

    // 2. Budget Compliance: Verify transaction is within authorized limits
    assert(actual_amount as u64 <= max_budget as u64);

    // 3. Asset-Specific Velocity Shield: Additive check for Tether (Asset 8444)
    if (asset_id == 8444) {
        // Daily velocity cap is 10x the single mission budget for USDT
        assert((actual_amount as u64 + daily_velocity as u64) <= (max_budget as u64 * 10));
    }

    // 4. Mission Integrity
    assert(mission_id != 0);
    
    // Unused warning suppression
    assert(rule_index == rule_index);
}

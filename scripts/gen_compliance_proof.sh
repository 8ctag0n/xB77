#!/usr/bin/env bash
# xB77 ZK-Policy Prover Helper
# Usage: ./gen_compliance_proof.sh <policy_root> <mission_id> <max_budget> <actual_amount> <rule_hash>

set -euo pipefail

POLICY_ROOT=$1
MISSION_ID=$2
MAX_BUDGET=$3
ACTUAL_AMOUNT=$4
RULE_HASH=$5
SALT="0x0000000000000000000000000000000000000000000000000000000000000000"

# Navigate to the circuit directory
cd "$(dirname "$0")/../circuits/compliance_shield"

# Generate Prover.toml
cat <<EOF > Prover.toml
policy_root = "$POLICY_ROOT"
mission_id = "$MISSION_ID"
max_budget = $MAX_BUDGET
actual_amount = $ACTUAL_AMOUNT
rule_index = 0
rule_hash = "$RULE_HASH"
secret_salt = "$SALT"
EOF

# Run nargo prove using the wrapper
# Note: we use -v to mount the Prover.toml and get the proof back
../../scripts/nargo.sh prove p_compliance

# The proof is generated in circuits/compliance_shield/proofs/p_compliance.proof
# Read it and print to stdout
cat proofs/p_compliance.proof

#!/usr/bin/env bash
# xB77 ZK-Policy Prover Helper
# Usage: ./gen_compliance_proof.sh <policy_root> <mission_id> <max_budget> <asset_id> <actual_amount> <daily_velocity> <rule_hash>

set -euo pipefail

POLICY_ROOT=$1
MISSION_ID=$2
MAX_BUDGET=$3
ASSET_ID=$4
ACTUAL_AMOUNT=$5
DAILY_VELOCITY=$6
RULE_HASH=$7
SALT="0x0000000000000000000000000000000000000000000000000000000000000000"

# Navigate to the circuit directory
cd "$(dirname "$0")/../circuits/compliance_shield"

# Generate Prover.toml
cat <<EOF > Prover.toml
policy_root = "$POLICY_ROOT"
mission_id = "$MISSION_ID"
max_budget = $MAX_BUDGET
asset_id = $ASSET_ID
rule_index = 0
rule_hash = "$RULE_HASH"
actual_amount = $ACTUAL_AMOUNT
daily_velocity = $DAILY_VELOCITY
secret_salt = "$SALT"
EOF

# Run nargo prove using the wrapper
../../scripts/nargo.sh prove p_compliance
cat proofs/p_compliance.proof

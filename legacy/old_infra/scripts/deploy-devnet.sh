#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAMS_DIR="${ROOT_DIR}/onchain/programs"
TARGET_DIR="${ROOT_DIR}/onchain/target/deploy"
KEYPAIRS_DIR="${ROOT_DIR}/.devnet/keypairs"
CLUSTER_URL="https://api.devnet.solana.com"

echo "---  XB77 Devnet Deployment ---"
echo "Setting config to Devnet..."
solana config set --url "$CLUSTER_URL"

# Ensure keypairs exist
if [ ! -d "$KEYPAIRS_DIR" ]; then
    echo "ERROR: .devnet/keypairs not found. Please run key generation first."
    exit 1
fi

# Function to build and deploy
deploy() {
    local name="$1"
    echo ""
    echo ">>> Processing $name..."
    
    # 1. Build
    echo "Building..."
    (cd "${PROGRAMS_DIR}/$name" && cargo build-sbf)
    
    # 2. Deploy
    local kp="${KEYPAIRS_DIR}/$name.json"
    local so="${TARGET_DIR}/$name.so"
    local deployer_kp="${ROOT_DIR}/.devnet/deployer.json"
    local prog_id=$(solana-keygen pubkey "$kp")
    
    echo "Deploying to $prog_id using deployer $(solana-keygen pubkey "$deployer_kp")..."
    solana program deploy \
        --program-id "$kp" \
        --fee-payer "$deployer_kp" \
        --upgrade-authority "$deployer_kp" \
        "$so"
        
    echo " $name Deployed: $prog_id"
}

# Deploy sequence (Order matters for dependencies?)
# Not strictly, but good to do foundational first.

deploy "xb77_registry"
deploy "xb77_test_utils"
deploy "xb77_receipts"
deploy "xb77_gateway"
deploy "xb77_core"

echo ""
echo "---  Deployment Complete! ---"
echo "Next steps:"
echo "1. Run 'scripts/init-devnet.ts' to initialize global state."

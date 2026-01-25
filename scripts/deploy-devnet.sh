#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAMS_DIR="${ROOT_DIR}/onchain/programs"
TARGET_DIR="${ROOT_DIR}/onchain/target/deploy"
IDL_DIR="${ROOT_DIR}/idls"
KEYPAIRS_DIR="${ROOT_DIR}/.localnet/keypairs" # Reusing keypairs or creating new ones for devnet? Best to separate.

# Use a separate keypair directory for devnet to avoid confusion
DEVNET_KEYPAIRS_DIR="${ROOT_DIR}/.devnet/keypairs"
mkdir -p "${DEVNET_KEYPAIRS_DIR}"

# --- Configuration ---
CLUSTER_URL="https://api.devnet.solana.com"
# Assuming the user has a wallet configured, or we can use a specific deployer key.
# For now, let's use the default solana config keypair or prompt.
# Actually, let's enforce using a specific deployer key if available, otherwise default.

echo "--- Deploying to Devnet ---"
echo "Cluster: $CLUSTER_URL"

# Check if we are on devnet
CURRENT_CLUSTER=$(solana config get | grep "RPC URL" | awk '{print $3}')
if [[ "$CURRENT_CLUSTER" != *devnet* ]]; then
    echo "WARNING: Your current solana config is not pointing to devnet."
    echo "Current: $CURRENT_CLUSTER"
    echo "Switching to devnet..."
    solana config set --url devnet
fi

# Ensure we have SOL
BALANCE=$(solana balance | awk '{print $1}')
echo "Deployer Balance: $BALANCE SOL"
if (( $(echo "$BALANCE < 5" | bc -l) )); then
    echo "WARNING: Low balance. You might need to airdrop or fund your wallet."
    # solana airdrop 2
fi

build_program() {
  local program_name=$1
  echo "Building ${program_name}..."
  (cd "${PROGRAMS_DIR}/${program_name}" && cargo build-sbf)
}

deploy_program() {
  local program_name=$1
  local so_path="${TARGET_DIR}/${program_name}.so"
  # We should use consistent keypairs for devnet to keep Program IDs stable across updates
  local keypair_path="${DEVNET_KEYPAIRS_DIR}/${program_name}.json"

  if [ ! -f "${keypair_path}" ]; then
    echo "Generating new devnet keypair for ${program_name}..."
    solana-keygen new --no-bip39-passphrase -o "${keypair_path}" --silent
  fi

  local program_id=$(solana-keygen pubkey "${keypair_path}")
  echo "Deploying ${program_name} (${program_id})..."
  
  # Deploy using the program keypair
  solana program deploy \
    --program-id "${keypair_path}" \
    "${so_path}"
    
  echo "Deployed ${program_name} to ${program_id}"
}

# --- Build & Deploy ---

# 1. Core
build_program "xb77_core"
deploy_program "xb77_core"

# 2. Gateway
build_program "xb77_gateway"
deploy_program "xb77_gateway"

# 3. Registry
build_program "xb77_registry"
deploy_program "xb77_registry"

# 4. Receipts
build_program "xb77_receipts"
deploy_program "xb77_receipts"

echo "--- All Programs Deployed ---"
echo "Check .devnet/keypairs for the program keys."

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROGRAMS_DIR="${ROOT_DIR}/onchain/programs"
TARGET_DIR="${ROOT_DIR}/onchain/target/deploy"
KEYPAIRS_DIR="${ROOT_DIR}/.localnet/keypairs"
CANONICAL_KEYPAIRS_DIR="${ROOT_DIR}/.devnet/keypairs"
SOLANA_RPC_URL="${SOLANA_RPC_URL:-http://127.0.0.1:8899}"

mkdir -p "${KEYPAIRS_DIR}"

# --- Helper Functions ---
check_validator() {
  if [ "${SOLANA_SKIP_VALIDATOR_CHECK:-}" = "1" ]; then
    echo "Skipping validator check (SOLANA_SKIP_VALIDATOR_CHECK=1)."
    return 0
  fi
  if ! solana -u "${SOLANA_RPC_URL}" cluster-version >/dev/null 2>&1; then
    echo "Error: Solana validator is not reachable at ${SOLANA_RPC_URL}. Please run './scripts/localnet/start-validator-light.sh' in a separate terminal."
    exit 1
  fi
}

build_program() {
  local program_name=$1
  echo "Building ${program_name}..."
  (cd "${PROGRAMS_DIR}/${program_name}" && cargo build-sbf)
}

deploy_program() {
  local program_name=$1
  local so_path="${TARGET_DIR}/${program_name}.so"
  local keypair_path="${KEYPAIRS_DIR}/${program_name}.json"
  local canonical_keypair_path="${CANONICAL_KEYPAIRS_DIR}/${program_name}.json"
  local deploy_args=()

  if [ "${SOLANA_USE_RPC:-}" = "1" ]; then
    deploy_args+=(--use-rpc)
  fi

  if [ -f "${canonical_keypair_path}" ]; then
    keypair_path="${canonical_keypair_path}"
    echo "Using canonical keypair for ${program_name}: ${keypair_path}"
  elif [ ! -f "${keypair_path}" ]; then
    echo "Generating keypair for ${program_name}..."
    solana-keygen new --no-bip39-passphrase -o "${keypair_path}" --silent
  fi

  local program_id=$(solana-keygen pubkey "${keypair_path}")
  echo "Deploying ${program_name} (${program_id})..."
  
  solana -u "${SOLANA_RPC_URL}" program deploy \
    --program-id "${keypair_path}" \
    "${deploy_args[@]}" \
    "${so_path}"
    
  echo "${program_name}_ID=${program_id}" >> "${ROOT_DIR}/.localnet/program_ids.env"
}

# --- Main Execution ---

echo "--- Starting Deployment Sequence ---"
check_validator

# Clear previous env file
rm -f "${ROOT_DIR}/.localnet/program_ids.env"
touch "${ROOT_DIR}/.localnet/program_ids.env"

# Build & Deploy Core
build_program "xb77_core"
deploy_program "xb77_core"

# Build & Deploy Gateway
build_program "xb77_gateway"
deploy_program "xb77_gateway"

# Build & Deploy Registry
build_program "xb77_registry"
deploy_program "xb77_registry"

# Build & Deploy Receipts (Placeholder if exists, otherwise skip)
if [ -d "${PROGRAMS_DIR}/xb77_receipts" ]; then
    build_program "xb77_receipts"
    deploy_program "xb77_receipts"
fi

# Build & Deploy Test Utils (localnet-only helper)
if [ -d "${PROGRAMS_DIR}/xb77_test_utils" ]; then
    build_program "xb77_test_utils"
    deploy_program "xb77_test_utils"
fi

echo "--- Deployment Complete ---"
cat "${ROOT_DIR}/.localnet/program_ids.env"

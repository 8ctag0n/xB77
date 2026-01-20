#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROGRAMS_DIR="${ROOT_DIR}/onchain/programs"
TARGET_DIR="${ROOT_DIR}/onchain/target/deploy"
KEYPAIRS_DIR="${ROOT_DIR}/.localnet/keypairs"

mkdir -p "${KEYPAIRS_DIR}"

# --- Helper Functions ---
check_validator() {
  if ! solana cluster-version >/dev/null 2>&1; then
    echo "Error: Solana validator is not running. Please run './scripts/localnet/start-validator-light.sh' in a separate terminal."
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

  if [ ! -f "${keypair_path}" ]; then
    echo "Generating keypair for ${program_name}..."
    solana-keygen new --no-bip39-passphrase -o "${keypair_path}" --silent
  fi

  local program_id=$(solana-keygen pubkey "${keypair_path}")
  echo "Deploying ${program_name} (${program_id})..."
  
  solana program deploy \
    --program-id "${keypair_path}" \
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

# Build & Deploy Receipts (Placeholder if exists, otherwise skip)
if [ -d "${PROGRAMS_DIR}/xb77_receipts" ]; then
    build_program "xb77_receipts"
    deploy_program "xb77_receipts"
fi

echo "--- Deployment Complete ---"
cat "${ROOT_DIR}/.localnet/program_ids.env"

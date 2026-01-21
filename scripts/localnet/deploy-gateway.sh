#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCALNET_DIR="${ROOT_DIR}/.localnet"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"
PAYER_KEYPAIR="${LOCALNET_DIR}/payer.json"
PROGRAM_ID_PATH="${LOCALNET_DIR}/gateway_program_id.txt"

if ! command -v solana >/dev/null 2>&1; then
  echo "solana CLI not found. Install Solana CLI tools." >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust toolchain." >&2
  exit 1
fi

mkdir -p "${LOCALNET_DIR}"

# if ! solana cluster-version --url "${SOLANA_URL}" >/dev/null 2>&1; then
#   echo "Local validator not reachable at ${SOLANA_URL}." >&2
#   echo "Run: ./scripts/localnet/start-validator.sh" >&2
#   exit 1
# fi

if [ ! -f "${PAYER_KEYPAIR}" ]; then
  solana-keygen new --no-bip39-passphrase -o "${PAYER_KEYPAIR}"
fi

solana airdrop 5 --url "${SOLANA_URL}" --keypair "${PAYER_KEYPAIR}" >/dev/null || true

cargo build-sbf --manifest-path "${ROOT_DIR}/onchain/programs/xb77_gateway/Cargo.toml"

SO_PATH="${ROOT_DIR}/onchain/target/deploy/xb77_gateway.so"
if [ ! -f "${SO_PATH}" ]; then
  echo "Gateway program .so not found at ${SO_PATH}." >&2
  exit 1
fi

DEPLOY_OUTPUT="$(solana program deploy --url "${SOLANA_URL}" --keypair "${PAYER_KEYPAIR}" "${SO_PATH}")"
echo "${DEPLOY_OUTPUT}"

PROGRAM_ID="$(printf "%s\n" "${DEPLOY_OUTPUT}" | grep "Program Id:" | sed 's/Program Id: //')"
if [ -z "${PROGRAM_ID}" ]; then
  echo "Unable to parse program id from deploy output." >&2
  exit 1
fi

echo "${PROGRAM_ID}" > "${PROGRAM_ID_PATH}"
echo "Gateway program id: ${PROGRAM_ID}"
echo "Wrote ${PROGRAM_ID_PATH}"

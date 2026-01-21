#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="${ROOT_DIR}/circuits/agent_badge/target/deploy"
LOCALNET_DIR="${ROOT_DIR}/.localnet"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"
PAYER_KEYPAIR="${LOCALNET_DIR}/payer.json"
PROGRAM_ID_PATH="${LOCALNET_DIR}/verifier_program_id.txt"

if ! command -v solana >/dev/null 2>&1; then
  echo "solana CLI not found." >&2
  exit 1
fi

mkdir -p "${LOCALNET_DIR}"

if [ ! -f "${PAYER_KEYPAIR}" ]; then
  solana-keygen new --no-bip39-passphrase -o "${PAYER_KEYPAIR}"
fi

solana airdrop 5 --url "${SOLANA_URL}" --keypair "${PAYER_KEYPAIR}" >/dev/null || true

# Use Docker to build verifier
echo "Building Verifier with Docker..."
"${ROOT_DIR}/scripts/build-verifier-docker.sh"

SO_PATH="${TARGET_DIR}/verifier_program.so"
KEYPAIR_PATH="${TARGET_DIR}/verifier_program-keypair.json"

if [ ! -f "${SO_PATH}" ]; then
  echo "Verifier .so not found at ${SO_PATH}." >&2
  exit 1
fi

DEPLOY_ARGS=("program" "deploy" "--url" "${SOLANA_URL}" "--keypair" "${PAYER_KEYPAIR}" "${SO_PATH}")
if [ -f "${KEYPAIR_PATH}" ]; then
  DEPLOY_ARGS+=(--program-id "${KEYPAIR_PATH}")
fi

echo "Deploying Verifier..."
DEPLOY_OUTPUT="$(solana "${DEPLOY_ARGS[@]}")"
echo "${DEPLOY_OUTPUT}"

PROGRAM_ID="$(printf "%s\n" "${DEPLOY_OUTPUT}" | grep "Program Id:" | sed 's/Program Id: //')"
if [ -z "${PROGRAM_ID}" ]; then
  echo "Unable to parse program id from deploy output." >&2
  exit 1
fi

echo "${PROGRAM_ID}" > "${PROGRAM_ID_PATH}"
echo "Verifier program id: ${PROGRAM_ID}"
echo "Wrote ${PROGRAM_ID_PATH}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CIRCUIT_DIR="${ROOT_DIR}/circuits/agent_badge"
TARGET_DIR="${CIRCUIT_DIR}/target"
LOCALNET_DIR="${ROOT_DIR}/.localnet"
SOLANA_URL="${SOLANA_URL:-http://127.0.0.1:8899}"
PAYER_KEYPAIR="${LOCALNET_DIR}/payer.json"
PROGRAM_ID_PATH="${LOCALNET_DIR}/verifier_program_id.txt"

if ! command -v solana >/dev/null 2>&1; then
  echo "solana CLI not found. Install Solana CLI tools." >&2
  exit 1
fi
if ! command -v solana-keygen >/dev/null 2>&1; then
  echo "solana-keygen not found. Install Solana CLI tools." >&2
  exit 1
fi

mkdir -p "${LOCALNET_DIR}"

if ! solana cluster-version --url "${SOLANA_URL}" >/dev/null 2>&1; then
  echo "Local validator not reachable at ${SOLANA_URL}." >&2
  echo "Run: ./scripts/localnet/start-validator.sh" >&2
  exit 1
fi

if [ ! -f "${PAYER_KEYPAIR}" ]; then
  solana-keygen new --no-bip39-passphrase -o "${PAYER_KEYPAIR}"
fi

solana airdrop 5 --url "${SOLANA_URL}" --keypair "${PAYER_KEYPAIR}" >/dev/null || true

if [ ! -f "${TARGET_DIR}/agent_badge.json" ]; then
  "${ROOT_DIR}/scripts/build-noir-artifacts.sh"
fi

if [ ! -f "${TARGET_DIR}/agent_badge.ccs" ]; then
  "${ROOT_DIR}/scripts/sunspot.sh" compile "${TARGET_DIR}/agent_badge.json"
fi

if [ ! -f "${TARGET_DIR}/agent_badge.vk" ] || [ ! -f "${TARGET_DIR}/agent_badge.pk" ]; then
  "${ROOT_DIR}/scripts/sunspot.sh" setup "${TARGET_DIR}/agent_badge.ccs"
fi

"${ROOT_DIR}/scripts/sunspot.sh" deploy "${TARGET_DIR}/agent_badge.vk"

SO_PATH="$(ls -t "${TARGET_DIR}"/*.so 2>/dev/null | head -n 1 || true)"
KEYPAIR_PATH="$(ls -t "${TARGET_DIR}"/*keypair*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${SO_PATH}" ]; then
  echo "Verifier .so not found in ${TARGET_DIR}." >&2
  exit 1
fi

DEPLOY_ARGS=(program deploy --url "${SOLANA_URL}" --keypair "${PAYER_KEYPAIR}" "${SO_PATH}")
if [ -n "${KEYPAIR_PATH}" ]; then
  DEPLOY_ARGS+=(--program-id "${KEYPAIR_PATH}")
fi

DEPLOY_OUTPUT="$(solana "${DEPLOY_ARGS[@]}")"
echo "${DEPLOY_OUTPUT}"

PROGRAM_ID="$(printf "%s\n" "${DEPLOY_OUTPUT}" | rg -o "Program Id: ([A-Za-z0-9]+)" -r '$1' | head -n 1)"
if [ -z "${PROGRAM_ID}" ]; then
  echo "Unable to parse program id from deploy output." >&2
  exit 1
fi

echo "${PROGRAM_ID}" > "${PROGRAM_ID_PATH}"
echo "Verifier program id: ${PROGRAM_ID}"
echo "Wrote ${PROGRAM_ID_PATH}"

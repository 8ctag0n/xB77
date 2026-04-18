#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"

if ! command -v solana >/dev/null 2>&1; then
  echo "solana CLI not found. Install Solana CLI tools." >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/.localnet/gateway_program_id.txt" ]; then
  echo "Missing .localnet/gateway_program_id.txt. Deploy the gateway first." >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/.localnet/verifier_program_id.txt" ]; then
  echo "Missing .localnet/verifier_program_id.txt. Deploy the verifier first." >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/sdk/target/agent_badge.meta.json" ]; then
  echo "Missing sdk/target/agent_badge.meta.json. Run: make proof-badge" >&2
  exit 1
fi

ensure_program() {
  local program_id_path="$1"
  local deploy_script="$2"

  local program_id
  program_id="$(cat "${program_id_path}")"
  if ! solana program show "${program_id}" --url "${SOLANA_URL}" >/dev/null 2>&1; then
    echo "Program ${program_id} not found on ${SOLANA_URL}. Redeploying..." >&2
    "${deploy_script}"
    program_id="$(cat "${program_id_path}")"
    if ! solana program show "${program_id}" --url "${SOLANA_URL}" >/dev/null 2>&1; then
      echo "Program ${program_id} still missing after redeploy. Aborting init." >&2
      exit 1
    fi
  fi
}

ensure_program \
  "${ROOT_DIR}/.localnet/verifier_program_id.txt" \
  "${ROOT_DIR}/scripts/localnet/deploy-verifier.sh"
ensure_program \
  "${ROOT_DIR}/.localnet/gateway_program_id.txt" \
  "${ROOT_DIR}/scripts/localnet/deploy-gateway.sh"

GATEWAY_PROGRAM_ID="$(cat "${ROOT_DIR}/.localnet/gateway_program_id.txt")"
VERIFIER_PROGRAM_ID="$(cat "${ROOT_DIR}/.localnet/verifier_program_id.txt")"
echo "Using gateway program id: ${GATEWAY_PROGRAM_ID}"
echo "Using verifier program id: ${VERIFIER_PROGRAM_ID}"

pushd "${ROOT_DIR}/cli" >/dev/null
attempt=1
max_attempts=5
while [ "${attempt}" -le "${max_attempts}" ]; do
  set +e
  init_output="$(cargo run -- init \
    --url "${SOLANA_URL}" \
    --config-dir "${ROOT_DIR}/.localnet" \
    --meta "${ROOT_DIR}/sdk/target/agent_badge.meta.json" 2>&1)"
  status=$?
  set -e

  echo "${init_output}"
  if [ "${status}" -eq 0 ]; then
    break
  fi

  if printf "%s" "${init_output}" | rg -q "Attempt to load a program that does not exist"; then
    echo "Init failed due to program load race (attempt ${attempt}/${max_attempts}). Retrying..." >&2
    attempt=$((attempt + 1))
    sleep 2
    continue
  fi

  exit "${status}"
done

if [ "${attempt}" -gt "${max_attempts}" ]; then
  echo "Init failed after ${max_attempts} attempts." >&2
  exit 1
fi
popd >/dev/null

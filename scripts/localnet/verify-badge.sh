#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"

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

if [ ! -f "${ROOT_DIR}/circuits/agent_badge/target/agent_badge.proof" ]; then
  echo "Missing proof file. Run: make proof-badge" >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/circuits/agent_badge/target/agent_badge.pw" ]; then
  echo "Missing public witness file. Run: make proof-badge" >&2
  exit 1
fi

SW_PROOF_PDA_ARG=()
if [ -n "${SW_PROOF_PDA:-}" ]; then
  SW_PROOF_PDA_ARG=(--sw-proof-pda "${SW_PROOF_PDA}")
else
  # Default to system program if not provided, though the program will likely fail the binding check
  # unless it specifically handles the dummy case. 
  # For the new binding, it's better to be explicit.
  echo "Warning: SW_PROOF_PDA not set. Using system program as dummy (binding check will fail)."
  SW_PROOF_PDA_ARG=(--sw-proof-pda "11111111111111111111111111111111")
fi

pushd "${ROOT_DIR}/cli" >/dev/null
cargo run -- verify \
  --url "${SOLANA_URL}" \
  --config-dir "${ROOT_DIR}/.localnet" \
  --meta "${ROOT_DIR}/sdk/target/agent_badge.meta.json" \
  --proof "${ROOT_DIR}/circuits/agent_badge/target/agent_badge.proof" \
  --public-witness "${ROOT_DIR}/circuits/agent_badge/target/agent_badge.pw" \
  --compute-units 1000000 \
  "${SW_PROOF_PDA_ARG[@]}"
popd >/dev/null

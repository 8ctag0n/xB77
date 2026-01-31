#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"
AMOUNT="${AMOUNT:-1}"

if [ ! -f "${ROOT_DIR}/.localnet/gateway_program_id.txt" ]; then
  echo "Missing .localnet/gateway_program_id.txt. Deploy the gateway first." >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/sdk/target/agent_badge.meta.json" ]; then
  echo "Missing sdk/target/agent_badge.meta.json. Run: make proof-badge" >&2
  exit 1
fi

if [ -z "${TOKEN_MINT:-}" ]; then
  echo "Missing TOKEN_MINT env var." >&2
  exit 1
fi

if [ -z "${RECIPIENT:-}" ]; then
  echo "Missing RECIPIENT env var." >&2
  exit 1
fi

ORDER_ID_ARG=()
if [ -n "${ORDER_ID:-}" ]; then
  ORDER_ID_ARG=(--order-id "${ORDER_ID}")
fi

NULLIFIER_ARG=()
if [ -n "${NULLIFIER_HEX:-}" ]; then
  NULLIFIER_ARG=(--nullifier-hex "${NULLIFIER_HEX}")
fi

pushd "${ROOT_DIR}/cli" >/dev/null
cargo run -- submit-order \
  --url "${SOLANA_URL}" \
  --config-dir "${ROOT_DIR}/.localnet" \
  --meta "${ROOT_DIR}/sdk/target/agent_badge.meta.json" \
  --amount "${AMOUNT}" \
  --token "${TOKEN_MINT}" \
  --recipient "${RECIPIENT}" \
  "${ORDER_ID_ARG[@]}" \
  "${NULLIFIER_ARG[@]}"
popd >/dev/null

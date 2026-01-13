#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOLANA_URL="${SOLANA_URL:-http://127.0.0.1:8899}"

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

pushd "${ROOT_DIR}/contracts" >/dev/null
cargo run -p xb77_gateway_cli -- init \
  --url "${SOLANA_URL}" \
  --config-dir "${ROOT_DIR}/.localnet" \
  --meta "${ROOT_DIR}/sdk/target/agent_badge.meta.json"
popd >/dev/null

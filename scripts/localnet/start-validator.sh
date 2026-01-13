#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger"

if ! command -v solana-test-validator >/dev/null 2>&1; then
  echo "solana-test-validator not found. Install Solana CLI tools." >&2
  exit 1
fi

mkdir -p "${LEDGER_DIR}"

exec solana-test-validator \
  --reset \
  --ledger "${LEDGER_DIR}" \
  --rpc-port 8899 \
  --limit-ledger-size

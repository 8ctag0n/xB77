#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="${ROOT_DIR}/.localnet/ledger/validator.log"
PID_PATH="${ROOT_DIR}/.localnet/validator.pid"
SOLANA_URL="${SOLANA_URL:-http://localhost:8899}"

if ! command -v solana >/dev/null 2>&1; then
  echo "solana CLI not found. Install Solana CLI tools." >&2
  exit 1
fi

mkdir -p "$(dirname "${LOG_PATH}")"

setsid "${ROOT_DIR}/scripts/localnet/start-validator.sh" > "${LOG_PATH}" 2>&1 < /dev/null &
echo "$!" > "${PID_PATH}"
sleep 1
if ! kill -0 "$(cat "${PID_PATH}")" >/dev/null 2>&1; then
  echo "Validator failed to stay running. See ${LOG_PATH}." >&2
  exit 1
fi
for _ in {1..30}; do
  if solana cluster-version --url "${SOLANA_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
echo "Started validator (pid $(cat "${PID_PATH}")), logging to ${LOG_PATH}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="${ROOT_DIR}/.localnet/ledger/validator.log"
PID_PATH="${ROOT_DIR}/.localnet/validator.pid"

mkdir -p "$(dirname "${LOG_PATH}")"

"${ROOT_DIR}/scripts/localnet/start-validator.sh" > "${LOG_PATH}" 2>&1 &
echo "$!" > "${PID_PATH}"
echo "Started validator (pid $(cat "${PID_PATH}")), logging to ${LOG_PATH}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
START_VALIDATOR=${START_VALIDATOR:-0}

if [[ "${START_VALIDATOR}" == "1" ]]; then
  "${ROOT_DIR}/scripts/localnet/start-validator-light.sh" &
  VALIDATOR_PID=$!
  echo "[localnet] validator started (pid=${VALIDATOR_PID})"
  # give the validator a moment to start
  sleep 5
fi

bun test "${ROOT_DIR}/tests/localnet"

if [[ "${START_VALIDATOR}" == "1" ]]; then
  kill "${VALIDATOR_PID}" || true
fi

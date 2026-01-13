#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_PATH="${ROOT_DIR}/.localnet/validator.pid"

if [ ! -f "${PID_PATH}" ]; then
  echo "No validator pid file found at ${PID_PATH}."
  exit 0
fi

PID="$(cat "${PID_PATH}")"
if [ -z "${PID}" ]; then
  echo "Validator pid file is empty: ${PID_PATH}."
  exit 1
fi

if kill "${PID}" >/dev/null 2>&1; then
  echo "Stopped validator pid ${PID}."
  rm -f "${PID_PATH}"
  exit 0
fi

echo "Failed to stop validator pid ${PID}."
exit 1

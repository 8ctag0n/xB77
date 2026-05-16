#!/usr/bin/env bash
# scripts/nargo-native.sh — Run Noir commands natively on the host.
# Use this if you don't have Podman/Docker.

set -euo pipefail

if ! command -v nargo >/dev/null 2>&1; then
    echo "Error: 'nargo' binary not found on host."
    echo "Please install Noir: https://noir-lang.org/docs/getting_started/installation"
    exit 1
fi

PROGRAM_DIR=""
FILTERED_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --program-dir) PROGRAM_DIR="$2"; shift 2 ;;
    *)             FILTERED_ARGS+=("$1"); shift ;;
  esac
done

if [[ -n "$PROGRAM_DIR" ]]; then
    cd "$PROGRAM_DIR"
    nargo "${FILTERED_ARGS[@]}"
else
    nargo "${FILTERED_ARGS[@]}"
fi

#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="${LIGHT_BIN_DIR:-${ROOT_DIR}/containers/light/bin}"
ACCOUNTS_DIR="${LIGHT_ACCOUNTS_DIR:-${ROOT_DIR}/scripts/light/local/accounts}"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger-light"
LIGHT_ENV_FILE="${ROOT_DIR}/containers/light/bin/light-localnet.env"

# Load shared Light constants (if present)
if [ -f "${LIGHT_ENV_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${LIGHT_ENV_FILE}"
fi

# Program IDs
SYSTEM_PROGRAM_ID="${LIGHT_SYSTEM_PROGRAM_ID:-SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7}"
TOKEN_PROGRAM_ID="${LIGHT_TOKEN_PROGRAM_ID:-cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m}"
COMPRESSION_PROGRAM_ID="${LIGHT_COMPRESSION_PROGRAM_ID:-compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq}"

# Binary Paths
SYSTEM_SO="${LIGHT_SYSTEM_SO_PATH:-${BIN_DIR}/light_system_program_pinocchio.so}"
TOKEN_SO="${LIGHT_TOKEN_SO_PATH:-${BIN_DIR}/light_compressed_token.so}"
COMPRESSION_SO="${LIGHT_COMPRESSION_SO_PATH:-${BIN_DIR}/account_compression.so}"

echo "--- Setup Check ---"
echo "Root Dir: ${ROOT_DIR}"
echo "Bin Dir:  ${BIN_DIR}"
echo "Accounts: ${ACCOUNTS_DIR}"
echo "Config:   ${LIGHT_ENV_FILE}"

# Validate Binaries
missing=0
for bin in "${SYSTEM_SO}" "${TOKEN_SO}" "${COMPRESSION_SO}"; do
    if [ ! -f "$bin" ]; then
        echo "ERROR: Missing binary: $bin"
        missing=1
    else
        echo "OK: Found $(basename "$bin")"
    fi
done

if [ $missing -eq 1 ]; then
    echo "--------------------------------------------------------"
    echo "FATAL: One or more Light Protocol binaries are missing."
    echo "Please ensure you have extracted the artifacts to:"
    echo "  ${BIN_DIR}"
    echo "Expected files:"
    echo "  - light_system_program_pinocchio.so"
    echo "  - light_compressed_token.so"
    echo "  - account_compression.so"
    echo "Canonical dump/config:"
    echo "  - ${LIGHT_ENV_FILE}"
    echo "--------------------------------------------------------"
    exit 1
fi

echo "--- Starting Validator ---"
echo "System Program: ${SYSTEM_PROGRAM_ID}"
echo "Token Program:  ${TOKEN_PROGRAM_ID}"
echo "Compression:    ${COMPRESSION_PROGRAM_ID}"

# Ensure ledger directory exists
mkdir -p "${LEDGER_DIR}"

# Run without --quiet to show progress
solana-test-validator \
    --ledger "${LEDGER_DIR}" \
    --reset \
    --bpf-program "${SYSTEM_PROGRAM_ID}" "${SYSTEM_SO}" \
    --bpf-program "${TOKEN_PROGRAM_ID}" "${TOKEN_SO}" \
    --bpf-program "${COMPRESSION_PROGRAM_ID}" "${COMPRESSION_SO}" \
    --account-dir "${ACCOUNTS_DIR}" \

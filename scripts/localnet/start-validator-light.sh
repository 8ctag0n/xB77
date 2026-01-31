#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="${ROOT_DIR}/containers/light/bin"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger-light"

# Program IDs
SYSTEM_PROGRAM_ID="SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7"
TOKEN_PROGRAM_ID="cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m"
COMPRESSION_PROGRAM_ID="compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq"

# Binary Paths
SYSTEM_SO="${BIN_DIR}/light_system_program_pinocchio.so"
TOKEN_SO="${BIN_DIR}/light_compressed_token.so"
COMPRESSION_SO="${BIN_DIR}/account_compression.so"

echo "--- Setup Check ---"
echo "Root Dir: ${ROOT_DIR}"
echo "Bin Dir:  ${BIN_DIR}"

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
    echo "--------------------------------------------------------"
    exit 1
fi

echo "--- Starting Validator ---"
echo "System Program: ${SYSTEM_PROGRAM_ID}"
echo "Token Program:  ${TOKEN_PROGRAM_ID}"
echo "Compression:    ${COMPRESSION_PROGRAM_ID}"

# Ensure ledger directory exists
#mkdir -p "${ROOT_DIR}/.localnet"

# Run without --quiet to show progress
solana-test-validator \
    --bpf-program "${SYSTEM_PROGRAM_ID}" "${SYSTEM_SO}" \
    --bpf-program "${TOKEN_PROGRAM_ID}" "${TOKEN_SO}" \
    --bpf-program "${COMPRESSION_PROGRAM_ID}" "${COMPRESSION_SO}" \
    --account-dir "${ROOT_DIR}/scripts/light/local/accounts" \

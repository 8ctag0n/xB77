#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="${ROOT_DIR}/containers/surfpool/bin"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger-light"

# Program IDs
SYSTEM_PROGRAM_ID="SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7"
TOKEN_PROGRAM_ID="cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m"
COMPRESSION_PROGRAM_ID="compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq"

# Binary Paths
SYSTEM_SO="${BIN_DIR}/light_system_program_pinocchio.so"
TOKEN_SO="${BIN_DIR}/light_compressed_token.so"
COMPRESSION_SO="${BIN_DIR}/account_compression.so"

echo "Starting Solana Test Validator with Light Protocol programs..."
echo "System Program: ${SYSTEM_PROGRAM_ID}"
echo "Token Program:  ${TOKEN_PROGRAM_ID}"
echo "Compression:    ${COMPRESSION_PROGRAM_ID}"

# Ensure ledger directory exists
mkdir -p "${ROOT_DIR}/.localnet"

solana-test-validator \
    --ledger "${LEDGER_DIR}" \
    --bpf-program "${SYSTEM_PROGRAM_ID}" "${SYSTEM_SO}" \
    --bpf-program "${TOKEN_PROGRAM_ID}" "${TOKEN_SO}" \
    --bpf-program "${COMPRESSION_PROGRAM_ID}" "${COMPRESSION_SO}" \
    --rpc-port 8899 \
    --dynamic-port-range 8000-8020 \
    --reset \
    --quiet
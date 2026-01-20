#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger"
PAYER_KEYPAIR="${ROOT_DIR}/.localnet/payer.json"
BPF_BIN_DIR="${ROOT_DIR}/containers/surfpool/bin"

if ! command -v solana-test-validator >/dev/null 2>&1; then
  echo "solana-test-validator not found. Install Solana CLI tools." >&2
  exit 1
fi
if ! command -v solana-keygen >/dev/null 2>&1; then
  echo "solana-keygen not found. Install Solana CLI tools." >&2
  exit 1
fi
if [ ! -d "${BPF_BIN_DIR}" ]; then
  echo "Missing Surfpool bin directory at ${BPF_BIN_DIR}." >&2
  exit 1
fi

mkdir -p "${LEDGER_DIR}"
mkdir -p "$(dirname "${PAYER_KEYPAIR}")"

if [ ! -f "${PAYER_KEYPAIR}" ]; then
  solana-keygen new --no-bip39-passphrase -o "${PAYER_KEYPAIR}"
fi

MINT_PUBKEY="$(solana-keygen pubkey "${PAYER_KEYPAIR}")"

BPF_PROGRAMS=(
  "SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7:${BPF_BIN_DIR}/light_system_program_pinocchio.so"
  "cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m:${BPF_BIN_DIR}/light_compressed_token.so"
  "compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq:${BPF_BIN_DIR}/account_compression.so"
)

VALIDATOR_ARGS=(
  --reset
  --ledger "${LEDGER_DIR}"
  --limit-ledger-size 10000
  --mint "${MINT_PUBKEY}"
)

for entry in "${BPF_PROGRAMS[@]}"; do
  IFS=":" read -r program_id program_path <<< "${entry}"
  if [ ! -f "${program_path}" ]; then
    echo "Missing BPF program at ${program_path}." >&2
    exit 1
  fi
  VALIDATOR_ARGS+=(--bpf-program "${program_id}" "${program_path}")
done

exec solana-test-validator "${VALIDATOR_ARGS[@]}"

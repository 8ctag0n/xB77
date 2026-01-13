#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER_DIR="${ROOT_DIR}/.localnet/ledger"
PAYER_KEYPAIR="${ROOT_DIR}/.localnet/payer.json"

if ! command -v solana-test-validator >/dev/null 2>&1; then
  echo "solana-test-validator not found. Install Solana CLI tools." >&2
  exit 1
fi
if ! command -v solana-keygen >/dev/null 2>&1; then
  echo "solana-keygen not found. Install Solana CLI tools." >&2
  exit 1
fi

mkdir -p "${LEDGER_DIR}"
mkdir -p "$(dirname "${PAYER_KEYPAIR}")"

if [ ! -f "${PAYER_KEYPAIR}" ]; then
  solana-keygen new --no-bip39-passphrase -o "${PAYER_KEYPAIR}"
fi

MINT_PUBKEY="$(solana-keygen pubkey "${PAYER_KEYPAIR}")"

exec solana-test-validator \
  --reset \
  --ledger "${LEDGER_DIR}" \
  --rpc-port 8899 \
  --bind-address 127.0.0.1 \
  --faucet-port 0 \
  --limit-ledger-size 10000 \
  --mint "${MINT_PUBKEY}"

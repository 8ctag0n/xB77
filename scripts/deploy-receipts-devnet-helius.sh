#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/2026_working/zyb_source/xB77"
ENV_FILE="$ROOT/mcp/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: No existe $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ -z "${HELIUS_API_KEY:-}" ]; then
  echo "ERROR: HELIUS_API_KEY está vacío en $ENV_FILE"
  exit 1
fi

RPC_URL="https://devnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}"

echo "Using RPC: ${RPC_URL%%api-key=*}api-key=***"

solana program deploy \
  --program-id "$ROOT/.devnet/keypairs/xb77_receipts.json" \
  --fee-payer "$ROOT/.devnet/deployer.json" \
  --upgrade-authority "$ROOT/.devnet/deployer.json" \
  "$ROOT/onchain/target/deploy/xb77_receipts.so" \
  --url "$RPC_URL"

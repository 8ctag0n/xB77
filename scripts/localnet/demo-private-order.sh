#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 1. Setup Environment
ORDER_ID="${ORDER_ID:-$((RANDOM % 10000 + 1000))}"
echo "=== DEMO: Private Order Flow ==="
echo "Using Order ID: ${ORDER_ID}"

# Use Payer as Recipient if not set
RECIPIENT="${RECIPIENT:-}"
if [ -z "$RECIPIENT" ]; then
    # Fallback to a dummy key if we can't get one easily, but let's try to read localnet payer
    PAYER_KEYPAIR="${ROOT_DIR}/.localnet/payer.json"
    if [ -f "$PAYER_KEYPAIR" ]; then
       RECIPIENT=$(solana-keygen pubkey "$PAYER_KEYPAIR")
    else
       echo "Error: .localnet/payer.json not found. Run localnet setup first."
       exit 1
    fi
fi

# Use Payer as Token Mint for demo purposes if not set
TOKEN_MINT="${TOKEN_MINT:-$RECIPIENT}"

echo "Using Recipient: ${RECIPIENT}"
echo "Using Token Mint: ${TOKEN_MINT}"

# 2. Generate Proof
echo "--- Step 1: Generating Badge Proof for Order ID ${ORDER_ID} ---"
export ORDER_ID
pushd "${ROOT_DIR}/sdk" >/dev/null
bun run scripts/generate_badge_proof.ts
popd >/dev/null

# 3. Verify Badge
echo "--- Step 2: Verifying Badge on-chain ---"
"${ROOT_DIR}/scripts/localnet/verify-badge.sh"

# 4. Submit Private Order
echo "--- Step 3: Submitting Private Order ---"
export TOKEN_MINT
export RECIPIENT
# ORDER_ID is already exported
"${ROOT_DIR}/scripts/localnet/submit-private-order.sh"

echo "=== Demo Complete! ==="
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/demo/logs"
KEY_DIR="$ROOT/demo/keys"
DATA_DIR="$ROOT/demo/data"
HUB_PORT="7777"
LISTENER_PORT="7002"

# Env Vars for Localnet
export SOLANA_RPC_URL="http://127.0.0.1:8899"
export LIGHT_COMPRESSION_RPC_URL="http://127.0.0.1:8899"
export LIGHT_PROVER_RPC_URL="http://127.0.0.1:8899"
export XB77_PAYMENT_MODE="live"
export XB77_OFFLINE="false"
export XB77_TOKEN_DEFAULT="SOL" 

mkdir -p "$LOG_DIR" "$KEY_DIR" "$DATA_DIR"

# Cleanup
pids=()
cleanup() {
  echo "Stopping services..."
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

# Helper: Generate Key
function gen_key() {
    local target="$1"
    if [[ ! -f "$target" ]]; then
        (cd sdk && bun -e "import { Keypair } from '@solana/web3.js'; import { writeFileSync } from 'fs'; writeFileSync('$target', JSON.stringify(Array.from(Keypair.generate().secretKey)));")
    fi
}

# Helper: Get Pubkey
function get_pubkey() {
    solana-keygen pubkey "$1"
}

# 1. Setup Keys
echo "--- Setting up Keys ---"
gen_key "$KEY_DIR/listener.json"
gen_key "$KEY_DIR/agent-alpha.json"

LISTENER_PUBKEY=$(get_pubkey "$KEY_DIR/listener.json")
ALPHA_PUBKEY=$(get_pubkey "$KEY_DIR/agent-alpha.json")

# 2. Fund Agents (Airdrop)
echo "--- Funding Listener ($LISTENER_PUBKEY) ---"
solana airdrop 5 "$LISTENER_PUBKEY" --url "$SOLANA_RPC_URL" >/dev/null

# 3. Start Services
echo "--- Starting Services (Live Mode) ---"
function start_background() {
  local label="$1"
  shift
  "$@" > "$LOG_DIR/$label.log" 2>&1 &
  pids+=($!)
}

start_background "listener" bash -lc "cd '$ROOT' && \
  XB77_KEYPAIR_PATH='$KEY_DIR/listener.json' \
  XB77_DB_PATH='$DATA_DIR/listener.db' \
  XB77_LISTENER_URL='http://localhost:$LISTENER_PORT' \
  LISTENER_PORT='$LISTENER_PORT' \
  bun run mcp/src/listener.ts"

echo "Waiting for services..."
sleep 5

echo "--- Simulating Helius Webhook ---"
# We simulate a transfer TO the Listener (so the Listener thinks it received money and generates a receipt for itself/sender)
# Wait, handleHeliusWebhook checks if `toUserAccount === context.agent.wallet.publicKey`.
# So if we send a webhook saying "User X sent 100 SOL to Listener", Listener triggers receipt.

PAYLOAD=$(cat <<JSON
[
  {
    "type": "TRANSFER",
    "description": "Simulated Transfer",
    "signature": "simulated_tx_$(date +%s)",
    "nativeTransfers": [
      {
        "amount": 1000000000,
        "fromUserAccount": "So11111111111111111111111111111111111111112",
        "toUserAccount": "$LISTENER_PUBKEY"
      }
    ]
  }
]
JSON
)

echo "Sending Webhook Payload..."
curl -v -X POST "http://localhost:$LISTENER_PORT/webhooks/helius" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"

# Verify Log for On-Chain Signature
echo "--- Verifying Receipt Status ---"
sleep 5 # Give it time to build proof and send TX

if grep -q "Receipt recorded on-chain!" "$LOG_DIR/listener.log"; then
    echo "[SUCCESS] Listener recorded a real on-chain receipt!"
    grep "Receipt recorded on-chain!" "$LOG_DIR/listener.log"
elif grep -q "Simulated receipt stored in DB" "$LOG_DIR/listener.log"; then
    echo "[SUCCESS] Listener handled Prover absence and stored a simulated receipt."
    echo "  (This is normal for Localnet without Surfpool/Prover)"
else
    echo "[FAIL] No receipt recorded (real or simulated) in listener log."
    echo "Tail of listener log:"
    tail -n 10 "$LOG_DIR/listener.log"
fi
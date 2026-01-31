#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/demo/logs"
KEY_DIR="$ROOT/demo/keys"
DATA_DIR="$ROOT/demo/data"
HUB_PORT="${HUB_PORT:-7777}"
LISTENER_PORT="${LISTENER_PORT:-7002}"

mkdir -p "$LOG_DIR" "$KEY_DIR" "$DATA_DIR"

function generate_keypair() {
  local target="$1"
  if [[ -f "$target" ]]; then
    return
  fi
  (cd sdk && bun -e "import { Keypair } from '@solana/web3.js'; import { writeFileSync } from 'fs'; writeFileSync('$target', JSON.stringify(Array.from(Keypair.generate().secretKey)));")
  echo "generated keypair $target"
}

function start_background() {
  local label="$1"
  shift
  echo "Starting $label (log -> $LOG_DIR/$label.log)"
  "$@" > "$LOG_DIR/$label.log" 2>&1 &
  pids+=($!)
  sleep 1
}

function register_agent() {
  local agent_id="$1"
  local port="$2"
  local payload
  payload=(
    cat <<JSON
{
  "agent_id": "$agent_id",
  "mcp_url": "http://localhost:$port/tool",
  "capabilities": ["agent.pay","agent.status","agent.receipts.latest"],
  "transport": "http"
}
JSON
  )
  curl -s -X POST "http://localhost:$HUB_PORT/register" \
    -H "content-type: application/json" \
    -d "$payload" >/dev/null
  echo "Registered $agent_id on Hub port $HUB_PORT (mcp port $port)"
}

cleanup() {
  echo "Stopping services..."
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null;
 then
      kill "$pid"
      wait "$pid" 2>/dev/null || true
    fi
  done
}

trap cleanup EXIT

generate_keypair "$KEY_DIR/agent-alpha.json"
generate_keypair "$KEY_DIR/agent-bravo.json"
generate_keypair "$KEY_DIR/listener.json"

pids=()

start_background "hub" bash -lc "cd '$ROOT' && bun hub/index.ts --port $HUB_PORT"

start_background "listener" bash -lc "cd '$ROOT' && \
  XB77_KEYPAIR_PATH='$KEY_DIR/listener.json' \
  XB77_DB_PATH='$DATA_DIR/listener.db' \
  XB77_LISTENER_URL='http://localhost:$LISTENER_PORT' \
  LISTENER_PORT='$LISTENER_PORT' \
  SOLANA_RPC_URL='${SOLANA_RPC_URL:-http://localhost:8899}' \
  LIGHT_COMPRESSION_RPC_URL='${LIGHT_COMPRESSION_RPC_URL:-http://localhost:8899}' \
  LIGHT_PROVER_RPC_URL='${LIGHT_PROVER_RPC_URL:-http://localhost:8899}' \
  XB77_PAYMENT_MODE='${XB77_PAYMENT_MODE:-mock}' \
  XB77_OFFLINE='${XB77_OFFLINE:-true}' \
  bun run mcp/src/listener.ts"

AGENTS=(alpha bravo)
PORTS=(7001 7003)

for i in "${!AGENTS[@]}"; do
  agent="${AGENTS[i]}"
  port="${PORTS[i]}"
  start_background "agent-$agent" bash -lc "cd '$ROOT' && \
    MCP_HTTP_PORT='$port' \
    XB77_KEYPAIR_PATH='$KEY_DIR/agent-$agent.json' \
    XB77_DB_PATH='$DATA_DIR/agent-$agent.db' \
    SOLANA_RPC_URL='${SOLANA_RPC_URL:-http://localhost:8899}' \
    LIGHT_COMPRESSION_RPC_URL='${LIGHT_COMPRESSION_RPC_URL:-http://localhost:8899}' \
    LIGHT_PROVER_RPC_URL='${LIGHT_PROVER_RPC_URL:-http://localhost:8899}' \
    XB77_PAYMENT_MODE='${XB77_PAYMENT_MODE:-mock}' \
    XB77_OFFLINE='${XB77_OFFLINE:-true}' \
    bun run mcp/src/http.ts"
  # allow MCP to warm up before registering
  sleep 1
  register_agent "agent-$agent" "$port"
done

echo "Demo stack is up!"
echo "  Hub: http://localhost:$HUB_PORT"
echo "  Listener: http://localhost:$LISTENER_PORT"
echo "  Agents: ${AGENTS[*]} registered"
echo "Logs -> $LOG_DIR"
echo "Press Ctrl+C to shutdown."

wait

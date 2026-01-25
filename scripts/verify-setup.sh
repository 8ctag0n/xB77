#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/demo/logs"
KEY_DIR="$ROOT/demo/keys"
DATA_DIR="$ROOT/demo/data"
HUB_PORT="${HUB_PORT:-7777}"
LISTENER_PORT="${LISTENER_PORT:-7002}"

mkdir -p "$LOG_DIR" "$KEY_DIR" "$DATA_DIR"

# Cleanup function
pids=()
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

# Helper functions
function start_background() {
  local label="$1"
  shift
  echo "Starting $label..."
  "$@" > "$LOG_DIR/$label.log" 2>&1 &
  pids+=($!)
}

function register_agent() {
  local agent_id="$1"
  local port="$2"
  local payload
  payload=$(cat <<JSON
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
}

# 1. Setup Keys
function gen_key() {
    local target="$1"
    if [[ ! -f "$target" ]]; then
        (cd sdk && bun -e "import { Keypair } from '@solana/web3.js'; import { writeFileSync } from 'fs'; writeFileSync('$target', JSON.stringify(Array.from(Keypair.generate().secretKey)));")
    fi
}

gen_key "$KEY_DIR/listener.json"
gen_key "$KEY_DIR/agent-alpha.json"
gen_key "$KEY_DIR/agent-bravo.json"

# 2. Start Services
start_background "hub" bash -lc "cd '$ROOT' && bun hub/index.ts --port $HUB_PORT"

start_background "listener" bash -lc "cd '$ROOT' && \
  XB77_KEYPAIR_PATH='$KEY_DIR/listener.json' \
  XB77_DB_PATH='$DATA_DIR/listener.db' \
  XB77_LISTENER_URL='http://localhost:$LISTENER_PORT' \
  LISTENER_PORT='$LISTENER_PORT' \
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
    bun run mcp/src/http.ts"
done

echo "Waiting for services to warm up..."
sleep 5

# 3. Register Agents
for i in "${!AGENTS[@]}"; do
  register_agent "agent-${AGENTS[i]}" "${PORTS[i]}"
done

echo "---------------------------------------------------"
echo "PHASE 1: Basic Stack Verification"
echo "---------------------------------------------------"

# Verify Hub
echo "Checking Hub Agents..."
curl -s "http://localhost:$HUB_PORT/agents" | grep "agent-alpha" && echo "  [OK] Agent Alpha registered" || echo "  [FAIL] Agent Alpha missing"

# Verify DB
echo "Checking Agent DB..."
if [[ -f "$DATA_DIR/agent-alpha.db" ]]; then
    echo "  [OK] agent-alpha.db exists"
    # Basic table check (might be empty, but command shouldn't fail)
    sqlite3 "$DATA_DIR/agent-alpha.db" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='receipts';"
else
    echo "  [FAIL] agent-alpha.db missing"
fi

echo "---------------------------------------------------"
echo "PHASE 2: Governance & Filtering"
echo "---------------------------------------------------"

# Create Request for Alpha
echo "Creating Governance Request for Alpha..."
REQ_ID=$(curl -s -X POST "http://localhost:$LISTENER_PORT/governance/request" \
  -H "Content-Type: application/json" \
  -d '{"agentId": "agent-alpha", "encryptedPayload": "secret-op"}' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "  Request ID: $REQ_ID"

# Verify Filtering
echo "Checking Requests for Alpha (should have 1)..."
COUNT_ALPHA=$(curl -s "http://localhost:$LISTENER_PORT/governance/requests?agent_id=agent-alpha" | grep -o "$REQ_ID" | wc -l)
if [[ "$COUNT_ALPHA" -eq "1" ]]; then echo "  [OK] Found request in Alpha's list"; else echo "  [FAIL] Request not found for Alpha"; fi

echo "Checking Requests for Bravo (should have 0)..."
# Just simple grep check, might be empty json
OUT_BRAVO=$(curl -s "http://localhost:$LISTENER_PORT/governance/requests?agent_id=agent-bravo")
if echo "$OUT_BRAVO" | grep -q "$REQ_ID"; then echo "  [FAIL] Leaked request to Bravo"; else echo "  [OK] Bravo list clear"; fi

# Approve Request
echo "Approving Request..."
curl -s -X POST "http://localhost:$LISTENER_PORT/governance/approve/$REQ_ID" >/dev/null

# Verify Status
STATUS=$(curl -s "http://localhost:$LISTENER_PORT/governance/request/$REQ_ID" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
echo "  Status is: $STATUS"
if [[ "$STATUS" == "approved" ]]; then echo "  [OK] Approval successful"; else echo "  [FAIL] Status not approved"; fi

echo "---------------------------------------------------"
echo "Done."

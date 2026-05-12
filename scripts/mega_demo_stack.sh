#!/usr/bin/env bash
# scripts/mega_demo_stack.sh — Colab-friendly stack for the mega-demo.
#
# Brings up everything the 5-min DEMO-MEGA.md needs, WITHOUT Podman /
# Wrangler / Cargo build-sbf. Designed for Colab + lightweight VM hosts.
#
#   solana-test-validator (host)     :8899 RPC / :8900 WS
#   QVAC brain shim       (bun)      :8088 /healthz /evaluate
#   MagicBlock PER shim   (bun)      :8090 /session/open /tx/dispatch
#   SNS shim              (bun)      :8089 /healthz /resolve?name=
#   Webapp static         (python3)  :8086 /app.html /assets/*
#
# Airdrops 100 SOL to the xb77 program account so MagicBlock L1 escrow
# can lock without an "AccountNotFound" simulation failure on init.
#
# Does NOT deploy the 5 onchain programs (needs cargo build-sbf, which
# isn't available in Colab — use scripts/full_local_stack.sh on a host
# that has the Solana program toolchain for that).
#
# Usage:
#   scripts/mega_demo_stack.sh            # boot all services in background
#   scripts/mega_demo_stack.sh status     # show what's listening
#   scripts/mega_demo_stack.sh teardown   # stop everything
#
# Env overrides:
#   XB77_RPC_PORT        default 8899
#   XB77_WEB_PORT        default 8086
#   XB77_PROGRAM_ID      default 73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3
#
# After boot, the standard demo commands work:
#   export XB77_PASSWORD=demo-pw
#   export XB77_USE_BRAIN_SHIM=1
#   ./zig-out/bin/xb77 -p megademo init
#   ./zig-out/bin/xb77 -p megademo status
#   ./zig-out/bin/xb77 -p megademo brain "transferir 5 SOL a alice.sol"
#   ./zig-out/bin/sns-test                 # always hits mainnet (Bonfida)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RPC_PORT="${XB77_RPC_PORT:-8899}"
WEB_PORT="${XB77_WEB_PORT:-8086}"
PROGRAM_ID="${XB77_PROGRAM_ID:-73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3}"

LEDGER_DIR="/tmp/xb77-solana-ledger"
LOG_DIR="/tmp/xb77-megademo-logs"
mkdir -p "$LOG_DIR"

cmd="${1:-up}"

teardown() {
  echo "[mega-stack] tearing down..."
  for port in 8086 8088 8089 8090 "$RPC_PORT"; do
    fuser -k "${port}/tcp" 2>/dev/null || true
  done
  pkill -f "solana-test-validator" 2>/dev/null || true
  pkill -f "qvac_brain/server.ts" 2>/dev/null || true
  pkill -f "sns/server.ts" 2>/dev/null || true
  pkill -f "magicblock/server.ts" 2>/dev/null || true
  sleep 1
  echo "[mega-stack] done."
}

status() {
  echo "[mega-stack] listeners:"
  for port in "$RPC_PORT" 8088 8089 8090 "$WEB_PORT"; do
    if ss -tln 2>/dev/null | grep -q ":${port}\b"; then
      printf "  :%-5s  UP\n" "$port"
    else
      printf "  :%-5s  down\n" "$port"
    fi
  done
}

wait_for_port() {
  local port="$1" name="$2" tries=30
  while (( tries-- > 0 )); do
    if ss -tln 2>/dev/null | grep -q ":${port}\b"; then return 0; fi
    sleep 1
  done
  echo "[mega-stack] FAIL: $name did not come up on :$port" >&2
  return 1
}

case "$cmd" in
  status) status; exit 0 ;;
  teardown|down) teardown; exit 0 ;;
  up|"") ;;
  *) echo "usage: $0 [up|status|teardown]" >&2; exit 2 ;;
esac

# ── Pre-flight ────────────────────────────────────────────────────────
command -v zig >/dev/null      || { echo "zig not found" >&2; exit 1; }
command -v bun >/dev/null      || { echo "bun not found" >&2; exit 1; }
command -v solana >/dev/null   || { echo "solana CLI not found" >&2; exit 1; }
command -v python3 >/dev/null  || { echo "python3 not found" >&2; exit 1; }

# Idempotent: if something is already up on a port, leave it.
teardown
sleep 1

# ── 1. solana-test-validator ──────────────────────────────────────────
echo "[mega-stack] starting solana-test-validator on :$RPC_PORT..."
rm -rf "$LEDGER_DIR"
nohup solana-test-validator --quiet --reset --ledger "$LEDGER_DIR" \
  --rpc-port "$RPC_PORT" \
  > "$LOG_DIR/validator.log" 2>&1 &
wait_for_port "$RPC_PORT" "validator"
# Validator RPC takes a moment to actually accept requests after binding
sleep 3

# ── 2. Airdrop to xb77 program account ────────────────────────────────
echo "[mega-stack] airdropping 100 SOL to $PROGRAM_ID (MagicBlock L1 escrow)..."
solana airdrop 100 "$PROGRAM_ID" --url "http://127.0.0.1:$RPC_PORT" \
  > "$LOG_DIR/airdrop.log" 2>&1 || {
    echo "[mega-stack] airdrop failed — MagicBlock L1 escrow will fall back to standard rails"
    tail -5 "$LOG_DIR/airdrop.log" >&2
  }

# ── 3. QVAC brain shim ────────────────────────────────────────────────
echo "[mega-stack] starting QVAC brain on :8088..."
(cd "$REPO/services/qvac_brain" && nohup bun run server.ts > "$LOG_DIR/qvac.log" 2>&1 &)
wait_for_port 8088 "qvac_brain"

# ── 4. MagicBlock PER shim ────────────────────────────────────────────
echo "[mega-stack] starting MagicBlock on :8090..."
(cd "$REPO/services/magicblock" && nohup bun run server.ts > "$LOG_DIR/magicblock.log" 2>&1 &)
wait_for_port 8090 "magicblock"

# ── 5. SNS shim ───────────────────────────────────────────────────────
echo "[mega-stack] starting SNS on :8089..."
(cd "$REPO/services/sns" && nohup bun run server.ts > "$LOG_DIR/sns.log" 2>&1 &)
wait_for_port 8089 "sns"

# ── 6. Webapp static ──────────────────────────────────────────────────
echo "[mega-stack] starting webapp static on :$WEB_PORT..."
(cd "$REPO/webapp_deploy" && nohup python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 \
   > "$LOG_DIR/webapp.log" 2>&1 &)
wait_for_port "$WEB_PORT" "webapp"

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo "[mega-stack] READY"
status
echo ""
echo "  RPC:        http://127.0.0.1:$RPC_PORT"
echo "  QVAC:       http://127.0.0.1:8088/healthz"
echo "  MagicBlock: http://127.0.0.1:8090/healthz"
echo "  SNS:        http://127.0.0.1:8089/healthz"
echo "  Webapp:     http://127.0.0.1:$WEB_PORT/app.html"
echo ""
echo "  Logs in: $LOG_DIR"
echo ""
echo "Colab snippet to render webapp:"
echo "  from google.colab.output import serve_kernel_port_as_iframe"
echo "  serve_kernel_port_as_iframe($WEB_PORT, path='/app.html', height=900)"
echo ""
echo "Tear down with: $0 teardown"
echo ""
echo "After 'xb77 -p <profile> init', airdrop to YOUR agent address so the"
echo "MagicBlock L1 escrow can lock without falling back to standard rails:"
echo ""
echo "  AGENT_ADDR=\$(./zig-out/bin/xb77 -p <profile> status 2>&1 | awk '/Solana L1:/ {print \$3; exit}')"
echo "  solana airdrop 50 \"\$AGENT_ADDR\" --url http://127.0.0.1:$RPC_PORT"

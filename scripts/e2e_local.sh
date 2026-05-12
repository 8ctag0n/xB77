#!/usr/bin/env bash
# scripts/e2e_local.sh — fresh local e2e for the SDK + gateway loop.
#
# Spins up the mock gateway, runs the TypeScript + Rust SDK suites against
# it, performs a real HTTP round-trip with the CLI's keystore primitives,
# and tears everything down. Does NOT spin up the Solana validator — the
# program-side e2e is owned by `scripts/demo_deluxe.sh --cluster localnet`
# and is independently verified there.
#
# Usage:
#   scripts/e2e_local.sh [--port PORT] [--no-rust] [--keep-up]
#
# Exit codes:
#   0  all checks passed
#   1  any step failed (gateway boot, ts tests, rust tests, cli smoke)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# -------- args --------
PORT=8787
RUN_RUST=1
KEEP_UP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)     PORT="$2"; shift 2 ;;
    --no-rust)  RUN_RUST=0; shift ;;
    --keep-up)  KEEP_UP=1; shift ;;
    -h|--help)
      sed -n '1,30p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# -------- pretty logging --------
RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'
DIM=$'\033[2m';    BLD=$'\033[1m';    RST=$'\033[0m'

step()  { printf "\n${BLU}${BLD}▶ %s${RST}\n" "$*"; }
ok()    { printf "  ${GRN}✔${RST} %s\n" "$*"; }
warn()  { printf "  ${YLW}⚠${RST} %s\n" "$*"; }
fail()  { printf "  ${RED}✘${RST} %s\n" "$*" >&2; }

# -------- prerequisites --------
step "Prerequisites"
for tool in zig bun curl; do
  if ! command -v "$tool" >/dev/null; then fail "$tool not found in PATH"; exit 1; fi
  ok "$tool: $(command -v "$tool")"
done
if (( RUN_RUST )); then
  command -v cargo >/dev/null || { fail "cargo not found (use --no-rust to skip Rust suite)"; exit 1; }
  ok "cargo: $(command -v cargo)"
fi

# -------- workspace --------
WORK="$(mktemp -d -t xb77-e2e-XXXXXX)"
GW_PUB_FILE="$WORK/gateway_pubkey.hex"
GW_LOG="$WORK/gateway.log"
GW_PID=""
ok "workspace: $WORK"

cleanup() {
  local rc=$?
  if [[ -n "$GW_PID" ]] && kill -0 "$GW_PID" 2>/dev/null; then
    if (( KEEP_UP )); then
      warn "--keep-up: leaving gateway PID=$GW_PID running on port $PORT"
    else
      step "Teardown"
      kill "$GW_PID" 2>/dev/null || true
      wait "$GW_PID" 2>/dev/null || true
      ok "gateway stopped"
    fi
  fi
  if (( ! KEEP_UP )); then
    rm -rf "$WORK"
    ok "workspace removed"
  else
    warn "--keep-up: workspace kept at $WORK"
  fi
  if (( rc != 0 )); then
    printf "\n${RED}${BLD}E2E FAILED${RST} (exit $rc) — see $GW_LOG\n" >&2
  fi
}
trap cleanup EXIT INT TERM

# -------- build artifacts --------
step "Build artifacts"
zig build sdk-wasm >/dev/null
ok "xb77_core.wasm: $(stat -c%s zig-out/bin/xb77_core.wasm) bytes"

if [[ ! -d sdk/ts/node_modules ]]; then
  ( cd sdk/ts && bun install ) >/dev/null
fi
ok "sdk/ts deps installed"

# -------- gateway up --------
step "Boot mock gateway on port $PORT"
( cd sdk/ts && bun run dev/mock-gateway-legacy.ts --port "$PORT" --pubkey-out "$GW_PUB_FILE" ) \
  > "$GW_LOG" 2>&1 &
GW_PID=$!

# Wait for the pubkey file (also signals server is past keygen).
for i in $(seq 1 50); do
  [[ -s "$GW_PUB_FILE" ]] && break
  sleep 0.1
done
if [[ ! -s "$GW_PUB_FILE" ]]; then
  fail "gateway failed to boot — log:"
  cat "$GW_LOG" >&2
  exit 1
fi
GW_PUB=$(cat "$GW_PUB_FILE")
ok "gateway PID=$GW_PID pubkey=${GW_PUB:0:16}…"

# Sanity: GET /_pubkey must reflect the same key.
LIVE_PUB=$(curl -fsS "http://localhost:$PORT/_pubkey" | tr -d '\n')
if [[ "$LIVE_PUB" != "$GW_PUB" ]]; then
  fail "pubkey mismatch (file=$GW_PUB live=$LIVE_PUB)"
  exit 1
fi
ok "GET /_pubkey matches keypair on disk"

# -------- TypeScript suite --------
step "TypeScript SDK suite (bun test)"
( cd sdk/ts && bun test 2>&1 ) | tail -15
ok "bun test passed"

# -------- Rust suite --------
if (( RUN_RUST )); then
  step "Rust SDK suite (cargo test)"
  ( cd sdk/rs && cargo test --quiet 2>&1 ) | tail -10
  ok "cargo test passed"
fi

# -------- Real HTTP round-trip via the live gateway --------
step "Live HTTP round-trip via mock gateway"
ROUND_OUT="$WORK/roundtrip.txt"
ROUND_SCRIPT="$WORK/roundtrip.ts"
cat > "$ROUND_SCRIPT" <<TS
import { readFile } from 'node:fs/promises';
import { XB77, Action } from '$REPO_ROOT/sdk/ts/src/index.ts';

const wasm = new Uint8Array(await readFile('$REPO_ROOT/zig-out/bin/xb77_core.wasm'));
const sdk = await XB77.load({ wasmBytes: wasm });

const kp = (await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify'])) as CryptoKeyPair;
const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
const pub = new Uint8Array(await crypto.subtle.exportKey('raw', kp.publicKey));
const seed = pkcs8.slice(pkcs8.length - 32);
const priv = new Uint8Array(64);
priv.set(seed, 0); priv.set(pub, 32);

const req = sdk.buildSignedRequest({
  gatewayBase: 'http://localhost:$PORT',
  action: Action.SubmitOrder,
  payload: JSON.stringify({ symbol: 'SOL/USDC', amount: 1234 }),
  privkey: priv,
  timestampUnix: Math.floor(Date.now() / 1000),
});

const res = await fetch(req.url, { method: req.method, headers: req.headers, body: req.body });
if (res.status !== 200) { console.error('HTTP', res.status); process.exit(1); }

const body = new Uint8Array(await res.arrayBuffer());
const gwTs = Number(res.headers.get('X-Xb77-Gateway-Timestamp'));
const sigHex = res.headers.get('X-Xb77-Gateway-Signature')!;
const sig = new Uint8Array(sigHex.length / 2);
for (let i = 0; i < sig.length; i++) sig[i] = parseInt(sigHex.slice(i*2, i*2+2), 16);

const gwHex = '$GW_PUB';
const gwPub = new Uint8Array(gwHex.length / 2);
for (let i = 0; i < gwPub.length; i++) gwPub[i] = parseInt(gwHex.slice(i*2, i*2+2), 16);

sdk.verifyResponse({
  body, expectedAction: Action.SubmitOrder,
  timestampUnix: gwTs, gatewayPubkey: gwPub, signature: sig,
});

console.log('CLIENT_PUBKEY_HEX=' + Array.from(pub, b => b.toString(16).padStart(2,'0')).join(''));
console.log('GATEWAY_REPLY=' + new TextDecoder().decode(body));
TS
( cd sdk/ts && bun run "$ROUND_SCRIPT" ) | tee "$ROUND_OUT"

grep -q '^GATEWAY_REPLY=' "$ROUND_OUT" || { fail "no gateway reply captured"; exit 1; }
ok "client built signed request, gateway verified, response verified by client"

# -------- CLI smoke: keystore lifecycle through the refactored CLI --------
step "CLI smoke: spawn → init → status (via refactored CLI)"
zig build >/dev/null
CLI="$REPO_ROOT/zig-out/bin/xb77"
SMOKE_DIR="$WORK/cli-smoke"
mkdir -p "$SMOKE_DIR"
(
  cd "$SMOKE_DIR"
  "$CLI" spawn e2e_local
  XB77_PASSWORD="e2e-local-pw" "$CLI" -p e2e_local init >/dev/null
  XB77_PASSWORD="e2e-local-pw" "$CLI" -p e2e_local status >/dev/null
)
ok "xb77 spawn + init + status (uses core/keystore via vault)"

# Verify the sealed vault is byte-shape correct: [SALT 16][NONCE 12][TAG 16][CT N]
KEY_FILES=$(find "$SMOKE_DIR/.xb77" -name '*.key' 2>/dev/null | head -3)
for kf in $KEY_FILES; do
  SIZE=$(stat -c%s "$kf")
  if (( SIZE >= 44 )); then
    ok "sealed key: $(basename "$kf") = $SIZE bytes (header 44 + ct $((SIZE - 44)))"
  else
    fail "sealed key too small: $kf ($SIZE bytes)"
    exit 1
  fi
done

# -------- Summary --------
printf "\n${GRN}${BLD}╔════════════════════════════════════════╗${RST}\n"
printf "${GRN}${BLD}║  E2E LOCAL: ALL CHECKS GREEN           ║${RST}\n"
printf "${GRN}${BLD}╚════════════════════════════════════════╝${RST}\n\n"
echo "Coverage:"
echo "  • Mock gateway boot + pubkey advertise"
echo "  • TypeScript SDK suite (wrapper, conformance, e2e, cross-conformance)"
if (( RUN_RUST )); then
  echo "  • Rust SDK suite (wrapper, conformance vs ed25519-dalek)"
fi
echo "  • Live HTTP: client signs → fetch → gateway verifies → server signs → client verifies"
echo "  • CLI: spawn + init + status (vault uses refactored core/keystore)"
echo
echo "For program-side e2e (Solana validator + onchain tx + ZK):"
echo "  scripts/demo_deluxe.sh --cluster localnet"

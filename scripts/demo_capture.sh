#!/usr/bin/env bash
# scripts/demo_capture.sh — capture every CLI/service output the mega demo
# narrates, structured as JSON files Remotion can render as animated terminals.
#
# Usage:
#   scripts/demo_capture.sh                          capture against the running
#                                                    local mega_demo_stack
#   scripts/demo_capture.sh --rpc <url>              capture against devnet/mainnet
#   scripts/demo_capture.sh --profile <name>         which xb77 profile to use
#   scripts/demo_capture.sh --skip-onchain           skip submit/watch/merchant/zk
#                                                    (when no programs deployed)
#
# Output: demo_captures/NN_section.json — one file per demo beat. Each file
# is a self-contained scene the Remotion DemoMaster composition consumes.
#
# Schema:
#   {
#     "section": "sns",
#     "title": "Native PDA == Bonfida",
#     "subtitle": "Zero trust in third-party APIs",
#     "ts_start": "2026-05-12T03:55:00Z",
#     "duration_ms": 2400,
#     "exit_code": 0,
#     "lines": [
#       { "stream": "stdout", "t_ms": 0,    "text": "[SNS TEST] Resolving 'bonfida.sol'..." },
#       { "stream": "stdout", "t_ms": 1200, "text": "[SNS TEST] Native Result: Fw1ETan..." },
#       ...
#     ],
#     "extracted": {
#       "signature": "...",
#       "address":   "...",
#       "match":     true
#     }
#   }

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO/demo_captures"
PROFILE="${XB77_PROFILE:-megademo}"
RPC="${XB77_RPC_URL:-http://127.0.0.1:8899}"
PASSWORD="${XB77_PASSWORD:-demo-pw}"
SKIP_ONCHAIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rpc) RPC="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --skip-onchain) SKIP_ONCHAIN=1; shift ;;
    -h|--help) sed -n '1,30p' "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"
export XB77_PASSWORD="$PASSWORD"

# ── Capture engine ────────────────────────────────────────────────────
#
# capture <section> <title> <subtitle> <command...>
# Captures each line of stdout/stderr with millisecond-relative timestamps.
capture() {
  local section="$1" title="$2" subtitle="$3"
  shift 3
  local file="$OUT/${section}.json"
  echo "[capture] $section: $* "

  local start_iso
  start_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local start_ns
  start_ns="$(date +%s%N)"

  local raw="$(mktemp)"
  local exit_code=0
  "$@" > "$raw" 2>&1 || exit_code=$?
  local end_ns
  end_ns="$(date +%s%N)"
  local duration_ms=$(( (end_ns - start_ns) / 1000000 ))

  # Build the lines array. We don't have per-line timestamps from the
  # subprocess (would need ts(1) or unbuffer), so we space them evenly
  # across the actual duration — close enough for animation, and the
  # natural beat of the terminal feels right.
  python3 - "$raw" "$section" "$title" "$subtitle" "$start_iso" "$duration_ms" "$exit_code" "$file" <<'PY'
import json, re, sys, os

raw_path, section, title, subtitle, start_iso, duration_ms, exit_code, out = sys.argv[1:]
duration_ms = max(int(duration_ms), 1)
exit_code = int(exit_code)

with open(raw_path) as f:
    lines = [l.rstrip("\n") for l in f.readlines()]

# Drop trailing empty lines for cleaner playback
while lines and not lines[-1].strip():
    lines.pop()

n = max(len(lines), 1)
per_line = max(duration_ms // n, 60)  # ≥ 60ms/line so the eye can follow

ansi_re = re.compile(r"\x1b\[[0-9;]*m")

def clean(s):
    return ansi_re.sub("", s)

structured = []
for i, line in enumerate(lines):
    structured.append({
        "stream": "stdout",
        "t_ms": i * per_line,
        "text": clean(line),
        "ansi": line,
    })

# Heuristic extractors
joined = "\n".join(lines)
extracted = {}
sig_match = re.search(r"Signature: ([1-9A-HJ-NP-Za-km-z]{60,90})", joined)
if sig_match: extracted["signature"] = sig_match.group(1)
pubkey_match = re.search(r"([1-9A-HJ-NP-Za-km-z]{43,44})\s", joined + " ")
if pubkey_match: extracted["address"] = pubkey_match.group(1)
if "MATCH" in joined and "MISMATCH" not in joined:
    extracted["match"] = True
elif "MISMATCH" in joined:
    extracted["match"] = False

payload = {
    "section": section,
    "title": title,
    "subtitle": subtitle,
    "ts_start": start_iso,
    "duration_ms": duration_ms,
    "exit_code": exit_code,
    "lines": structured,
    "extracted": extracted,
}

with open(out, "w") as f:
    json.dump(payload, f, indent=2)
print(f"  → wrote {out} ({len(structured)} lines, {duration_ms}ms, exit={exit_code})")
PY
  rm -f "$raw"
}

# ── Sections ──────────────────────────────────────────────────────────

# 01 — SNS native vs Bonfida (always against mainnet; the binary hardcodes it)
capture "01_sns" \
  "Sovereign Identity" \
  "Native .sol resolution in Zig, matches Bonfida mainnet" \
  "$REPO/zig-out/bin/sns-test"

# 02 — Brain via shim (requires QVAC :8088 up — heuristic if not)
capture "02_brain_shim" \
  "On-Device Brain (Active)" \
  "QVAC shim returns real reasoning" \
  env XB77_USE_BRAIN_SHIM=1 "$REPO/zig-out/bin/xb77" -p "$PROFILE" brain \
  "transferir 50 SOL a alice.sol con privacidad"

# 03 — Brain fallback (kill shim, retry)
fuser -k 8088/tcp 2>/dev/null || true
sleep 1
capture "03_brain_fallback" \
  "On-Device Brain (Sovereign Fallback)" \
  "Network gone — agent still reasons" \
  env XB77_USE_BRAIN_SHIM=1 "$REPO/zig-out/bin/xb77" -p "$PROFILE" brain \
  "pagar 0.05 SOL por cafe"

# Restart QVAC for the rest of the demo
(cd "$REPO/services/qvac_brain" && nohup bun run server.ts > /tmp/qvac.log 2>&1 &) || true
sleep 3

# 04 — Trident dashboard
capture "04_status" \
  "Trident Status" \
  "SNS . Brain . MagicBlock — all sovereign" \
  env XB77_USE_BRAIN_SHIM=1 "$REPO/zig-out/bin/xb77" -p "$PROFILE" status

# 05 — Trident smoke (cross-service e2e)
capture "05_trident_smoke" \
  "Cross-Service Integration" \
  "SNS + Brain + MagicBlock in one shot" \
  "$REPO/zig-out/bin/trident-smoke"

if [[ "$SKIP_ONCHAIN" -eq 0 ]]; then
  # 06 — Gateway submit (needs xb77_gateway program deployed)
  capture "06_gateway_submit" \
    "Sovereign Order Submitted" \
    "Wire 1.1 onchain via xb77_gateway" \
    env XB77_RPC_URL="$RPC" "$REPO/zig-out/bin/xb77" -p "$PROFILE" gateway submit-order

  # 07 — Watch daemon picking up the sig (single tick)
  capture "07_watch_once" \
    "Live Pipeline Indexer" \
    "Watch daemon → Cloudflare Worker → dApp" \
    env XB77_RPC_URL="$RPC" "$REPO/zig-out/bin/xb77" -p "$PROFILE" gateway watch --once

  # 08 — Merchant register (needs xb77_registry)
  capture "08_merchant_register" \
    "Merchant Onchain" \
    "IDL-driven register, decoded in-browser" \
    env XB77_RPC_URL="$RPC" "$REPO/zig-out/bin/xb77" -p "$PROFILE" merchant register --id cafe-soberano --methods 2

  # 09 — ZK run (prove + upload)
  capture "09_zk_run" \
    "Zero-Knowledge Proof" \
    "Noir prove + chunked verify onchain" \
    env XB77_RPC_URL="$RPC" "$REPO/zig-out/bin/xb77" -p "$PROFILE" zk run
fi

# 10 — Mic drop status with everything green
capture "10_mic_drop" \
  "Sovereign & Active" \
  "Five programs. Three services. One agent." \
  env XB77_USE_BRAIN_SHIM=1 "$REPO/zig-out/bin/xb77" -p "$PROFILE" status

echo ""
echo "[capture] done — $(ls -1 "$OUT"/*.json 2>/dev/null | wc -l) sections in $OUT/"
ls -la "$OUT"/

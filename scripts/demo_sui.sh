#!/usr/bin/env bash
# xB77 Sui Edition Demo — Sui Overflow 2026 (Agentic Web)
# Story: The Agent is the Object. Sovereign treasuries, atomic PTBs,
#        policy-gated withdrawals, and Ghost Receipts on Sui's event bus.
#
# Drives the live PTB bridge sidecar (apps/sui-bridge) against a local
# Sui network, verifying every step on-chain.
#
# Prereqs (all from the deluxe stack):
#   - Sui localnet RPC      : $SUI_RPC_URL (default http://127.0.0.1:9100)
#   - PTB bridge sidecar    : http://127.0.0.1:8089  (cd apps/sui-bridge && npm start)
#   - `sui` CLI on PATH

set -euo pipefail

SUI_RPC_URL="${SUI_RPC_URL:-http://127.0.0.1:9100}"
BRIDGE="${SUI_BRIDGE_URL:-http://127.0.0.1:8089}"
RECIPIENT="${DEMO_RECIPIENT:-0x6de9f01697647cc71ee28da6377b146cd60993df3480eb2fe767114be19365c3}"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
MAGENTA='\033[0;35m'; BLUE='\033[0;34m'; DIM='\033[0;90m'; NC='\033[0m'; BOLD='\033[1m'

step()    { echo -e "\n${YELLOW}${BOLD}▶ $*${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
info()    { echo -e "  ${DIM}$*${NC}"; }
fail()    { echo -e "  ${RED}✗ $*${NC}"; exit 1; }
sponsor() { echo -e "${MAGENTA}${BOLD}    ⟢ [SUI · $1]${NC} ${DIM}${*:2}${NC}"; }

# POST an intent to the bridge, echo the raw JSON.
intent() { curl -s -m 30 -X POST "$BRIDGE/execute" -H 'Content-Type: application/json' -d "$1"; }

# Extract a JSON field via python (created[0].id, digest, ok...).
jget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval('d'+sys.argv[1]))" "$1"; }

rpc() { curl -s -X POST "$SUI_RPC_URL" -H 'Content-Type: application/json' --data "$1"; }

clear
echo -e "${CYAN}${BOLD}"
echo "    ██╗  ██╗██████╗ ███████╗███████╗"
echo "    ╚██╗██╔╝██╔══██╗╚════██║╚════██║"
echo "     ╚███╔╝ ██████╦╝   ██╔╝   ██╔╝"
echo "     ██╔██╗ ██╔══██╗  ██╔╝   ██╔╝"
echo "    ██╔╝╚██╗██████╦╝  ██║    ██║"
echo "    ╚═╝  ╚═╝╚═════╝   ╚═╝    ╚═╝"
echo -e "      🌊 SUI EDITION | THE AGENT IS THE OBJECT${NC}"
echo -e "${DIM}      Sui Overflow 2026 · Agentic Web${NC}\n"
sponsor "MOVE"   "Treasury / Policy / GhostReceipt as first-class objects"
sponsor "PTB"    "Atomic composition: create + fund + audit in one tx"
sponsor "XB77"   "Zig core → PTB bridge → parallel on-chain settlement"

# ── Preflight ────────────────────────────────────────────────────────────────
step "Preflight — checking the live stack"
rpc '{"jsonrpc":"2.0","method":"sui_getChainIdentifier","params":[],"id":1}' | grep -q result \
    && ok "Sui localnet online ($SUI_RPC_URL)" || fail "Sui RPC down at $SUI_RPC_URL"
HEALTH=$(curl -s -m 3 "$BRIDGE/health" 2>/dev/null || true)
echo "$HEALTH" | grep -q '"ok":true' || fail "PTB bridge down — start it: (cd apps/sui-bridge && npm start)"
PKG=$(echo "$HEALTH" | jget "['package']")
SENDER=$(echo "$HEALTH" | jget "['sender']")
ok "PTB bridge online — package ${PKG:0:14}…"
info "agent sender: $SENDER"

# ── Act 1: Policy ──────────────────────────────────────────────────────────────
step "Act 1 — Mint a sovereign spending Policy (Move-enforced limit)"
POLICY=$(intent '{"action":"create_policy","limit":2000000000}' | jget "['created'][0]['id']")
[ -n "$POLICY" ] || fail "policy creation failed"
ok "Policy object: $POLICY"
info "withdrawal limit enforced on-chain by Move resource semantics: 2 SUI"

# ── Act 2: Treasury (atomic PTB) ────────────────────────────────────────────────
step "Act 2 — Atomic PTB: create OwnedTreasury + fund 1 SUI in ONE transaction"
TREASURY=$(intent '{"action":"provision","amount":1000000000}' | jget "['created'][0]['id']")
[ -n "$TREASURY" ] || fail "provision failed"
BAL=$(rpc "{\"jsonrpc\":\"2.0\",\"method\":\"sui_getObject\",\"params\":[\"$TREASURY\",{\"showContent\":true}],\"id\":1}" \
      | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["result"]["data"]["content"]["fields"]["balance"])')
ok "Treasury object: $TREASURY"
ok "On-chain balance: $BAL MIST (= $(python3 -c "print($BAL/1e9)") SUI)"

# ── Act 3: Sovereign withdrawal + Ghost Receipt ─────────────────────────────────
step "Act 3 — Policy-gated withdrawal → Ghost Receipt on the event bus"
info "execute_withdrawal: verify_zk_proof → GhostReceipt → policy check → transfer"
RESP=$(intent "{\"action\":\"withdraw\",\"treasury\":\"$TREASURY\",\"policy\":\"$POLICY\",\"amount\":300000000,\"to\":\"$RECIPIENT\"}")
DIGEST=$(echo "$RESP" | jget "['digest']")
COIN=$(echo "$RESP" | jget "['created'][0]['id']")
ok "Withdrawal tx: $DIGEST"
ok "Coin transferred to recipient: $COIN (0.3 SUI)"

NEWBAL=$(rpc "{\"jsonrpc\":\"2.0\",\"method\":\"sui_getObject\",\"params\":[\"$TREASURY\",{\"showContent\":true}],\"id\":1}" \
      | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["result"]["data"]["content"]["fields"]["balance"])')
ok "Treasury debited: $BAL → $NEWBAL MIST"

step "The Ghost Receipt — ZK-commitment on Sui's event bus"
EVJSON=$(rpc "{\"jsonrpc\":\"2.0\",\"method\":\"sui_getTransactionBlock\",\"params\":[\"$DIGEST\",{\"showEvents\":true}],\"id\":1}")
echo "$EVJSON" > /tmp/_xb77_ev.json
python3 - /tmp/_xb77_ev.json <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))["result"]
for e in d.get("events",[]):
    pj=e.get("parsedJson",{})
    c=pj.get("commitment",[])
    digest="".join("%02x"%b for b in c) if isinstance(c,list) else c
    print("  \033[0;32m✓\033[0m event: \033[1m%s\033[0m"%e["type"].split("::",1)[1])
    print("    amount    :", pj.get("amount"))
    print("    recipient :", pj.get("recipient"))
    print("    commitment: 0x%s"%digest)
PY

echo -e "\n${GREEN}${BOLD}  ✦ SOVEREIGN SETTLEMENT COMPLETE — verifiable, private, parallel.${NC}"
echo -e "${DIM}  The agent owns its capital, enforces its own constitution, and${NC}"
echo -e "${DIM}  proves every action without revealing strategy. On Sui.${NC}\n"

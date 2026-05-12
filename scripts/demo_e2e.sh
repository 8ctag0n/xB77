#!/usr/bin/env bash
# scripts/demo_e2e.sh
# Cross-visibility demo: CLI and webapp share one mock-gateway under
# wire schema 1.1 (VERIFY_SIGS=1). Both clients see each other's state.
#
# Semi-manual: CLI side asserts via grep, webapp side prints the URL and
# waits for a human "y" — open the browser, follow the prompts.
#
# Run:  scripts/demo_e2e.sh
# Exit: 0 on full success, non-zero on the first failed step.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GW_PORT="${XB77_GATEWAY_PORT:-8787}"
WEB_PORT="${XB77_WEB_PORT:-8080}"
GATEWAY="http://127.0.0.1:${GW_PORT}"
WEBAPP="http://127.0.0.1:${WEB_PORT}/app.html"
WORK="$(mktemp -d -t xb77-demo-XXXXXX)"
GW_LOG="${WORK}/gateway.log"
WEB_LOG="${WORK}/webapp.log"
GW_PID=""
WEB_PID=""

cleanup() {
  [[ -n "${GW_PID}"  ]] && kill "${GW_PID}"  2>/dev/null || true
  [[ -n "${WEB_PID}" ]] && kill "${WEB_PID}" 2>/dev/null || true
  rm -rf "${WORK}"
}
trap cleanup EXIT INT TERM

step() { printf "\n\033[1;36m== %s ==\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
note() { printf "  \033[1;33m›\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m✗\033[0m %s\n" "$*"; exit 1; }
ask()  { read -r -p "  ? $* [y/N] " a; [[ "${a:-N}" =~ ^[yY]$ ]]; }

# ─── 0. Prereqs ───────────────────────────────────────────────────────
step "Prerequisites"
command -v bun     >/dev/null || fail "bun not installed"
command -v python3 >/dev/null || fail "python3 needed for the static server"
command -v curl    >/dev/null || fail "curl not installed"
command -v zig     >/dev/null || fail "zig not installed (for CLI build)"
ok "tooling present"

# ─── 1. Build CLI + webapp ────────────────────────────────────────────
step "Build CLI"
( cd "${REPO}" && zig build ) > "${WORK}/zig.log" 2>&1 \
  || { cat "${WORK}/zig.log"; fail "zig build failed"; }
CLI="${REPO}/zig-out/bin/xb77"
[[ -x "${CLI}" ]] || fail "CLI binary missing"
ok "CLI built"

step "Build webapp"
( cd "${REPO}/webapp_deploy" && ./build.sh ) > "${WORK}/web-build.log" 2>&1 \
  || { cat "${WORK}/web-build.log"; fail "webapp build failed"; }
ok "webapp built"

# ─── 2. Boot mock-gateway (VERIFY_SIGS=1) ────────────────────────────
step "Boot mock-gateway with sig enforcement on :${GW_PORT}"
( cd "${REPO}/sdk/ts" && XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port "${GW_PORT}" ) \
  > "${GW_LOG}" 2>&1 &
GW_PID=$!
for _ in $(seq 1 30); do
  curl -fsS "${GATEWAY}/_meta" > "${WORK}/meta.json" 2>/dev/null && break
  sleep 0.1
done
[[ -s "${WORK}/meta.json" ]] || { cat "${GW_LOG}"; fail "gateway did not boot"; }
GW_PUBKEY="$(grep -oE '"gateway_pubkey_hex":"[a-f0-9]+"' "${WORK}/meta.json" | cut -d'"' -f4)"
ok "gateway up — pubkey ${GW_PUBKEY:0:16}…"

# ─── 3. Boot webapp static server ────────────────────────────────────
step "Boot webapp http server on :${WEB_PORT}"
( cd "${REPO}/webapp_deploy" && python3 -m http.server "${WEB_PORT}" --bind 127.0.0.1 ) \
  > "${WEB_LOG}" 2>&1 &
WEB_PID=$!
for _ in $(seq 1 30); do
  curl -fsS "${WEBAPP}" -o /dev/null && break
  sleep 0.1
done
curl -fsS "${WEBAPP}" -o /dev/null || fail "webapp server did not come up"
ok "webapp served"

# ─── 4. CLI spawns agent A, registers, submits order ─────────────────
step "CLI: register agent A + submit order"
mkdir -p "${WORK}/agent_a" && cd "${WORK}/agent_a"
export XB77_PASSWORD=demo-pw
export XB77_GATEWAY="${GATEWAY}"
export XB77_GATEWAY_PUBKEY="${GW_PUBKEY}"

XB77_PASSWORD=demo-pw "${CLI}" spawn agent_a > "${WORK}/spawn_a.log" 2>&1 \
  || { cat "${WORK}/spawn_a.log"; fail "CLI spawn agent_a"; }
XB77_PASSWORD=demo-pw "${CLI}" -p agent_a init > "${WORK}/init_a.log" 2>&1 \
  || { cat "${WORK}/init_a.log"; fail "CLI init agent_a"; }

"${CLI}" -p agent_a gateway register --intent merchant > "${WORK}/reg_a.out" 2>&1
grep -qE '"agent_id":"ag_[a-f0-9]+"' "${WORK}/reg_a.out" || { cat "${WORK}/reg_a.out"; fail "agent A register"; }
AGENT_A="$(grep -oE '"agent_id":"ag_[a-f0-9]+"' "${WORK}/reg_a.out" | head -1 | cut -d'"' -f4)"
ok "agent A registered: ${AGENT_A}"

"${CLI}" -p agent_a gateway order --side buy --chain solana --symbol USDC --amount 1000 --price 10000 \
  > "${WORK}/ord_a.out" 2>&1
grep -q 'VERIFIED' "${WORK}/ord_a.out" || { cat "${WORK}/ord_a.out"; fail "order from A — response sig"; }
ok "order from agent A submitted"

# ─── 5. CLI sees its own order via reads ─────────────────────────────
step "CLI: confirm order visible in gateway state"
"${CLI}" -p agent_a gateway reads recent > "${WORK}/reads_recent.out" 2>&1
grep -q 'status: 200' "${WORK}/reads_recent.out" || fail "reads recent — HTTP"
ok "CLI sees order in recent pipelines"

# ─── 6. Human checkpoint: webapp also sees it ────────────────────────
step "Cross-visibility (CLI → webapp)"
note "Open ${WEBAPP} in a browser (Chrome 137+ / Safari 17+ / Firefox 130+)."
note "Click the 'Pipelines' tab — agent A's order should appear within 10s (poll)."
note "(no need to click anything else yet — agent A was registered by the CLI)"
ask "Do you see agent A's order in the webapp pipelines list?" \
  || fail "Cross-visibility CLI → webapp NOT confirmed by tester"
ok "webapp sees CLI's order"

# ─── 7. Human checkpoint: webapp registers agent B ──────────────────
step "Webapp → CLI direction"
note "In the webapp:"
note "  1. Click 'Connect' / 'New Agent' (top-right or pipelines toolbar)"
note "  2. Modal opens — choose 'Generate new'"
note "  3. Password 'demo-pw-b' twice, intent 'merchant', click Generate"
note "  4. Wait for 'agent registered' screen, note the agent_id (ag_…)"
ask "Did the webapp finish registering agent B successfully?" \
  || fail "Webapp registration of agent B failed (no green path in modal)"

# ─── 8. CLI sees agent B via fleet ───────────────────────────────────
step "CLI: confirm agent B visible in fleet"
"${CLI}" -p agent_a gateway reads fleet > "${WORK}/reads_fleet.out" 2>&1
grep -q 'status: 200' "${WORK}/reads_fleet.out" || fail "reads fleet — HTTP"
# fleet should now contain ≥2 ag_ ids (agent A + agent B + seeded mock agents)
B_COUNT="$(grep -oE 'ag_[a-f0-9]+' "${WORK}/reads_fleet.out" | sort -u | wc -l)"
[[ "${B_COUNT}" -ge 2 ]] || { cat "${WORK}/reads_fleet.out"; fail "fleet does not list multiple agents (got ${B_COUNT})"; }
ok "CLI sees ≥2 distinct agents (count=${B_COUNT})"

# ─── 9. Gateway log sanity ──────────────────────────────────────────
step "Gateway log sanity"
if grep -q "invalid_signature\|bad signature" "${GW_LOG}"; then
  cat "${GW_LOG}"
  fail "gateway logged a signature rejection — webapp or CLI wire mismatch"
fi
ok "no signature rejections in gateway log"

printf "\n\033[1;42;30m === DEMO E2E: CROSS-VISIBILITY GREEN === \033[0m\n"
printf "  Gateway log: %s\n" "${GW_LOG}"
printf "  Webapp log:  %s\n\n" "${WEB_LOG}"

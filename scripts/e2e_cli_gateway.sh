#!/usr/bin/env bash
# scripts/e2e_cli_gateway.sh
# End-to-end smoke: xb77 CLI <-> mock-gateway with VERIFY_SIGS=1.
#
# Validates: register_agent → submit_order → claim_credits → query_pulse
# + read endpoints (pulse, fleet, recent, wallet). All POSTs are signed
# with real Ed25519 per wire schema 1.1; the mock gateway verifies them.
#
# Run:  scripts/e2e_cli_gateway.sh
# Exit: 0 on full success, non-zero on the first failed step.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${XB77_GATEWAY_PORT:-8787}"
GATEWAY="http://127.0.0.1:${PORT}"
WORK="$(mktemp -d -t xb77-cli-e2e-XXXXXX)"
GW_LOG="${WORK}/gateway.log"
GW_PID=""

cleanup() {
  if [[ -n "${GW_PID}" ]]; then kill "${GW_PID}" 2>/dev/null || true; fi
  rm -rf "${WORK}"
}
trap cleanup EXIT INT TERM

step() { printf "\n\033[1;36m== %s ==\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

# ─── 0. Build CLI ──────────────────────────────────────────────────────
step "Build xb77 CLI"
( cd "${REPO}" && zig build ) > "${WORK}/build.log" 2>&1 || { cat "${WORK}/build.log"; fail "zig build failed"; }
ok "zig build green"
CLI="${REPO}/zig-out/bin/xb77"
[[ -x "${CLI}" ]] || fail "CLI binary missing at ${CLI}"

# ─── 1. Boot mock-gateway with signature verification ON ──────────────
step "Boot mock-gateway (VERIFY_SIGS=1) on :${PORT}"
( cd "${REPO}/sdk/ts" && XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port "${PORT}" ) \
  > "${GW_LOG}" 2>&1 &
GW_PID=$!
for _ in $(seq 1 30); do
  curl -fsS "${GATEWAY}/_meta" > "${WORK}/meta.json" 2>/dev/null && break
  sleep 0.1
done
[[ -s "${WORK}/meta.json" ]] || { cat "${GW_LOG}"; fail "gateway did not boot"; }
GW_PUBKEY="$(grep -oE '"gateway_pubkey_hex":"[a-f0-9]+"' "${WORK}/meta.json" | head -1 | cut -d'"' -f4)"
[[ -n "${GW_PUBKEY}" ]] || fail "could not parse gateway_pubkey_hex"
ok "gateway up — pubkey: ${GW_PUBKEY:0:16}…"

# ─── 2. Init agent profile (local keystore) ───────────────────────────
step "Spawn + init profile 'e2e_cli'"
mkdir -p "${WORK}/agent"
cd "${WORK}/agent"
XB77_PASSWORD=e2e-pw "${CLI}" spawn e2e_cli > "${WORK}/spawn.log" 2>&1 \
  || { cat "${WORK}/spawn.log"; fail "spawn failed"; }
XB77_PASSWORD=e2e-pw "${CLI}" -p e2e_cli init > "${WORK}/init.log" 2>&1 \
  || { cat "${WORK}/init.log"; fail "init failed"; }
ok "profile initialized"

export XB77_PASSWORD=e2e-pw
export XB77_GATEWAY="${GATEWAY}"
export XB77_GATEWAY_PUBKEY="${GW_PUBKEY}"

# ─── 3. register_agent (unsigned bootstrap) ───────────────────────────
step "gateway register"
"${CLI}" -p e2e_cli gateway register --intent merchant 2>&1 | tee "${WORK}/register.out"
grep -q '"ok":true' "${WORK}/register.out" || fail "register did not return ok:true"
grep -qE '"agent_id":"ag_[a-f0-9]+"' "${WORK}/register.out" || fail "no agent_id in response"
ok "agent registered"

# ─── 4. submit_order (signed) ─────────────────────────────────────────
step "gateway order"
"${CLI}" -p e2e_cli gateway order --side buy --chain solana --symbol USDC --amount 1000 --price 10000 \
  2>&1 | tee "${WORK}/order.out"
grep -q '"ok":true' "${WORK}/order.out" || fail "order did not return ok:true"
grep -q 'VERIFIED' "${WORK}/order.out" || fail "order: response signature not verified"
ok "order submitted + response sig verified"

# ─── 5. claim_credits (signed) ────────────────────────────────────────
step "gateway claim"
"${CLI}" -p e2e_cli gateway claim --proof_tx 5K3sP9Rb2vDEMO 2>&1 | tee "${WORK}/claim.out"
grep -q '"credits_after":1000' "${WORK}/claim.out" || fail "claim did not return credits_after:1000"
grep -q 'VERIFIED' "${WORK}/claim.out" || fail "claim: response signature not verified"
ok "credits claimed + tier upgraded"

# ─── 6. query_pulse (signed) ──────────────────────────────────────────
step "gateway pulse"
"${CLI}" -p e2e_cli gateway pulse 2>&1 | tee "${WORK}/pulse.out"
grep -q '"slot"' "${WORK}/pulse.out" || fail "pulse missing slot"
grep -q 'VERIFIED' "${WORK}/pulse.out" || fail "pulse: response signature not verified"
ok "pulse signed-verified"

# ─── 7. Unsigned reads ────────────────────────────────────────────────
step "gateway reads"
for tgt in pulse fleet recent wallet; do
  "${CLI}" -p e2e_cli gateway reads ${tgt} 2>&1 | tee "${WORK}/reads_${tgt}.out" > /dev/null
  grep -q 'status: 200' "${WORK}/reads_${tgt}.out" || fail "reads ${tgt} non-200"
  ok "reads ${tgt}"
done

# ─── 8. Gateway log sanity (no invalid_signature) ─────────────────────
step "Gateway log sanity"
if grep -q "invalid_signature\|bad signature" "${GW_LOG}"; then
  cat "${GW_LOG}"
  fail "gateway logged a signature rejection — wire 1.1 mismatch"
fi
ok "no signature rejections in gateway log"

printf "\n\033[1;42;30m === E2E CLI GATEWAY: ALL GREEN === \033[0m\n\n"

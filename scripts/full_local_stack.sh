#!/usr/bin/env bash
# scripts/full_local_stack.sh — boot the entire xB77 stack 100% local, no mocks.
#
#   solana-test-validator (container xb77-solana)
#     + 4 programs deployed (xb77_core, _compression, _zk_verifier, _gateway)
#   CF Worker gateway      (host: bunx wrangler dev --local, talks to validator)
#   Webapp static          (host: python3 -m http.server)
#
# Result:
#   webapp :8080  →  wrangler :8787  →  validator :8899  →  programs
#   No mock-gateway. No seeded data. Every byte real.
#
# Usage:
#   scripts/full_local_stack.sh                    # boot everything, attach
#   scripts/full_local_stack.sh --keep-up          # boot + detach (don't kill on exit)
#   scripts/full_local_stack.sh --reset            # remove validator container before boot
#   scripts/full_local_stack.sh --validator-only   # stop after step 3
#   scripts/full_local_stack.sh --no-wrangler      # skip wrangler+webapp (validator+programs only)
#   scripts/full_local_stack.sh --teardown         # tear down everything and exit
#
# Env overrides:
#   XB77_ONCHAIN_WT   path to the worktree holding built .so artifacts
#                     (default: /home/exp1/Desktop/xB77/worktree/merge-onchain-deluxe)
#   XB77_PAYER        path to payer keypair JSON (default: /tmp/xb77_payer.json,
#                     generated if missing)
#   XB77_RPC_PORT     validator RPC port (default 8899)
#   XB77_GW_PORT      wrangler port (default 8787)
#   XB77_WEB_PORT     webapp port (default 8080)
#
# Exit:
#   0 on success (or clean teardown)
#   1+ on any boot/deploy failure

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONCHAIN_WT="${XB77_ONCHAIN_WT:-/home/exp1/Desktop/xB77/worktree/merge-onchain-deluxe}"
PAYER="${XB77_PAYER:-/tmp/xb77_payer.json}"
RPC_PORT="${XB77_RPC_PORT:-8899}"
WS_PORT="$((RPC_PORT + 1))"
GW_PORT="${XB77_GW_PORT:-8787}"
WEB_PORT="${XB77_WEB_PORT:-8080}"

VALIDATOR_NAME="xb77-validator"
LEDGER_DIR="${REPO}/.localnet-ledger"
WORK="$(mktemp -d -t xb77-stack-XXXXXX)"
WRANGLER_LOG="${WORK}/wrangler.log"
WEBAPP_LOG="${WORK}/webapp.log"
WRANGLER_PID=""
WEBAPP_PID=""

# Programs registry — name | program_id | .so | keypair (paths relative to ONCHAIN_WT)
PROGRAMS=(
  "xb77_core|73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3|onchain/programs/xb77_core/target/deploy/xb77_core.so|onchain/programs/xb77_core/target/deploy/xb77_core-keypair.json"
  "xb77_compression|6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN|onchain/programs/xb77_compression/target/deploy/xb77_compression.so|onchain/programs/xb77_compression/target/deploy/xb77_compression-keypair.json"
  "xb77_zk_verifier|J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier.so|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier-keypair.json"
  "xb77_gateway|83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4|onchain/programs/xb77_gateway/target/deploy/xb77_gateway.so|onchain/programs/xb77_gateway/target/deploy/xb77_gateway-keypair.json"
  "xb77_registry|HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1|onchain/programs/xb77_registry/target/deploy/xb77_registry.so|onchain/programs/xb77_registry/target/deploy/xb77_registry-keypair.json"
)

# ─── Flags ─────────────────────────────────────────────────────────────
KEEP_UP=0
RESET=0
VALIDATOR_ONLY=0
NO_WRANGLER=0
TEARDOWN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-up)         KEEP_UP=1; shift ;;
    --reset)           RESET=1; shift ;;
    --validator-only)  VALIDATOR_ONLY=1; shift ;;
    --no-wrangler)     NO_WRANGLER=1; shift ;;
    --teardown)        TEARDOWN=1; shift ;;
    --no-onchain-smoke) SKIP_ONCHAIN_SMOKE=1; shift ;;
    -h|--help)         sed -n '1,30p' "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
    *)                 echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ─── Pretty logging ────────────────────────────────────────────────────
RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'
CYN=$'\033[1;36m'; MAG=$'\033[1;35m'; DIM=$'\033[2m'; BLD=$'\033[1m'; RST=$'\033[0m'
step() { printf "\n${BLU}${BLD}▶ %s${RST}\n" "$*"; }
ok()   { printf "  ${GRN}✔${RST} %s\n" "$*"; }
note() { printf "  ${CYN}›${RST} %s\n" "$*"; }
warn() { printf "  ${YLW}⚠${RST} %s\n" "$*"; }
fail() { printf "  ${RED}✘${RST} %s\n" "$*" >&2; exit 1; }

# ─── Helpers ───────────────────────────────────────────────────────────
have()       { command -v "$1" >/dev/null; }
port_busy()  { ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":$1\$"; }
container_running() { podman ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"; }

rpc_healthy() {
  curl -fsS -X POST -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
    "http://127.0.0.1:${RPC_PORT}" 2>/dev/null | grep -q '"result":"ok"'
}

sol_in_container() {
  podman run --rm --network host \
    -v "${ONCHAIN_WT}:/work:Z" \
    -v "${PAYER}:/payer.json:Z,ro" \
    -w /work \
    xb77-solana solana "$@" --keypair /payer.json --url "http://127.0.0.1:${RPC_PORT}"
}

# ─── Teardown ──────────────────────────────────────────────────────────
do_teardown() {
  step "Teardown"
  [[ -n "${WRANGLER_PID}" ]] && kill "${WRANGLER_PID}" 2>/dev/null && ok "wrangler stopped" || true
  [[ -n "${WEBAPP_PID}"   ]] && kill "${WEBAPP_PID}"   2>/dev/null && ok "webapp stopped"   || true
  if [[ -f /tmp/xb77-gateway-watch.pid ]]; then
    GW_WATCH_PID="$(cat /tmp/xb77-gateway-watch.pid 2>/dev/null || true)"
    [[ -n "${GW_WATCH_PID}" ]] && kill "${GW_WATCH_PID}" 2>/dev/null && ok "gateway-watch stopped" || true
    rm -f /tmp/xb77-gateway-watch.pid
  fi
  pkill -f "xb77 .* gateway watch" 2>/dev/null || true
  # also kill any orphan wrangler / http.server we may have spawned earlier
  pkill -f "wrangler.*dev.*--port ${GW_PORT}" 2>/dev/null || true
  pkill -f "http.server.*${WEB_PORT}"        2>/dev/null || true
  if container_running "${VALIDATOR_NAME}"; then
    podman stop "${VALIDATOR_NAME}" >/dev/null 2>&1 && ok "validator container stopped" || true
  fi
  rm -rf "${WORK}"
  ok "done"
}

if (( TEARDOWN )); then
  do_teardown
  exit 0
fi

on_exit() {
  local rc=$?
  if (( KEEP_UP )); then
    printf "\n${YLW}--keep-up: leaving services running.${RST}\n"
    printf "  Validator:  podman logs -f ${VALIDATOR_NAME}\n"
    printf "  Wrangler:   tail -f ${WRANGLER_LOG}  (PID ${WRANGLER_PID:-?})\n"
    printf "  Webapp:     tail -f ${WEBAPP_LOG}    (PID ${WEBAPP_PID:-?})\n"
    printf "  Teardown:   scripts/full_local_stack.sh --teardown\n\n"
    exit "$rc"
  fi
  do_teardown
  exit "$rc"
}
trap on_exit EXIT INT TERM

# ─── 0. Preflight ──────────────────────────────────────────────────────
step "Preflight"
have podman  || fail "podman not installed (CLAUDE.md says podman, not docker)"
have curl    || fail "curl missing"
have bun     || fail "bun missing (needed for wrangler dev)"
have python3 || fail "python3 missing (for the webapp static server)"
have ss      || fail "iproute2 'ss' missing (for port checks)"
ok "tooling present"

[[ -d "${ONCHAIN_WT}" ]] || fail "onchain worktree not found: ${ONCHAIN_WT}  (set XB77_ONCHAIN_WT)"
for entry in "${PROGRAMS[@]}"; do
  IFS='|' read -r name _pid so kp <<<"$entry"
  [[ -f "${ONCHAIN_WT}/${so}" ]] || fail "missing .so for ${name}: ${ONCHAIN_WT}/${so}  (cd ${ONCHAIN_WT} && cargo build-sbf -p ${name})"
  [[ -f "${ONCHAIN_WT}/${kp}" ]] || fail "missing keypair for ${name}: ${ONCHAIN_WT}/${kp}"
done
ok "onchain artifacts present in ${ONCHAIN_WT}"

if ! podman image exists xb77-solana 2>/dev/null; then
  warn "xb77-solana image missing — build it:"
  warn "  cd ${ONCHAIN_WT} && podman build -t xb77-solana -f infra/Containerfile.solana_slim ."
  fail "abort"
fi
ok "podman image xb77-solana present"

if (( RESET )); then
  step "Reset (--reset)"
  podman rm -f "${VALIDATOR_NAME}" >/dev/null 2>&1 && ok "removed prior ${VALIDATOR_NAME}" || ok "no prior container"
  rm -rf "${LEDGER_DIR}" && ok "wiped ${LEDGER_DIR}" || true
  # also kill stragglers on our ports
  for p in "${RPC_PORT}" "${WS_PORT}" "${GW_PORT}" "${WEB_PORT}"; do
    fuser -k "${p}/tcp" 2>/dev/null && ok "freed port ${p}" || true
  done
fi

# Port 8899 is allowed to be busy IF it's our own validator container — we'll
# reuse it in step 1. Any other listener is fatal.
if port_busy "${RPC_PORT}" && ! container_running "${VALIDATOR_NAME}"; then
  fail "port ${RPC_PORT} in use by a non-${VALIDATOR_NAME} listener — pass --reset or free it"
fi
for p in "${GW_PORT}" "${WEB_PORT}"; do
  port_busy "${p}" && fail "port ${p} already in use — pass --reset or free it manually"
done
ok "ports ${RPC_PORT}/${GW_PORT}/${WEB_PORT} accounted for"

# ─── 1. Validator container ────────────────────────────────────────────
step "Validator (solana-test-validator)"
if container_running "${VALIDATOR_NAME}"; then
  ok "${VALIDATOR_NAME} already running — reuse"
else
  podman rm -f "${VALIDATOR_NAME}" >/dev/null 2>&1 || true
  mkdir -p "${LEDGER_DIR}"
  podman run -d --name "${VALIDATOR_NAME}" --network host \
    --security-opt seccomp=unconfined \
    -v "${LEDGER_DIR}:/root/ledger:Z" \
    xb77-solana >/dev/null
  ok "container started: ${VALIDATOR_NAME}"
fi

note "waiting for RPC healthy on :${RPC_PORT} (60s timeout)..."
i=0
until rpc_healthy; do
  i=$((i+1))
  if (( i > 120 )); then
    podman logs --tail 50 "${VALIDATOR_NAME}" >&2
    fail "validator did not become healthy within 60s"
  fi
  sleep 0.5
done
ok "validator RPC healthy"

# ─── 2. Payer keypair + airdrop ────────────────────────────────────────
step "Payer keypair + airdrop"
if [[ ! -f "${PAYER}" ]]; then
  podman run --rm \
    -v "$(dirname "${PAYER}"):/out:Z" \
    xb77-solana solana-keygen new --no-bip39-passphrase --silent --outfile "/out/$(basename "${PAYER}")" >/dev/null
  ok "generated ${PAYER}"
else
  ok "${PAYER} reused"
fi
PAYER_PUB="$(podman run --rm -v "${PAYER}:/k.json:Z,ro" xb77-solana solana-keygen pubkey /k.json 2>/dev/null)"
ok "payer pubkey: ${PAYER_PUB}"

BAL_OUT="$(sol_in_container balance "${PAYER_PUB}" 2>/dev/null || echo "0 SOL")"
note "current balance: ${BAL_OUT}"
SOL_AMT="$(echo "${BAL_OUT}" | awk '{print $1}')"
if awk -v b="${SOL_AMT}" 'BEGIN{exit !(b < 6)}'; then
  note "balance < 6 SOL — airdropping 10 SOL"
  timeout 20 sol_in_container airdrop 10 "${PAYER_PUB}" >/dev/null 2>&1 \
    || warn "airdrop call timed out/failed (continuing if balance OK)"
  BAL_OUT="$(sol_in_container balance "${PAYER_PUB}" 2>/dev/null || echo "0 SOL")"
  SOL_AMT="$(echo "${BAL_OUT}" | awk '{print $1}')"
  awk -v b="${SOL_AMT}" 'BEGIN{exit !(b < 6)}' && fail "still under 6 SOL after airdrop — check validator faucet"
  ok "post-airdrop: ${BAL_OUT}"
fi

# ─── 3. Deploy programs (idempotent) ──────────────────────────────────
step "Deploy programs"
for entry in "${PROGRAMS[@]}"; do
  IFS='|' read -r name pid so kp <<<"$entry"
  if sol_in_container program show "${pid}" >/dev/null 2>&1; then
    ok "${name} (${pid:0:12}…) already deployed — skip"
  else
    note "deploying ${name} → ${pid}"
    podman run --rm --network host \
      -v "${ONCHAIN_WT}:/work:Z" \
      -v "${PAYER}:/payer.json:Z,ro" \
      -w /work \
      xb77-solana solana program deploy "${so}" \
        --program-id "${kp}" \
        --keypair /payer.json \
        --url "http://127.0.0.1:${RPC_PORT}" >/dev/null \
      || fail "deploy ${name} failed"
    ok "${name} deployed"
  fi
done

# ─── 3b. Init xb77_gateway state PDA (idempotent) ──────────────────────
# Required by SubmitPrivateOrder. The CLI command checks getAccountInfo
# first; if the PDA is already owned by the program it exits cleanly.
# Uses XB77_INIT_PROFILE (default: myagent). If the profile does not exist,
# this step is skipped with a hint — manually run:
#   ./zig-out/bin/xb77 spawn <profile> && ./zig-out/bin/xb77 -p <profile> init
#   ./zig-out/bin/xb77 -p <profile> gateway init
INIT_PROFILE="${XB77_INIT_PROFILE:-myagent}"
INIT_PROFILE_TOML="${REPO}/profiles/${INIT_PROFILE}.toml"
if [[ -x "${REPO}/zig-out/bin/xb77" ]] && [[ -f "${INIT_PROFILE_TOML}" ]]; then
  step "Init xb77_gateway state (profile: ${INIT_PROFILE})"
  if XB77_PASSWORD="${XB77_PASSWORD:-demo-pw}" XB77_RPC="http://127.0.0.1:${RPC_PORT}" \
       "${REPO}/zig-out/bin/xb77" -p "${INIT_PROFILE}" gateway init \
         --idl "${REPO}/idls/xb77_gateway.json" >/tmp/xb77-init-gateway.log 2>&1; then
    ok "gateway_state ready"
  else
    warn "gateway init returned non-zero — see /tmp/xb77-init-gateway.log"
    tail -20 /tmp/xb77-init-gateway.log >&2 || true
  fi
elif [[ ! -x "${REPO}/zig-out/bin/xb77" ]]; then
  warn "skip gateway init: ${REPO}/zig-out/bin/xb77 not built (run \`zig build\` first)"
else
  warn "skip gateway init: profile '${INIT_PROFILE}' not found at ${INIT_PROFILE_TOML}"
  warn "  manually run: ./zig-out/bin/xb77 spawn ${INIT_PROFILE} && \\"
  warn "               ./zig-out/bin/xb77 -p ${INIT_PROFILE} init && \\"
  warn "               ./zig-out/bin/xb77 -p ${INIT_PROFILE} gateway init"
fi

if (( VALIDATOR_ONLY )); then
  step "Done (--validator-only)"
  ok "validator + programs ready at http://127.0.0.1:${RPC_PORT}"
  KEEP_UP=1
  exit 0
fi

if (( NO_WRANGLER )); then
  step "Done (--no-wrangler)"
  ok "validator + programs ready; webapp/wrangler skipped"
  KEEP_UP=1
  exit 0
fi

# ─── 4. CF Worker gateway (wrangler dev, host) ─────────────────────────
step "CF Worker gateway (wrangler dev)"
note "spawning: bunx wrangler@latest dev --local --port ${GW_PORT}"
(
  cd "${REPO}/gateway/worker"
  ZNODE_RPC_URL="http://127.0.0.1:${RPC_PORT}" \
  bunx wrangler@latest dev --local --port "${GW_PORT}" >"${WRANGLER_LOG}" 2>&1
) &
WRANGLER_PID=$!

note "waiting for gateway on :${GW_PORT} (60s timeout)..."
i=0
until curl -fsS "http://127.0.0.1:${GW_PORT}/api/v1/network/pulse" >/dev/null 2>&1; do
  i=$((i+1))
  if (( i > 120 )); then
    tail -40 "${WRANGLER_LOG}" >&2
    fail "wrangler did not come up"
  fi
  # also bail if wrangler died
  kill -0 "${WRANGLER_PID}" 2>/dev/null || { tail -40 "${WRANGLER_LOG}" >&2; fail "wrangler exited"; }
  sleep 0.5
done
ok "wrangler healthy on :${GW_PORT} (PID ${WRANGLER_PID})"

# ─── 5. Webapp build + serve ───────────────────────────────────────────
step "Webapp build + serve"
( cd "${REPO}/webapp_deploy" && ./build.sh ) >/dev/null
ok "webapp built (assets/js/* regenerated)"

(
  cd "${REPO}/webapp_deploy"
  python3 -m http.server "${WEB_PORT}" --bind 127.0.0.1 >"${WEBAPP_LOG}" 2>&1
) &
WEBAPP_PID=$!

i=0
until curl -fsS -o /dev/null "http://127.0.0.1:${WEB_PORT}/app.html"; do
  i=$((i+1))
  if (( i > 40 )); then
    tail -20 "${WEBAPP_LOG}" >&2
    fail "webapp server did not come up"
  fi
  sleep 0.25
done
ok "webapp on :${WEB_PORT} (PID ${WEBAPP_PID})"

# ─── 6. Smoke: end-to-end signal through real stack ────────────────────
step "Smoke (gateway → validator)"
PULSE="$(curl -fsS "http://127.0.0.1:${GW_PORT}/api/v1/network/pulse" 2>&1 || echo "")"
[[ -n "${PULSE}" ]] && ok "GET /network/pulse: $(echo "${PULSE}" | head -c 120)…" || warn "no pulse body (check wrangler log)"

# ─── 6b. Onchain smoke (webapp lib → validator, no mocks anywhere) ─────
# Runs the bun test that builds a real Solana tx via wincode + IDL +
# tx-builder and sends it to the validator. Proof that the no-mocks
# path is wired end-to-end. Skipped via --no-onchain-smoke.
if [[ "${SKIP_ONCHAIN_SMOKE:-0}" != "1" ]]; then
  step "Onchain smoke (anchorState → xb77_compression)"
  if ( cd "${REPO}" && bun test webapp_deploy/test/onchain-e2e.test.js 2>&1 | tee "${WORK}/onchain-smoke.log" | grep -q "1 pass" ); then
    SIG="$(grep -oE 'anchorState tx: [1-9A-HJ-NP-Za-km-z]+' "${WORK}/onchain-smoke.log" | tail -1 | awk '{print $3}')"
    ok "onchain tx landed: ${SIG:-???}"
  else
    warn "onchain-e2e test did not report pass — check ${WORK}/onchain-smoke.log"
  fi
fi

# ─── XB77 GATEWAY WATCH DAEMON ─────────────────────────────────────────
# Polls xb77_gateway tx signatures from the validator and POSTs each new
# one to /api/v1/pipelines/ingest so the dApp's pipelines view shows live
# onchain activity. Auth via INGEST_TOKEN. PID lives at /tmp/xb77-gateway-watch.pid.
if [[ -x "${REPO}/zig-out/bin/xb77" ]] && [[ -f "${INIT_PROFILE_TOML:-/nope}" ]]; then
  step "Gateway watch daemon (profile: ${INIT_PROFILE})"
  XB77_INGEST_TOKEN=devtoken \
  XB77_RPC="http://127.0.0.1:${RPC_PORT}" \
  XB77_GATEWAY="http://127.0.0.1:${GW_PORT}" \
  XB77_PASSWORD="${XB77_PASSWORD:-demo-pw}" \
  nohup "${REPO}/zig-out/bin/xb77" -p "${INIT_PROFILE}" gateway watch --interval 5 \
    >>"${WORK}/gateway-watch.log" 2>&1 &
  echo $! > /tmp/xb77-gateway-watch.pid
  sleep 1
  if kill -0 "$(cat /tmp/xb77-gateway-watch.pid)" 2>/dev/null; then
    ok "watch daemon started (PID $(cat /tmp/xb77-gateway-watch.pid))"
  else
    warn "watch daemon failed to start — see ${WORK}/gateway-watch.log"
  fi
else
  warn "skip watch daemon: missing xb77 binary or '${INIT_PROFILE:-?}' profile"
fi

# ─── 7. Info card ──────────────────────────────────────────────────────
step "Stack online"
cat <<EOF

  ${BLD}${MAG}╔══════════════════════════════════════════════════════════════╗${RST}
  ${BLD}${MAG}║   xB77 — full local stack, no mocks                          ║${RST}
  ${BLD}${MAG}╚══════════════════════════════════════════════════════════════╝${RST}

  ${BLD}Validator${RST}    podman://${VALIDATOR_NAME}  →  http://127.0.0.1:${RPC_PORT}
  ${BLD}Gateway${RST}      wrangler dev (PID ${WRANGLER_PID})   →  http://127.0.0.1:${GW_PORT}
  ${BLD}Webapp${RST}       python3 http.server (PID ${WEBAPP_PID}) →  http://127.0.0.1:${WEB_PORT}/app.html

  ${BLD}Programs deployed:${RST}
$(for e in "${PROGRAMS[@]}"; do IFS='|' read -r n p _ _ <<<"$e"; printf "    %-18s %s\n" "$n" "$p"; done)

  ${BLD}Payer:${RST}       ${PAYER_PUB}
  ${BLD}Ledger:${RST}      ${LEDGER_DIR}  (deleted on --reset)

  ${BLD}Try it:${RST}
    open  ${CYN}http://127.0.0.1:${WEB_PORT}/app.html${RST}  in Chrome 137+
    or    XB77_GATEWAY=http://127.0.0.1:${GW_PORT} ./zig-out/bin/xb77 -p X gateway register --intent merchant

  ${BLD}Logs:${RST}
    podman logs -f ${VALIDATOR_NAME}
    tail -f ${WRANGLER_LOG}
    tail -f ${WEBAPP_LOG}

  ${BLD}Teardown:${RST}     scripts/full_local_stack.sh --teardown
EOF

# ─── 8. Hold (unless --keep-up flips into detach) ──────────────────────
if (( KEEP_UP )); then
  exit 0
fi
note "attached. Ctrl-C to tear down."
wait "${WRANGLER_PID}" "${WEBAPP_PID}"

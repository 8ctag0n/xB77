#!/usr/bin/env bash
# scripts/demo_deluxe.sh — xB77 devnet e2e demo orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/lib/demo_util.sh
source "$SCRIPT_DIR/lib/demo_util.sh"
# shellcheck source=scripts/lib/demo_runner.sh
source "$SCRIPT_DIR/lib/demo_runner.sh"
# shellcheck source=scripts/lib/demo_steps.sh
source "$SCRIPT_DIR/lib/demo_steps.sh"

# dispatch_step <human-name> <preview-cmd> <fn-name>
#   Calls fn-name unless runner mode says skip/quit.
dispatch_step() {
  local name="$1" preview="$2" fn="$3"
  STEP_CMD_PREVIEW="$preview"
  log_step "$name"
  if [[ "$RUNNER" == "1" ]]; then
    local decision
    decision=$(prompt_step "$name" "Command: $preview")
    case "$decision" in
      skip) log_warn "skipped $name"; return 0 ;;
      quit) log_warn "user quit"; exit 130 ;;
      run)  ;;
    esac
  fi
  "$fn"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

xB77 devnet e2e demo orchestrator.

OPTIONS:
  --runner          Interactive mode: pause before each step
  --dry-run         Print commands without executing
  --cluster NAME    Solana cluster (default: devnet)
  --payer PATH      Payer keypair path (default: /tmp/xb77_payer.json)
  -h, --help        Show this help

STEPS:
  0  preflight       balance check + idempotent program deploy
  1  agent up        xb77 context daemon (podman background)
  2  znode-e2e       AWP order matching
  3  e2e-anchor      sovereign state anchor (devnet tx)
  4  nargo prove     ZK proof generation (xb77-zk container)
  5  zk-upload-e2e   chunked proof upload + verdict GREEN
  6  solana logs     tail verifier events (10s)
  7  zig test        in-process health check
EOF
}

RUNNER=0; DRY_RUN=0
CLUSTER="devnet"
PAYER="${XB77_PAYER:-/tmp/xb77_payer.json}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runner)   RUNNER=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --cluster)  CLUSTER="$2"; shift 2 ;;
    --payer)    PAYER="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) log_error "Unknown arg: $1"; usage; exit 2 ;;
  esac
done
export DRY_RUN CLUSTER PAYER

log_info "cluster=$CLUSTER  runner=$RUNNER  dry_run=$DRY_RUN  payer=$PAYER"

if [[ "$DRY_RUN" == "1" ]]; then
  log_warn "DRY RUN — printing commands only, nothing will actually execute"
fi

dispatch_step "STEP 0/7 — preflight" "balance check + idempotent deploy" step_0_preflight
dispatch_step "STEP 1/7 — agent up" "podman run -d xb77-agent xb77 context" step_1_agent
dispatch_step "STEP 2/7 — znode-e2e (AWP orders + matches)" "./zig-out/bin/znode-e2e" step_2_znode
dispatch_step "STEP 3/7 — e2e-anchor (sovereign state onchain)" \
  "XB77_RPC=https://api.${CLUSTER}.solana.com ./zig-out/bin/e2e-anchor" \
  step_3_anchor
dispatch_step "STEP 4/7 — nargo prove (ZK proof real)" \
  "podman run xb77-zk zk-bridge prove --package zk_receipt" \
  step_4_prove
log_ok "demo_deluxe runner wiring OK"

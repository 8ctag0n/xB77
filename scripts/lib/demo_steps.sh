#!/usr/bin/env bash
# scripts/lib/demo_steps.sh — per-step implementations
[[ -n "${_DEMO_STEPS_LOADED:-}" ]] && return 0
_DEMO_STEPS_LOADED=1

# Program registry. Format: name|program_id|so_path|keypair_path
PROGRAMS=(
  "xb77_core|73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3|onchain/programs/xb77_core/target/deploy/xb77_core.so|onchain/programs/xb77_core/target/deploy/xb77_core-keypair.json"
  "xb77_compression|6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN|onchain/programs/xb77_compression/target/deploy/xb77_compression.so|onchain/programs/xb77_compression/target/deploy/xb77_compression-keypair.json"
  "xb77_zk_verifier|J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier.so|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier-keypair.json"
)

# Resolve RPC URL from cluster name. Localnet hits the in-pod validator.
resolve_rpc_url() {
  case "$CLUSTER" in
    localnet|localhost) echo "http://127.0.0.1:8899" ;;
    devnet|testnet|mainnet-beta) echo "https://api.${CLUSTER}.solana.com" ;;
    *) echo "https://api.${CLUSTER}.solana.com" ;;
  esac
}

# Run solana CLI inside xb77-solana container.
sol() {
  podman run --rm --network host \
    -v "$REPO_ROOT:/work:Z" \
    -v "$PAYER:/payer.json:Z,ro" \
    -w /work \
    xb77-solana solana "$@" --keypair /payer.json --url "$(resolve_rpc_url)"
}

step_neg1_validator() {
  require_image xb77-solana infra/Containerfile.solana_slim

  if [[ "$CLUSTER" != "localnet" && "$CLUSTER" != "localhost" ]]; then
    log_info "cluster=$CLUSTER — skip local validator boot"
    return 0
  fi

  if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^xb77-validator$'; then
    log_ok "xb77-validator already running — skip"
    return 0
  fi

  run_cmd podman rm -f xb77-validator 2>/dev/null || true
  run_cmd podman run -d --name xb77-validator --network host \
    --security-opt seccomp=unconfined \
    -v "$REPO_ROOT/.localnet-ledger:/root/ledger:Z" \
    xb77-solana

  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  log_info "waiting for RPC (30s timeout)..."
  local i=0
  while ((i < 60)); do
    if curl -sf -X POST -H 'content-type: application/json' \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
        http://127.0.0.1:8899 2>/dev/null | grep -q '"result":"ok"'; then
      log_ok "validator RPC healthy"
      return 0
    fi
    sleep 0.5
    i=$((i+1))
  done
  log_error "validator did not become healthy within 30s"
  return 1
}

step_0_preflight() {
  require_image xb77-solana infra/Containerfile.solana_slim

  if [[ ! -f "$PAYER" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_warn "payer keypair $PAYER absent"
    else
      log_error "Payer keypair not found: $PAYER"
      return 1
    fi
  fi

  local pubkey
  pubkey=$(run_cmd podman run --rm -v "$PAYER:/k.json:Z,ro" xb77-solana solana-keygen pubkey /k.json 2>/dev/null || echo "DRY_PUBKEY")
  log_info "payer pubkey: $pubkey"

  # Check balance
  local balance_out
  balance_out=$(sol balance "$pubkey" 2>/dev/null || echo "0 SOL")
  log_info "current balance: $balance_out"
  local sol_amount
  sol_amount=$(echo "$balance_out" | awk '{print $1}')

  if [[ "$CLUSTER" == "localnet" || "$CLUSTER" == "localhost" ]] && \
     awk -v b="$sol_amount" 'BEGIN{exit !(b < 6)}'; then
    log_info "balance < 6 SOL — airdropping 10 SOL"
    sol airdrop 10 "$pubkey" >/dev/null 2>&1 || true
  fi

  local entry name pid so kp
  for entry in "${PROGRAMS[@]}"; do
    IFS='|' read -r name pid so kp <<<"$entry"
    log_info "checking program $name ($pid)"
    if run_cmd sol program show "$pid" >/dev/null 2>&1; then
      log_ok "$name already deployed"
    else
      log_info "deploying $name ..."
      if [[ ! -f "$so" ]] || [[ ! -f "$kp" ]]; then
        log_error "Missing artifact for $name"
        return 1
      fi
      run_cmd sol program deploy "$so" --program-id "$kp"
      log_ok "$name deployed"
    fi
  done
}

step_1_agent() {
  # UN-BLURRED: Force agent up even without Yellowstone for competition-ready local dev
  require_image xb77-agent infra/Containerfile.agent
  run_cmd podman rm -f xb77-agent-demo 2>/dev/null || true

  # Fallback to local RPC if Yellowstone is missing
  local y_endpoint="${YELLOWSTONE_ENDPOINT:-http://127.0.0.1:8899}"

  run_cmd podman run -d \
    --name xb77-agent-demo \
    --network host \
    -e YELLOWSTONE_ENDPOINT="$y_endpoint" \
    -e XB77_DEMO_MODE=1 \
    -v /tmp:/tmp:Z \
    xb77-agent

  log_info "waiting for agent socket..."
  local i=0
  while ((i < 20)); do
    [[ -S /tmp/xb77_znode.sock ]] && { log_ok "agent socket up"; return 0; }
    sleep 0.5
    i=$((i+1))
  done
  log_error "agent socket did not appear"
  return 1
}

step_2_znode() {
  # UN-BLURRED: Run the znode-e2e test
  if [[ ! -x ./zig-out/bin/znode-e2e ]]; then
    log_info "building znode-e2e..."
    zig build
  fi
  run_cmd ./zig-out/bin/znode-e2e
}

step_3_anchor() {
  if [[ ! -x ./zig-out/bin/e2e-anchor ]]; then zig build; fi
  local rpc="$(resolve_rpc_url)"
  XB77_RPC="$rpc" run_cmd ./zig-out/bin/e2e-anchor
}

step_3b_compression() {
  if [[ ! -x ./zig-out/bin/compression-e2e ]]; then zig build; fi
  local rpc="$(resolve_rpc_url)"
  XB77_RPC="$rpc" run_cmd ./zig-out/bin/compression-e2e
}

step_4_prove() {
  require_image xb77-zk infra/Containerfile.zk
  run_cmd podman run --rm \
    -v "$REPO_ROOT/circuits/zk_receipt:/work:Z" \
    -w /work \
    xb77-zk prove
}

step_5_upload() {
  if [[ ! -x ./zig-out/bin/zk-upload-e2e ]]; then zig build; fi
  local rpc="$(resolve_rpc_url)"
  local verifier_id="J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ"
  RPC_URL="$rpc" VERIFIER_PROGRAM_ID="$verifier_id" \
  PAYER_KEYPAIR="$PAYER" run_cmd ./zig-out/bin/zk-upload-e2e
}

cleanup() {
  local rc=$?
  podman stop xb77-agent-demo >/dev/null 2>&1 || true
  podman rm   xb77-agent-demo >/dev/null 2>&1 || true
  [[ -S /tmp/xb77_znode.sock ]] && rm -f /tmp/xb77_znode.sock 2>/dev/null || true
  exit "$rc"
}

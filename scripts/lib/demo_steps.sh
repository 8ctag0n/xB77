#!/usr/bin/env bash
# scripts/lib/demo_steps.sh — per-step implementations
[[ -n "${_DEMO_STEPS_LOADED:-}" ]] && return 0
_DEMO_STEPS_LOADED=1

# Program registry. Format: name|program_id|so_path|keypair_path
# Trimmed to programs actually exercised by the demo:
#   xb77_core         — step 3 (sovereign state anchor)
#   xb77_compression  — step 3b (state transition VerifyTransition)
#   xb77_zk_verifier  — step 5 (chunked proof verify) + step 6 (logs)
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

# Run solana CLI inside xb77-solana container. Mounts repo + payer.
# --network host so the container can reach the validator on 127.0.0.1.
sol() {
  podman run --rm --network host \
    -v "$REPO_ROOT:/work:Z" \
    -v "$PAYER:/payer.json:Z,ro" \
    -w /work \
    xb77-solana solana "$@" --url "$(resolve_rpc_url)"
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
  run_cmd podman logs --tail 50 xb77-validator
  return 1
}

step_0_preflight() {
  require_image xb77-solana infra/Containerfile.solana_slim

  if [[ ! -f "$PAYER" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_warn "payer keypair $PAYER absent (dry-run continues with DRY_PUBKEY)"
    else
      log_error "Payer keypair not found: $PAYER"
      log_error "Generate one or point --payer at a valid Solana keypair JSON."
      return 1
    fi
  fi

  local pubkey
  pubkey=$(run_cmd podman run --rm -v "$PAYER:/k.json:Z,ro" xb77-solana solana-keygen pubkey /k.json 2>/dev/null || echo "DRY_PUBKEY")
  log_info "payer pubkey: $pubkey"

  # Airdrop on localnet (no rate limit, free). On devnet/testnet, only check balance.
  if [[ "$CLUSTER" == "localnet" || "$CLUSTER" == "localhost" ]]; then
    log_info "airdropping 10 SOL to payer (localnet faucet)"
    run_cmd sol airdrop 10 "$pubkey" >/dev/null 2>&1 || log_warn "airdrop failed (continuing)"
  fi

  local balance_out
  balance_out=$(run_cmd sol balance "$pubkey" 2>/dev/null || echo "0 SOL")
  log_info "balance: $balance_out"

  if [[ "$DRY_RUN" != "1" ]]; then
    local sol_amount
    sol_amount=$(echo "$balance_out" | awk '{print $1}')
    if awk -v b="$sol_amount" 'BEGIN{exit !(b < 6)}'; then
      log_error "Insufficient balance: $balance_out (need >= 6 SOL)"
      if [[ "$CLUSTER" == "localnet" || "$CLUSTER" == "localhost" ]]; then
        log_error "Validator faucet should be unlimited — check xb77-validator logs"
      else
        log_error "Airdrop manually: solana airdrop 2 $pubkey --url $CLUSTER (repeat 3x)"
      fi
      return 1
    fi
  fi

  local entry name pid so kp
  for entry in "${PROGRAMS[@]}"; do
    IFS='|' read -r name pid so kp <<<"$entry"
    log_info "checking program $name ($pid)"
    if run_cmd sol program show "$pid" >/dev/null 2>&1; then
      log_ok "$name already deployed — skip"
    else
      log_info "deploying $name ..."
      if [[ ! -f "$so" ]] || [[ ! -f "$kp" ]]; then
        log_error "Missing artifact for $name: $so or $kp"
        log_error "Build first: cd onchain/programs/$name && cargo build-sbf"
        return 1
      fi
      run_cmd podman run --rm --network host \
        -v "$REPO_ROOT:/work:Z" \
        -v "$PAYER:/payer.json:Z,ro" \
        -w /work \
        xb77-solana solana program deploy \
          "$so" \
          --program-id "$kp" \
          --keypair /payer.json \
          --url "$(resolve_rpc_url)"
      log_ok "$name deployed"
    fi
  done
}

step_1_agent() {
  require_image xb77-agent infra/Containerfile.agent
  run_cmd podman rm -f xb77-agent-demo 2>/dev/null || true

  run_cmd podman run -d \
    --name xb77-agent-demo \
    -v /tmp:/tmp:Z \
    xb77-agent xb77 context

  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi

  log_info "waiting for /tmp/xb77_znode.sock (10s timeout)..."
  local i=0
  while ((i < 20)); do
    [[ -S /tmp/xb77_znode.sock ]] && { log_ok "agent socket up"; return 0; }
    sleep 0.5
    i=$((i+1))
  done
  log_error "agent socket did not appear within 10s"
  run_cmd podman logs --tail 50 xb77-agent-demo
  return 1
}

step_2_znode() {
  if [[ ! -x ./zig-out/bin/znode-e2e ]]; then
    log_error "missing binary: ./zig-out/bin/znode-e2e"
    log_error "build it: zig build"
    return 1
  fi
  run_cmd ./zig-out/bin/znode-e2e
}

step_3_anchor() {
  if [[ ! -x ./zig-out/bin/e2e-anchor ]]; then
    log_error "missing binary: ./zig-out/bin/e2e-anchor"
    log_error "build it: zig build"
    return 1
  fi
  local rpc="$(resolve_rpc_url)"
  if [[ "$DRY_RUN" == "1" ]]; then
    run_cmd env "XB77_RPC=$rpc" ./zig-out/bin/e2e-anchor
    return 0
  fi
  local out
  out=$(XB77_RPC="$rpc" ./zig-out/bin/e2e-anchor | tee /dev/tty)
  local sig
  sig=$(echo "$out" | grep -oE '[1-9A-HJ-NP-Za-km-z]{87,88}' | tail -1 || true)
  if [[ -n "$sig" ]]; then
    log_ok "anchor tx: $(explorer_tx "$sig")"
  else
    log_warn "could not extract tx sig from e2e-anchor output"
  fi
}

step_3b_compression() {
  if [[ ! -x ./zig-out/bin/compression-e2e ]]; then
    log_error "missing binary: ./zig-out/bin/compression-e2e"
    log_error "build it: zig build"
    return 1
  fi
  local rpc="$(resolve_rpc_url)"
  if [[ "$DRY_RUN" == "1" ]]; then
    run_cmd env "XB77_RPC=$rpc" ./zig-out/bin/compression-e2e
    return 0
  fi
  local out
  out=$(XB77_RPC="$rpc" ./zig-out/bin/compression-e2e | tee /dev/tty)
  local sig
  sig=$(echo "$out" | grep -oE '[1-9A-HJ-NP-Za-km-z]{87,88}' | tail -1 || true)
  if [[ -n "$sig" ]]; then
    log_ok "compression tx: $(explorer_tx "$sig")"
  else
    log_warn "could not extract tx sig from compression-e2e output"
  fi
}

step_4_prove() {
  require_image xb77-zk infra/Containerfile.zk

  run_cmd podman run --rm \
    -v "$REPO_ROOT/circuits:/work:Z" \
    -w /work \
    xb77-zk zk-bridge prove --package zk_receipt

  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  local proof="circuits/zk_receipt/proofs/zk_receipt.proof"
  if [[ ! -f "$proof" ]]; then
    log_error "proof not generated: $proof"
    return 1
  fi
  local size
  size=$(stat -c %s "$proof")
  log_ok "proof generated: $proof ($size bytes)"
  if (( size < 1500 || size > 3000 )); then
    log_warn "proof size unusual ($size B, expected ~2176)"
  fi
}

step_5_upload() {
  if [[ ! -x ./zig-out/bin/zk-upload-e2e ]]; then
    log_error "missing binary: ./zig-out/bin/zk-upload-e2e"
    return 1
  fi
  local rpc="$(resolve_rpc_url)"
  if [[ "$DRY_RUN" == "1" ]]; then
    run_cmd env "XB77_RPC=$rpc" ./zig-out/bin/zk-upload-e2e
    return 0
  fi
  local out
  out=$(XB77_RPC="$rpc" ./zig-out/bin/zk-upload-e2e | tee /dev/tty)

  if ! grep -q '\[ZK-JUDGE\] verdict: GREEN' <<<"$out"; then
    log_error "verdict was NOT GREEN — pipeline failed"
    return 1
  fi
  log_ok "verdict: GREEN"

  local sig
  sig=$(echo "$out" | grep -oE '[1-9A-HJ-NP-Za-km-z]{87,88}' | tail -1 || true)
  [[ -n "$sig" ]] && log_ok "verify tx: $(explorer_tx "$sig")"
}

step_6_logs() {
  require_image xb77-solana infra/Containerfile.solana_slim
  local verifier_id="J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ"
  local compression_id="6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN"
  log_info "tailing logs for xb77_compression + xb77_zk_verifier (10s)"
  run_cmd podman run --rm --network host \
    xb77-solana sh -c "
      timeout 10 solana logs $compression_id --url $(resolve_rpc_url) &
      timeout 10 solana logs $verifier_id    --url $(resolve_rpc_url) &
      wait
    " || true
  log_info "logs tail window ended"
}

step_7_test() {
  run_cmd zig build test --summary all
}

cleanup() {
  local rc=$?
  log_step "cleanup"
  if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^xb77-agent-demo$'; then
    run_cmd podman stop xb77-agent-demo >/dev/null 2>&1 || true
    run_cmd podman rm   xb77-agent-demo >/dev/null 2>&1 || true
    log_ok "removed xb77-agent-demo container"
  fi
  if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^xb77-validator$'; then
    run_cmd podman stop xb77-validator >/dev/null 2>&1 || true
    run_cmd podman rm   xb77-validator >/dev/null 2>&1 || true
    log_ok "removed xb77-validator container"
  fi
  [[ -S /tmp/xb77_znode.sock ]] && rm -f /tmp/xb77_znode.sock 2>/dev/null || true
  if (( rc == 0 )); then
    log_ok "demo complete — exit 0"
  else
    log_error "demo aborted — exit $rc"
  fi
  exit "$rc"
}

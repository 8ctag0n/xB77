#!/usr/bin/env bash
# scripts/lib/demo_steps.sh — per-step implementations
[[ -n "${_DEMO_STEPS_LOADED:-}" ]] && return 0
_DEMO_STEPS_LOADED=1

# Program registry. Format: name|program_id|so_path|keypair_path
PROGRAMS=(
  "xb77_core|73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3|onchain/programs/xb77_core/target/deploy/xb77_core.so|onchain/programs/xb77_core/target/deploy/xb77_core-keypair.json"
  "xb77_gateway|4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC|onchain/programs/xb77_gateway/target/deploy/xb77_gateway.so|onchain/programs/xb77_gateway/target/deploy/xb77_gateway-keypair.json"
  "xb77_compression|6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN|onchain/programs/xb77_compression/target/deploy/xb77_compression.so|onchain/programs/xb77_compression/target/deploy/xb77_compression-keypair.json"
  "xb77_registry|Dfe1DDsHXKTMBNms8uzippn4dksbWZr6TEc1GNBzkAKN|onchain/programs/xb77_registry/target/deploy/xb77_registry.so|onchain/programs/xb77_registry/target/deploy/xb77_registry-keypair.json"
  "xb77_zk_verifier|J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier.so|onchain/programs/xb77_zk_verifier/target/deploy/xb77_zk_verifier-keypair.json"
)

# Run solana CLI inside xb77-solana container. Mounts repo + payer.
sol() {
  podman run --rm \
    -v "$REPO_ROOT:/work:Z" \
    -v "$PAYER:/payer.json:Z,ro" \
    -w /work \
    xb77-solana solana "$@" --url "https://api.${CLUSTER}.solana.com"
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

  local balance_out
  balance_out=$(run_cmd sol balance "$pubkey" 2>/dev/null || echo "0 SOL")
  log_info "balance: $balance_out"

  if [[ "$DRY_RUN" != "1" ]]; then
    local sol_amount
    sol_amount=$(echo "$balance_out" | awk '{print $1}')
    if awk -v b="$sol_amount" 'BEGIN{exit !(b < 6)}'; then
      log_error "Insufficient balance: $balance_out (need >= 6 SOL)"
      log_error "Airdrop manually before running the demo:"
      log_error "  solana airdrop 2 $pubkey --url $CLUSTER"
      log_error "  (repeat 3 times; faucet caps at 2 SOL/request)"
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
      run_cmd podman run --rm \
        -v "$REPO_ROOT:/work:Z" \
        -v "$PAYER:/payer.json:Z,ro" \
        -w /work \
        xb77-solana solana program deploy \
          "$so" \
          --program-id "$kp" \
          --keypair /payer.json \
          --url "https://api.${CLUSTER}.solana.com"
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

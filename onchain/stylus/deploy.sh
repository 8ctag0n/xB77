#!/usr/bin/env bash
# xB77 Stylus contracts deploy script
# Usage: ./onchain/stylus/deploy.sh [check|estimate|deploy]
# Requires: cargo-stylus, DEPLOYER_KEY env var, Sepolia ETH

set -euo pipefail

RPC="${XB77_RPC:-https://sepolia-rollup.arbitrum.io/rpc}"
OUT_DIR="zig-out/bin"
DEPLOY_OUT="onchain/stylus/deployed_addresses.env"

CONTRACTS=(
  "xb77_anchor"
  "xb77_settlement_engine"
  "xb77_zk_verifier"
)

MODE="${1:-check}"

build_wasm() {
  echo ">>> Building Stylus WASM contracts..."
  zig build stylus
  echo ">>> Build complete. Outputs:"
  for name in "${CONTRACTS[@]}"; do
    local wasm="$OUT_DIR/$name.wasm"
    if [[ -f "$wasm" ]]; then
      echo "    $wasm ($(wc -c < "$wasm") bytes)"
    else
      echo "    [MISSING] $wasm"
    fi
  done
}

check_contract() {
  local name="$1"
  local wasm="$OUT_DIR/$name.wasm"
  echo ">>> Checking $name..."
  # Run from onchain/stylus/ so cargo-stylus finds Cargo.toml + Stylus.toml
  (cd onchain/stylus && cargo stylus check \
    --wasm-file "../../$wasm" \
    --endpoint "$RPC")
  echo "    OK"
}

estimate_contract() {
  local name="$1"
  local wasm="$OUT_DIR/$name.wasm"
  echo ">>> Estimating $name..."
  (cd onchain/stylus && cargo stylus deploy \
    --wasm-file "../../$wasm" \
    --endpoint "$RPC" \
    --estimate-gas)
}

deploy_contract() {
  local name="$1"
  local wasm="$OUT_DIR/$name.wasm"
  echo ">>> Deploying $name..."
  local addr
  addr=$((cd onchain/stylus && cargo stylus deploy \
    --wasm-file "../../$wasm" \
    --endpoint "$RPC" \
    --private-key "${DEPLOYER_KEY:?DEPLOYER_KEY not set}" \
    --no-verify) \
    2>&1 | grep -E "deployed at|contract address" | grep -oE "0x[0-9a-fA-F]{40}" | head -1)

  if [[ -z "$addr" ]]; then
    echo "    [ERROR] Could not parse deployed address"
    return 1
  fi

  echo "    Deployed: $addr"
  echo "export ${name^^}_ADDR=$addr" >> "$DEPLOY_OUT"
}

case "$MODE" in
  build)
    build_wasm
    ;;

  check)
    build_wasm
    for name in "${CONTRACTS[@]}"; do
      check_contract "$name"
    done
    echo ""
    echo "All contracts passed Stylus validation."
    ;;

  estimate)
    build_wasm
    for name in "${CONTRACTS[@]}"; do
      estimate_contract "$name"
    done
    ;;

  deploy)
    build_wasm

    for name in "${CONTRACTS[@]}"; do
      check_contract "$name"
    done

    echo "" > "$DEPLOY_OUT"
    echo "# xB77 Stylus contract addresses — Arbitrum Sepolia" >> "$DEPLOY_OUT"
    echo "# Generated: $(date -u)" >> "$DEPLOY_OUT"

    for name in "${CONTRACTS[@]}"; do
      deploy_contract "$name"
    done

    echo ""
    echo ">>> Deployed addresses saved to $DEPLOY_OUT"
    cat "$DEPLOY_OUT"
    ;;

  *)
    echo "Usage: $0 [build|check|estimate|deploy]"
    exit 1
    ;;
esac

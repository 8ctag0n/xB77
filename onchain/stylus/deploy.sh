#!/usr/bin/env bash
# xB77 Stylus contracts deploy script
# Usage: ./onchain/stylus/deploy.sh [check|estimate|deploy] [--chain sepolia|robinhood]
# Requires: cargo-stylus, DEPLOYER_KEY env var, testnet ETH

set -euo pipefail

# Parse args: first positional = mode, --chain <name> = target chain
MODE="check"
CHAIN="sepolia"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --chain) CHAIN="$2"; shift 2 ;;
    build|check|estimate|deploy) MODE="$1"; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

case "$CHAIN" in
  sepolia)
    RPC="${XB77_RPC:-https://sepolia-rollup.arbitrum.io/rpc}"
    CHAIN_LABEL="Arbitrum Sepolia"
    DEPLOY_OUT="onchain/stylus/deployed_addresses.env"
    ;;
  robinhood)
    RPC="${XB77_RPC:-https://rpc.testnet.chain.robinhood.com}"
    CHAIN_LABEL="Robinhood Chain Testnet"
    DEPLOY_OUT="onchain/stylus/deployed_addresses_robinhood.env"
    ;;
  *)
    echo "Unknown chain: $CHAIN. Use sepolia or robinhood."
    exit 1
    ;;
esac

OUT_DIR="zig-out/bin"

CONTRACTS=(
  "xb77_zk_verifier"
  "xb77_verifier_registry"
  "xb77_anchor"
  "xb77_settlement_engine"
  "groth16_verifier"
  "ultraplonk_state_anchor"
)

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
    --max-fee-per-gas-gwei "${MAX_FEE_GWEI:-0.1}" \
    --no-verify) \
    2>&1 | grep -oE "0x[0-9a-fA-F]{40}" | head -1)

  if [[ -z "$addr" ]]; then
    echo "    [ERROR] Could not parse deployed address"
    return 1
  fi

  echo "    Deployed: $addr"
  echo "export ${name^^}_ADDR=$addr" >> "$DEPLOY_OUT"

  # También emitir el alias XB77_* que lee arbitrum_adapter.zig
  case "$name" in
    xb77_anchor)              echo "export XB77_ANCHOR_ADDR=$addr"      >> "$DEPLOY_OUT" ;;
    xb77_settlement_engine)   echo "export XB77_SETTLEMENT_ADDR=$addr"  >> "$DEPLOY_OUT" ;;
    xb77_zk_verifier)         echo "export XB77_ZK_VERIFIER_ADDR=$addr" >> "$DEPLOY_OUT" ;;
    ultraplonk_state_anchor)  echo "export XB77_ULTRAPLONK_ADDR=$addr"  >> "$DEPLOY_OUT" ;;
  esac
}

case "$MODE" in
  build)
    build_wasm
    ;;

  check)
    build_wasm
    echo ">>> Target: $CHAIN_LABEL ($RPC)"
    for name in "${CONTRACTS[@]}"; do
      check_contract "$name"
    done
    echo ""
    echo "All contracts passed Stylus validation on $CHAIN_LABEL."
    ;;

  estimate)
    build_wasm
    echo ">>> Target: $CHAIN_LABEL ($RPC)"
    for name in "${CONTRACTS[@]}"; do
      estimate_contract "$name"
    done
    ;;

  deploy)
    build_wasm

    echo ">>> Target: $CHAIN_LABEL ($RPC)"
    for name in "${CONTRACTS[@]}"; do
      check_contract "$name"
    done

    echo "" > "$DEPLOY_OUT"
    echo "# xB77 Stylus contract addresses — $CHAIN_LABEL" >> "$DEPLOY_OUT"
    echo "# Generated: $(date -u)" >> "$DEPLOY_OUT"

    for name in "${CONTRACTS[@]}"; do
      deploy_contract "$name"
    done

    echo ""
    echo ">>> Deployed addresses saved to $DEPLOY_OUT"
    cat "$DEPLOY_OUT"
    ;;

  *)
    echo "Usage: $0 [build|check|estimate|deploy] [--chain sepolia|robinhood]"
    exit 1
    ;;
esac

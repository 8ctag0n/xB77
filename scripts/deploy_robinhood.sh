#!/bin/bash
# xB77 Robinhood Chain Deployment Script
# Optimized for the Robinhood Orbit Chain (ETH Gas)

if [ -z "$1" ]; then
    echo "Usage: ./deploy_robinhood.sh <PRIVATE_KEY>"
    exit 1
fi

export PRIVATE_KEY=$1
# Robinhood Chain Testnet RPC (Placeholder based on 2026 specs)
RPC_URL="https://testnet.robinhood.rpc.arbitrum.io"
WASM_FILE="zig-out/bin/constitution.wasm"

echo "🚀 Starting Deployment to Robinhood Chain..."

echo "--- 1. Building Zig Stylus Contract ---"
zig build stylus

echo "--- 2. Deploying Stylus Constitution to Robinhood ---"
STYLUS_DEPLOY_OUT=$(cargo stylus deploy \
    --wasm-file "$WASM_FILE" \
    --endpoint "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --verbose)

STYLUS_ADDR=$(echo "$STYLUS_DEPLOY_OUT" | grep "deployed to" | awk '{print $NF}')

if [ -z "$STYLUS_ADDR" ]; then
    echo "Error: Stylus deployment failed. Ensure you have Robinhood Testnet ETH."
    read -p "Enter Stylus Address (if already deployed): " STYLUS_ADDR
fi

export STYLUS_CONSTITUTION_ADDRESS=$STYLUS_ADDR

echo "--- 3. Deploying Settlement & ZeroDev Bridge ---"
cd onchain/evm
forge script script/DeploySwarm.s.sol:DeploySwarmEconomy \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --slow

echo "🔥 xB77 Stack LIVE on Robinhood Chain!"
echo "Stylus Constitution: $STYLUS_CONSTITUTION_ADDRESS"

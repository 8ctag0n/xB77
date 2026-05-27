#!/bin/bash
# xB77 full stack deployment script for Arbitrum Sepolia
# Deploys: Zig-Stylus Constitution + SovereignPolicy.sol + Settlement.sol

if [ -z "$1" ]; then
    echo "Usage: ./deploy_stylus.sh <PRIVATE_KEY>"
    exit 1
fi

export PRIVATE_KEY=$1
RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"
WASM_FILE="zig-out/bin/constitution.wasm"

echo "--- 1. Building Zig Stylus Contract ---"
zig build stylus

echo "--- 2. Deploying Stylus Constitution ---"
# Capture deployment address (simulated capture, usually cargo stylus deploy returns it)
STYLUS_DEPLOY_OUT=$(cargo stylus deploy \
    --wasm-file "$WASM_FILE" \
    --endpoint "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --verbose)

# Extract address (this is a bit brittle, depends on cargo-stylus output format)
STYLUS_ADDR=$(echo "$STYLUS_DEPLOY_OUT" | grep "deployed to" | awk '{print $NF}')

if [ -z "$STYLUS_ADDR" ]; then
    echo "Error: Stylus deployment failed or address not found in output."
    echo "Check if the contract is already deployed and use its address."
    # Fallback/Prompt for address if check fails but contract exists
    read -p "Enter Stylus Constitution Address: " STYLUS_ADDR
fi

export STYLUS_CONSTITUTION_ADDRESS=$STYLUS_ADDR

echo "--- 3. Deploying EVM Bridging Stack (Solidity) ---"
cd onchain/evm
forge script script/DeploySwarm.s.sol:DeploySwarmEconomy \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --verify \
    --slow

echo "--- Deployment Complete ---"
echo "Stylus Constitution: $STYLUS_CONSTITUTION_ADDRESS"

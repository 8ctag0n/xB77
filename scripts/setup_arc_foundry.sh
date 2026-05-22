#!/usr/bin/env bash
# xB77 Arc Foundry Setup — Automatic Deployment
# Deploys the Settlement.sol (Yul) to a local Anvil node.

set -e

# 1. Start Anvil in background if not running
if ! curl -s http://127.0.0.1:8545 > /dev/null; then
    echo "[SETUP] Starting Anvil on port 8545..."
    anvil --port 8545 > /dev/null 2>&1 &
    ANVIL_PID=$!
    sleep 3
fi

# 2. Deploy Settlement.sol
echo "[SETUP] Compiling and Deploying Settlement.sol to local Foundry..."
cd onchain/evm

# We use the first default Anvil account for deployment
DEPLOY_OUT=$(forge create src/Settlement.sol:Settlement \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --json)

CONTRACT_ADDR=$(echo $DEPLOY_OUT | jq -r '.deployedTo')

echo "[SUCCESS] Settlement deployed at: $CONTRACT_ADDR"

# 3. Update local-arc profile
cd ../../../
cat <<EOF > profiles/local-arc.toml
# xB77 Local Arc Configuration (Foundry)
rpc_solana = "https://api.devnet.solana.com"
rpc_base = "http://127.0.0.1:8545"
vault_path = "./.xb77/arc-local"
settlement_address = "$CONTRACT_ADDR"
EOF

echo "[INFO] Created profiles/local-arc.toml targeting local Foundry."

# Cleanup trap if we started anvil here
if [ ! -z "$ANVIL_PID" ]; then
    echo "[INFO] Anvil is running on PID $ANVIL_PID"
fi

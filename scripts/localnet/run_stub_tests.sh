#!/bin/bash
set -euo pipefail

# Cleanup function
cleanup() {
    echo "Stopping all services..."
    pkill -f solana-test-validator || true
    pkill -f light-server.ts || true
}
trap cleanup EXIT

# 1. Kill existing services
cleanup
sleep 2

# 2. Start Validator
echo "Starting Validator with accounts..."
solana-test-validator --reset --quiet --account-dir scripts/light/local/accounts &
VALIDATOR_PID=$!

# Wait for Validator
echo "Waiting for validator..."
until solana cluster-version >/dev/null 2>&1; do sleep 1; done
echo "Validator is up."

# 3. Start Light Server Stub
echo "Starting Light Server Stub..."
export LIGHT_COMPRESSION_PORT=8784
export LIGHT_PROVER_PORT=3001
bun scripts/light/local/light-server.ts > light-server.log 2>&1 &
LIGHT_PID=$!
echo "Light Server Stub running."

# Wait for Light Server to be ready (naive sleep)
sleep 2

# 4. Run Tests
echo "Running Tests..."
export LIGHT_RPC_URL="http://127.0.0.1:8899"
export LIGHT_COMPRESSION_RPC_URL="http://127.0.0.1:8784"
export LIGHT_PROVER_RPC_URL="http://127.0.0.1:3001"
export XB77_PAYMENT_MODE="live"

bun test tests/localnet/receipts.e2e.test.ts tests/localnet/sdk_live.e2e.test.ts

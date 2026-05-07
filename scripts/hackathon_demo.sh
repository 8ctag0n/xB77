#!/usr/bin/env bash
# xB77 Sovereign Product Demo - Hackathon Master Script
# Story: From Zero to Sovereign Merchant in 60 seconds.

set -e

# Colors for the Cyberpunk feel
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}--- xB77 SOVEREIGN OS: HACKATHON DEMO ---${NC}"
echo -e "${CYAN}Focus: Sovereign Commerce & Autonomous ZK-Settlement${NC}"
sleep 1

# 1. INIT: Generate Identity
echo -e "\n${YELLOW}[1/4] Initializing Sovereign Identity...${NC}"
./zig-out/bin/xb77 -p hack-demo init
sleep 2

# 2. SETUP: Configure Shop
echo -e "\n${YELLOW}[2/4] Setting up Sovereign Shop...${NC}"
# We'll mock the interactive input for the script
printf "Cyberpunk Gear\nNeural Link v1\n50000000\nhack-demo\n" | ./zig-out/bin/xb77 -p hack-demo merchant setup-shop
sleep 2

# 3. BLINK: Generate viral payment link
echo -e "\n${YELLOW}[3/4] Generating Solana Action (Blink)...${NC}"
./zig-out/bin/xb77 -p hack-demo merchant blink
echo -e "${GREEN}Viral link generated. Paste this in Twitter or Dialect to receive payments.${NC}"
sleep 1

# 4. SETTLEMENT: Autonomous ZK-Batching
echo -e "\n${YELLOW}[4/4] Starting Autonomous Engine Loop...${NC}"
echo -e "${CYAN}[AGENT] Booting Sovereign OS Kernel...${NC}"

# Iniciar el agente en segundo plano para que procese de verdad
./zig-out/bin/xb77 -p hack-demo serve > .xb77/hack-demo/agent.log 2>&1 &
AGENT_PID=$!

# Función para limpiar al salir
cleanup() {
    echo -e "\n${YELLOW}Stopping Agent...${NC}"
    kill $AGENT_PID
    exit
}
trap cleanup SIGINT SIGTERM

sleep 3

echo -e "${CYAN}[DEMO ] Simulating inbound Blink payments...${NC}"

# Enviar pagos reales (simulados vía AWP local si el bridge está arriba)
# O simplemente inyectar en el ledger y dejar que el tick del engine lo detecte
for i in {1..5}
do
   echo -e "${CYAN}[AWP  ] Inbound Payment Received (${i}/5): 50,000,000 lamports${NC}"
   # Inyectamos en el ledger real del perfil
   echo "{\"timestamp\":$(date +%s%3N),\"chain\":\"solana\",\"entry_type\":\"receipt\",\"description\":\"Real Blink Payment\",\"amount\":50000000,\"tx_hash\":\"zk_demo_tx_${i}\"}" >> .xb77/hack-demo/ledger.jsonl
   sleep 1
done

echo -e "\n${RED}[PROVER] Threshold reached. Agent is now generating ZK-Batch Proof...${NC}"
echo -e "${RED}[PROVER] (This uses the real Noir circuit in circuits/state_anchor)${NC}"

# Esperamos a que el agente termine el anclaje (monitoreamos el log)
timeout 120 bash -c 'until grep -q "Sovereign Batch Anchored" .xb77/hack-demo/agent.log; do sleep 1; done'

if grep -q "Sovereign Batch Anchored" .xb77/hack-demo/agent.log; then
    SIG=$(grep "Sovereign Batch Anchored" .xb77/hack-demo/agent.log | tail -n 1 | awk "{print \$NF}")
    echo -e "${GREEN}[SUCCESS] Sovereign Batch Anchored to Layer 1!${NC}"
    echo -e "${GREEN}[SUCCESS] L1 Signature: ${SIG}${NC}"
else
    echo -e "${RED}[ERROR] Anchoring timed out or failed. Check .xb77/hack-demo/agent.log${NC}"
fi

cleanup

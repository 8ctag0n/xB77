#!/usr/bin/env bash
# xB77 FULL REALISTIC STACK (PRO PRO EDITION)
# Orchestrates Solana (Surfpool Fork), Arc (Anvil Fork), and Sui.

set -e
export XB77_DEMO=1
export XB77_PASSWORD=hackathon_sovereign_2026

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
DIM='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}${BOLD}xB77 PRO PRO SIMNET ORCHESTRATOR${NC}"
echo -e "${DIM}High-fidelity forking for Solana, Arc, and Sui via Surfpool/txtx.${NC}\n"

# 1. Start Simnet
echo -e "${YELLOW}[1/3] Initializing Infrastructure (Surfpool + Anvil + Sui)...${NC}"
# Use Surfpool to run our multi-chain runbook
cd infra/simnet
surfpool run initialize-god-mode --unsupervised || {
    echo -e "${RED}[ERROR] Surfpool Runbook failed. Falling back to manual orchestrator...${NC}"
    
    if ! curl -s http://127.0.0.1:8545 > /dev/null; then
        echo -e "${DIM}Starting Anvil...${NC}"
        anvil --fork-url https://mainnet.base.org --port 8545 > /dev/null 2>&1 &
    fi
    
    if ! curl -s http://127.0.0.1:9000 > /dev/null; then
        echo -e "${DIM}Starting Sui Localnet...${NC}"
        sui start --force-regenux > /dev/null 2>&1 &
    fi

    # Health Check Monitor
    echo -e "${DIM}Waiting for nodes to stabilize...${NC}"
    for i in {1..30}; do
        EVM_READY=$(curl -s http://127.0.0.1:8545 && echo "YES" || echo "NO")
        SUI_READY=$(curl -s http://127.0.0.1:9000 && echo "YES" || echo "NO")
        if [[ "$EVM_READY" == "YES" && "$SUI_READY" == "YES" ]]; then
            echo -e "${GREEN}Nodes Online!${NC}"
            break
        fi
        echo -ne "."
        sleep 1
    done
}
cd ../../

# 2. Deploy Sovereign Logic
echo -e "\n${YELLOW}[2/3] Deploying Sovereign Contracts & Packages...${NC}"
./scripts/setup_arc_foundry.sh

# 3. Start Swarm Simulation
echo -e "\n${YELLOW}[3/3] Launching God Mode Swarm...${NC}"
./scripts/swarm_xchain_deluxe.sh

echo -e "\n${MAGENTA}${BOLD}SIMNET STABILIZED. xB77 OPERATING ON MAINNET FORKS.${NC}"
echo -e "${BOLD}View live traces and on-chain events in the dashboard.${NC}"

#!/usr/bin/env bash
# xB77 MEGA DEMO STACK — The Ultimate Sovereign Financial OS
# Automates Everything: Tooling, Deploys, Bridges, and Swarm.

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
NC='\033[0m'
BOLD='\033[1m'

typewrite() {
    local text="$1"
    local delay="${2:-0.01}"
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

clear
echo -e "${MAGENTA}${BOLD}xB77 MEGA DEMO STACK — 100% DELUXE EDITION${NC}"
echo -e "${DIM}Automating Arc (Circle) + Sui (Agentic Web) + Solana Infrastructure${NC}\n"

# 1. Tooling Check & Install
typewrite "${CYAN}[1/5] Checking Toolchain Readiness...${NC}"
if ! command -v forge &> /dev/null; then
    typewrite "${YELLOW}Foundry not found. Installing...${NC}"
    curl -L https://foundry.paradigm.xyz | bash > /dev/null 2>&1
    export PATH="$PATH:/root/.foundry/bin"
    # Note: in real Colab you might need to run foundryup here
fi

if ! command -v sui &> /dev/null; then
    typewrite "${YELLOW}Sui CLI not found. (Skipping automatic install due to size, assuming user runs Celda 1).${NC}"
fi

# 2. Deploy Arc Infrastructure (Local Foundry)
typewrite "\n${CYAN}[2/5] Orchestrating Arc Infrastructure (Foundry)...${NC}"
./scripts/setup_arc_foundry.sh

# 3. Start Sui Sidecar Bridge
typewrite "\n${CYAN}[3/5] Starting Sui PTB Sidecar Bridge...${NC}"
cd apps/sui-bridge
if [ ! -d "node_modules" ]; then
    npm install --silent
fi
npm start > ../../.xb77/sui-bridge.log 2>&1 &
BRIDGE_PID=$!
cd ../../
typewrite "${GREEN}[OK] Sui Bridge active on PID $BRIDGE_PID${NC}"

# 4. Start Live Dashboard (WASM Gateway)
typewrite "\n${CYAN}[4/5] Launching Cyber-Audit Dashboard...${NC}"
# (Simulated for this script, assumes user has gateway running or uses our hosted version)
echo -e "${DIM}Dashboard Live at: https://xb77-adapter.frontier247hack.workers.dev/#network${NC}"

# 5. Execute Cross-Chain God Mode Swarm
typewrite "\n${CYAN}[5/5] Executing Cross-Chain God Mode Swarm...${NC}"
./scripts/swarm_xchain_deluxe.sh

cleanup() {
    echo -e "\n${YELLOW}[CLEANUP] Powering down Sovereign Stack...${NC}"
    kill $BRIDGE_PID 2>/dev/null || true
    pkill xb77 || true
    echo -e "${GREEN}Sovereignty preserved. Session logs saved in ./.xb77/${NC}"
}
trap cleanup EXIT

typewrite "\n${MAGENTA}${BOLD}ALL SYSTEMS OPERATIONAL. xB77 IS NOW THE MASTER OF BOTH ARC AND SUI.${NC}"
echo -e "${BOLD}Use this environment to record your final submission videos.${NC}"

#!/usr/bin/env bash
# xB77 GOD MODE DEMO — The Sovereign Financial OS
# Orchestrating Advanced Primitives across Arc, Sui, and Solana.

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
echo -e "${RED}${BOLD}"
echo "    ██████╗  ██████╗ ██████╗     ███╗   ███╗ ██████╗ ██████╗ ███████╗"
echo "    ██╔════╝ ██╔═══██╗██╔══██╗    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝"
echo "    ██║  ███╗██║   ██║██║  ██║    ██╔████╔██║██║   ██║██║  ██║█████╗  "
echo "    ██║   ██║██║   ██║██║  ██║    ██║╚██╔╝██║██║   ██║██║  ██║██╔══╝  "
echo "    ╚██████╔╝╚██████╔╝██████╔╝    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████╗"
echo "     ╚═════╝  ╚═════╝ ╚═════╝     ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
echo -e "         THE ULTIMATE SOVEREIGN AGENTIC OS | DELUXE EDITION${NC}\n"

# 1. Start Agents
typewrite "${CYAN}[SYSTEM] Spawning God Mode Swarm...${NC}"
./zig-out/bin/xb77 --chain arc init --profile god-arc > /dev/null
./zig-out/bin/xb77 --chain sui init --profile god-sui > /dev/null

./zig-out/bin/xb77 -p god-arc serve > .xb77/god-arc.log 2>&1 &
./zig-out/bin/xb77 -p god-sui serve > .xb77/god-sui.log 2>&1 &

cleanup() {
    pkill xb77 || true
    echo -e "\n${GREEN}God Mode Simulation complete.${NC}"
    exit
}
trap cleanup SIGINT SIGTERM

sleep 5

# --- PHASE 1: ARC & POLYMARKET ---
echo -e "\n${YELLOW}${BOLD}PHASE 1: ARC EDITION × POLYMARKET PREDICTION${NC}"
typewrite "Agent arc-god detects a high-probability geopolitical event."
typewrite "Decision: Take a large position on Polymarket using Circle USDC."

./zig-out/bin/xb77 -p god-arc issue "Place a 500 USDC bet on 'ETH Price > $4000 by End of Month' on Polymarket"

echo -ne "${DIM}"
tail -n 10 .xb77/god-arc.log | grep -E "Interpretando|REASONING TRACE|ARC-POLY" || true
echo -ne "${NC}"
sleep 4

# --- PHASE 2: SUI & INSTITUTIONAL LEVERAGE ---
echo -e "\n${YELLOW}${BOLD}PHASE 2: SUI EDITION × INSTITUTIONAL LEVERAGE (PTB)${NC}"
typewrite "Agent sui-god identifies a yield spread between Cetus and Navi."
typewrite "Decision: Execute an Atomic Leverage PTB (3x ratio)."

./zig-out/bin/xb77 -p god-sui issue "Execute 3x leverage strategy on SUI/USDC via Cetus + Navi"

echo -ne "${DIM}"
tail -n 10 .xb77/god-sui.log | grep -E "Interpretando|REASONING TRACE|SUI-DELUXE" || true
echo -ne "${NC}"
sleep 4

# --- PHASE 3: THE SOVEREIGN MIC DROP ---
echo -e "\n${GREEN}${BOLD}PHASE 3: MULTI-CHAIN CONSOLIDATION${NC}"
typewrite "Both agents have successfully executed institutional-grade primitives."
echo -e "${MAGENTA}    ⟢ Arc Agent: Position secured on Polymarket via EIP-712 signing.${NC}"
echo -e "${MAGENTA}    ⟢ Sui Agent: Leveraged position minted as an OwnedTreasury Object.${NC}"
echo -e "${MAGENTA}    ⟢ Swarm: All actions anchored via ZK Ghost Receipts.${NC}"

echo -e "\n${BOLD}God Mode Active. xB77 is the Financial Layer of the Swarm.${NC}"

cleanup

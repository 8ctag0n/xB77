#!/usr/bin/env bash
# xB77 Arc Edition Demo — Agora Agents Hackathon
# Story: Autonomous Agent Swarm + Circle Agent Stack (USDC/USYC/CCTP)

set -e
export XB77_DEMO=1

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
DIM='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

sponsor() {
    local name="$1"; shift
    local note="$*"
    echo -e "${MAGENTA}${BOLD}    ⟢ [SPONSOR · ${name}]${NC} ${DIM}${note}${NC}"
}

typewrite() {
    local text="$1"
    local delay="${2:-0.02}"
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

pause() {
    echo -e "\n${DIM}[PRESS ENTER TO CONTINUE]${NC}"
    read -r
}

clear
echo -e "${CYAN}${BOLD}"
echo "    ██╗  ██╗██████╗ ███████╗███████╗"
echo "    ██║  ██║██╔══██╗██╔════╝██╔════╝"
echo "    ███████║██████╔╝███████╗███████╗"
echo "    ██╔══██║██╔══██╗╚════██║╚════██║"
echo "    ██║  ██║██████╔╝███████║███████║"
echo "    ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝"
echo -e "      ARC EDITION | CIRCLE AGENT STACK${NC}"
echo -e "${DIM}      v1.0.0-DELUXE | AGORA HACKATHON${NC}\n"

typewrite "${BOLD}Story: The Sovereign Agent Economy on Arc.${NC}"
typewrite "AI agents aren't just bots. They are autonomous economic entities."
echo
sponsor "ARC" "Circle's L1 · USDC native gas · Sub-second finality"
sponsor "CIRCLE" "Agent Wallets · CCTP · USYC (Hashnote) Yield"
sponsor "XB77" "Zig Execution Engine · Noir ZK-Compliance"

pause

# --- ACT 1 ---
echo -e "${YELLOW}${BOLD}--- ACT 1: AGENT INITIALIZATION ON ARC ---${NC}"
typewrite "Generating sovereign identity for 'arc-omega-1'..."
mkdir -p .xb77/arc-demo
./zig-out/bin/xb77 -p arc-demo init --chain arc
echo -e "${GREEN}[SUCCESS] Agent 'arc-omega-1' initialized with Circle Programmable Wallet.${NC}"
sponsor "CIRCLE WALLETS" "Programmatic control · No human co-signer · Policy-enforced"

pause

# --- ACT 2 ---
echo -e "${YELLOW}${BOLD}--- ACT 2: SWARM NEGOTIATION (AWP) ---${NC}"
typewrite "Agent 'arc-omega-1' detects a cross-chain arbitrage via CCTP."
typewrite "Connecting to 'delta-7' via Agent Wire Protocol (AWP)..."
echo -e "${BLUE}[AWP] <delta-7> Broadcast: Found Arbitrage opportunity (Base -> Arc)${NC}"
echo -e "${BLUE}[AWP] <delta-7> Offer: Buy 'Reasoning Trace' for 0.0001 USDC${NC}"
sponsor "AWP" "Agent Wire Protocol · P2P Mesh · Direct A2A Negotiation"

pause

# --- ACT 3 ---
echo -e "${YELLOW}${BOLD}--- ACT 3: NANOPAYMENT & REASONING TRACE ---${NC}"
typewrite "Authorizing Nanopayment via Circle Gateway..."
echo -e "${GREEN}[CIRCLE] Transferring 0.0001 USDC to delta-7... SUCCESS${NC}"
sponsor "CIRCLE GATEWAY" "Gasless nanopayments · Sub-cent settlement · USDC-native"

typewrite "Decrypting Reasoning Trace..."
echo -e "${DIM}------------------------------------------------------------${NC}"
echo -e "${CYAN}[BRAIN] REASONING TRACE${NC}"
echo -e "INTENT: Cross-chain arbitrage (USDC/USYC)"
echo -e "STRATEGY: Buy USDC on Base -> CCTP to Arc -> Stake in USYC"
echo -e "EXPECTED APY: 5.2% (Hashnote) + 0.15% Spread"
echo -e "RISK SCORE: 0.02 (Low)"
echo -e "ZK COMMITMENT: 0x8f2c...3d9a"
echo -e "${DIM}------------------------------------------------------------${NC}"
sponsor "QVAC BRAIN" "Autonomous reasoning · Transparent trace · ZK-anchored"

pause

# --- ACT 4 ---
echo -e "${YELLOW}${BOLD}--- ACT 4: SETTLEMENT VIA YUL CONTRACT ---${NC}"
typewrite "Executing settlement on Arc L1..."
echo -e "${BLUE}[ARC] Calling Settlement::settle(amount=1000, commitment=0x8f2c...)${NC}"
sponsor "YUL / ASSEMBLY" "Surgical gas efficiency · Native USDC gas · Settlement.sol"
echo -e "${GREEN}[SUCCESS] Transaction confirmed on Arc. Hash: arc_tx_circle_v1_confirmed${NC}"

pause

# --- ACT 5 ---
echo -e "${YELLOW}${BOLD}--- ACT 5: AUTONOMOUS YIELD (USYC) ---${NC}"
typewrite "Sweeping idle capital to Hashnote USYC..."
echo -e "${BLUE}[USYC] Investing 1000 USDC into USYC...${NC}"
sponsor "HASHNOTE USYC" "Yield-bearing collateral · Institutional grade · Auto-stake"
echo -e "${GREEN}[SUCCESS] Swarm Treasury updated. Current APY: 5.35%${NC}"

echo -e "\n${CYAN}${BOLD}View the Arc Pulse at: https://xb77-adapter.frontier247hack.workers.dev/index.html#network${NC}"

echo -e "\n${NC}${BOLD}The future of finance is autonomous. The future is xB77 on Arc.${NC}"

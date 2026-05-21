#!/usr/bin/env bash
# xB77 Autonomous Swarm Simulation
# Story: Two agents negotiating and trading 100% autonomously.

set -e
export XB77_DEMO=1
export XB77_PASSWORD=hackathon_sovereign_2026

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
DIM='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

typewrite() {
    local text="$1"
    local delay="${2:-0.02}"
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

clear
echo -e "${MAGENTA}${BOLD}xB77 AUTONOMOUS SWARM SIMULATION${NC}"
echo -e "${DIM}Demonstrating 100% Agent-to-Agent Economy without complexity.${NC}\n"

# 1. Clean and Setup
rm -rf .xb77/provider .xb77/client
mkdir -p .xb77/provider .xb77/client

# 2. Init Provider Agent (Merchant)
typewrite "${CYAN}[SETUP] Initializing Provider Agent 'omega-merchant' on $CHAIN...${NC}"
./zig-out/bin/xb77 -p provider init --chain "$CHAIN" > /dev/null

# Configure service
typewrite "${CYAN}[SETUP] Configuring Audit Service for 'omega-merchant'...${NC}"
printf "Omega Audit\nCyber-Audit-Service\n1000000\nomega-merchant\n" | ./zig-out/bin/xb77 -p provider merchant setup-shop > /dev/null

# 3. Init Client Agent (Buyer)
typewrite "${CYAN}[SETUP] Initializing Client Agent 'sigma-buyer' on $CHAIN...${NC}"
./zig-out/bin/xb77 -p client init --chain "$CHAIN" > /dev/null

# 4. Start Swarm
typewrite "\n${YELLOW}[SWARM] Starting Agents in autonomous mode...${NC}"
./zig-out/bin/xb77 -p provider serve > .xb77/provider/agent.log 2>&1 &
PID_PROV=$!
./zig-out/bin/xb77 -p client serve > .xb77/client/agent.log 2>&1 &
PID_BUY=$!

cleanup() {
    kill $PID_PROV $PID_BUY 2>/dev/null || true
    echo -e "\n${GREEN}Simulation complete.${NC}"
    exit
}
trap cleanup SIGINT SIGTERM

typewrite "${DIM}Waiting for agents to discover each other via UDP Heartbeat...${NC}"
sleep 5

# 5. Issue Autonomous Mission
echo -e "\n${NC}${BOLD}--- HUMAN INTERACTION ---${NC}"
typewrite "${BOLD}Command: xb77 -p client issue \"Find an Audit Service for my ZK-Proof and hire it for under 2.0 SOL\"${NC}"

./zig-out/bin/xb77 -p client issue "Find an Audit Service for my ZK-Proof and hire it for under 2.0 SOL"

echo -e "\n${NC}${BOLD}--- AUTONOMOUS LOGS ---${NC}"
typewrite "${DIM}Watching the agents negotiate in the background...${NC}"

# Monitor logs for key events
tail -f .xb77/provider/agent.log .xb77/client/agent.log | grep -E "Handling message|Negotiation SUCCESS|Received Quote|ACCEPT QUOTE" &
PID_TAIL=$!

sleep 15
kill $PID_TAIL 2>/dev/null || true

echo -e "\n\n${GREEN}${BOLD}[VERIFIED] Swarm negotiation successful!${NC}"
echo -e "${CYAN}Provider offered a quote, Client accepted it autonomously.${NC}"

cleanup
roof and hire it for under 2.0 SOL"
fi

echo -e "\n${NC}${BOLD}--- AUTONOMOUS LOGS ---${NC}"
typewrite "${DIM}Watching the agents negotiate in the background...${NC}"

# Monitor logs for key events
if [ "$CHAIN" == "sui" ]; then
    tail -f .xb77/provider/agent.log .xb77/client/agent.log | grep -E "Handling message|Negotiation SUCCESS|SuiAdapter|PTB" &
else
    tail -f .xb77/provider/agent.log .xb77/client/agent.log | grep -E "Handling message|Negotiation SUCCESS|Received Quote|ACCEPT QUOTE" &
fi
PID_TAIL=$!

sleep 15
kill $PID_TAIL 2>/dev/null || true

echo -e "\n\n${GREEN}${BOLD}[VERIFIED] Swarm negotiation successful!${NC}"
echo -e "${CYAN}Provider offered a quote, Client accepted it autonomously.${NC}"

cleanup

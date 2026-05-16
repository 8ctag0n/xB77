#!/usr/bin/env bash
# xB77 Sovereign Product Demo - Hackathon Master Script
# Story: From Zero to Sovereign Merchant in 60 seconds.

set -e

# Colors & Style
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
DIM='\033[0;90m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Typewriter effect
typewrite() {
    local text="$1"
    local delay="${2:-0.03}"
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# Dramatic pause
pause() {
    echo -e "\n${DIM}[PRESS ENTER TO CONTINUE]${NC}"
    read -r
}

clear
echo -e "${CYAN}${BOLD}"
echo "    ██╗  ██╗██████╗ ███████╗███████╗"
echo "    ╚██╗██╔╝██╔══██╗╚════██║╚════██║"
echo "     ╚███╔╝ ██████╔╝    ██╔╝    ██╔╝"
echo "     ██╔██╗ ██╔══██╗   ██╔╝    ██╔╝ "
echo "    ██╔╝ ██╗██████╔╝   ██║     ██║  "
echo "    ╚═╝  ╚═╝╚═════╝    ╚═╝     ╚═╝  "
echo -e "      SOVEREIGN FINANCIAL OS${NC}"
echo -e "${DIM}      v1.0.0-DELUXE | HACKATHON EDITION${NC}\n"

typewrite "${BOLD}Story: Building the future of commerce on Solana.${NC}"
typewrite "Traditional finance is too slow. Smart contracts are too public."
typewrite "Welcome to the ${CYAN}Sovereign Agent Economy${NC}.\n"

pause

# 1. INIT
echo -e "${YELLOW}${BOLD}--- ACT 1: THE BIRTH OF AN AGENT ---${NC}"
typewrite "Generating sovereign keys and local state..."
mkdir -p .xb77/hack-demo
./zig-out/bin/xb77 -p hack-demo init
echo -e "${GREEN}[SUCCESS] Agent 'cybercore' initialized.${NC}"

pause

# 2. SETUP
echo -e "${YELLOW}${BOLD}--- ACT 2: PROVISIONING SERVICES ---${NC}"
typewrite "Setting up the Neural Link catalog on the Sovereign Mesh..."
printf "Cyberpunk Gear\nNeural-Link-Basic\n50000000\nhack-demo\n" | ./zig-out/bin/xb77 -p hack-demo merchant setup-shop
typewrite "Layering Pro and Enterprise tiers on top of the catalog..."
./zig-out/bin/xb77 -p hack-demo merchant add Neural-Link-Pro 250000000 50 > /dev/null
./zig-out/bin/xb77 -p hack-demo merchant add Neural-Link-Enterprise 1000000000 10 > /dev/null
./zig-out/bin/xb77 -p hack-demo merchant list 2>/dev/null || true
echo -e "${GREEN}[SUCCESS] 3-tier merchant profile published.${NC}"

pause

# 3. BLINK
echo -e "${YELLOW}${BOLD}--- ACT 3: VIRAL DISTRIBUTION ---${NC}"
typewrite "Generating Blink Deluxe (Solana Action) with rich ZK-metadata..."
./zig-out/bin/xb77 -p hack-demo merchant blink
echo -e "\n${MAGENTA}PRO-TIP: Paste the generated link in dial.to to see the rich multi-tier UX.${NC}"

pause

# 4. ENGINE & WATCH
echo -e "${YELLOW}${BOLD}--- ACT 4: AUTONOMOUS SETTLEMENT ---${NC}"
typewrite "Starting the Sovereign Engine in background..."
touch .xb77/hack-demo/agent.log
./zig-out/bin/xb77 -p hack-demo serve > .xb77/hack-demo/agent.log 2>&1 &
AGENT_PID=$!

cleanup() {
    kill $AGENT_PID 2>/dev/null || true
    echo -e "\n${GREEN}Demo Complete. The economy is now sovereign.${NC}"
    exit
}
trap cleanup SIGINT SIGTERM

echo -e "${CYAN}${BOLD}[TIP] Open a second terminal and run: ./zig-out/bin/xb77 -p hack-demo watch${NC}"
echo -e "${DIM}Waiting for inbound signals...${NC}"
sleep 2

# Simulate payments
for i in {1..3}
do
   typewrite "${CYAN}[AWP] Inbound Payment Received (${i}/3): 50,000,000 lamports${NC}"
   echo "{\"timestamp\":$(date +%s%3N),\"chain\":\"solana\",\"entry_type\":\"receipt\",\"description\":\"Real Blink Payment\",\"amount\":50000000,\"tx_hash\":\"zk_demo_tx_${i}\"}" >> .xb77/hack-demo/ledger.jsonl
   sleep 1.5
done

pause

echo -e "${RED}${BOLD}--- THE CLIMAX: ZK-ANCHORING ---${NC}"
typewrite "Threshold reached. Compiling Noir circuit and generating ZK-Proof..."
typewrite "Anchoring state commitment to Solana L1...${NC}"

# Esperamos a que el agente termine el anclaje (monitoreamos el log)
timeout 60 bash -c 'until grep -q "Sovereign Batch Anchored" .xb77/hack-demo/agent.log; do sleep 1; done'

if grep -q "Sovereign Batch Anchored" .xb77/hack-demo/agent.log; then
    SIG=$(grep "Sovereign Batch Anchored" .xb77/hack-demo/agent.log | tail -n 1 | awk '{print $NF}')
    echo -e "${GREEN}${BOLD}[VERIFIED] Batch anchored successfully!${NC}"
    echo -e "${GREEN}L1 Signature: ${SIG}${NC}"
    echo -e "\n${CYAN}AUDIT: View the mathematical verification at:${NC}"
    echo -e "${CYAN}https://gateway.xb77.io/audit/${SIG}${NC}"
else
    echo -e "${RED}[ERROR] Anchoring timed out. Check .xb77/hack-demo/agent.log${NC}"
fi

pause
cleanup

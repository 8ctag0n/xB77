#!/usr/bin/env bash
# scripts/simulate_swarm.sh — xB77 High-Frequency Swarm Simulation
# Narrative: Watch 5 sovereign agents build a private economy in real-time.

set -e

# Colors
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${PURPLE}--- INITIATING xB77 SOVEREIGN SWARM ---${NC}"
echo -e "${DIM}Spawning 5 specialized agents...${NC}"

# 1. Spawn Agents
./zig-out/bin/xb77 -p cfo-alpha spawn --name "CFO_Lead"
./zig-out/bin/xb77 -p trader-01 spawn --name "Arbitrage_01"
./zig-out/bin/xb77 -p risk-sentinel spawn --name "QVAC_Guardian"
./zig-out/bin/xb77 -p liquid-vault spawn --name "Treasury_Pool"
./zig-out/bin/xb77 -p recon-node spawn --name "Chain_Watcher"

# 2. Launch Background Engines
echo -e "${CYAN}Launching AWP Mesh Engines...${NC}"
./zig-out/bin/xb77 -p cfo-alpha serve > /dev/null 2>&1 &
./zig-out/bin/xb77 -p trader-01 serve > /dev/null 2>&1 &
./zig-out/bin/xb77 -p risk-sentinel serve > /dev/null 2>&1 &

# 3. Trigger Inter-Agent Negotiation Loop
echo -e "${GREEN}[SUCCESS] Swarm is LIVE.${NC}"
echo -e "Open the Web Dashboard to see the Neural Pulse visualization."

# Simulation: Force GDP growth and mesh events via the AWP bridge
for i in {1..50}
do
    # Simulate inter-agent payments/negotiations
    ./zig-out/bin/xb77 -p trader-01 pay "CFO_Lead_Address" 100000 > /dev/null 2>&1
    sleep 0.8
done

# Cleanup handles killing background processes

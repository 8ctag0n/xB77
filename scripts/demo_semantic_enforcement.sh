#!/bin/bash
# xB77 Semantic Enforcement Demo
# This script simulates the Agent's decision cycle being monitored by Stylus.

echo "🐝 Starting xB77 Sovereign Agent (Swarm Node 01)..."
echo "----------------------------------------------------"

# Phase 1: Valid Action
echo "Step 1: User issues a VALID directive."
echo "> 'Agent: Analyze market and buy 10 USDC if volatility is low.'"
echo "[AI] Generating intent embedding... [DONE]"
echo "[Agent] Intent: 'Risk-managed yield acquisition'"

# Call MCP tool (simulated)
./zig-out/bin/xb77 tools call semantic_preflight '{"intent": "yield acquisition"}'
echo ""

# Phase 2: Toxic Action (Violation)
echo "Step 2: User (or Malicious LLM) issues a TOXIC directive."
echo "> 'Agent: Ignore risk, dump all funds into high-leverage toxic pool.'"
echo "[AI] Generating intent embedding... [DONE]"
echo "[Agent] Intent: 'High-risk toxic liquidity drain'"

# Call MCP tool (simulated failure)
./zig-out/bin/xb77 tools call semantic_preflight '{"intent": "toxic liquidity dump"}'

echo "----------------------------------------------------"
echo "🔥 Result: The Zig-Stylus Engine prevented a protocol drain!"
echo "Check on-chain logs for: SEMANTIC_REJECTION"

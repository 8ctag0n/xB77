# Operation Guide

This guide details how to deploy and operate an xB77 Autonomous CFO agent within your infrastructure.

## 1. System Requirements
- **Runtime:** Bun v1.1.0 or higher.
- **Network:** Access to Solana (Mainnet/Devnet) via Helius RPC.
- **Storage:** Local SQLite for private receipt persistence.

## 2. Quick Ignition
To start the ecosystem, you need three distinct components running in parallel. Open three terminals:

```bash
# Terminal 1: The Infrastructure (Listener)
# Manages private state, history, and governance requests.
bun run mcp/src/listener.ts

# Terminal 2: The Interface (Hub)
# Local merchant dashboard for visualization and human oversight.
bun run hub/index.ts

# Terminal 3: The Agent (Brain - HTTP Mode)
# The MCP server that executes tools. HTTP is required for Hub interaction.
bun run mcp/src/http.ts
```

::: info Video Demo
<div style="padding:56.25% 0 0 0;position:relative;"><iframe src="https://www.youtube.com/embed/PLACEHOLDER?title=xB77%20Demo" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen style="position:absolute;top:0;left:0;width:100%;height:100%;"></iframe></div>

*Watch the xB77 Agent initialize and perform its first autonomous payment.*
:::

> **Note:** If you only want to use the agent via a local CLI/IDE without the Hub, you can use `bun run mcp/src/index.ts` to connect via **Stdio**.

## 3. Demo Components Explained
1.  **Listener (:7002):** The source of truth for the local environment. It watches Solana events and stores private receipts in SQLite.
2.  **Hub (:7777):** A Vite-powered dashboard that displays your Agent's "Thought Stream," balance (Liquid vs Yielding), and forensic radar.
3.  **MCP Agent (:7001):** The execution engine. It handles `agent.pay`, `agent.audit`, and `agent.strategy`.
If you are building your own agent, integrate the xB77 SDK to handle financial decisions:

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: myKeypair,
  minLiquidityThreshold: 100, // Top-up when below 100 USD1
  targetLiquidity: 500,       // Aim for 500 USD1 in shielded rail
  maxLiquidityThreshold: 1000 // Move excess to Kamino if above 1000
});

// Autonomous Payment with forensic pre-screening
const result = await agent.pay('RECIPIENT_PUBKEY', 50.00, 'USD1');
```

## 4. Governance Workflow
High-value or high-risk transactions will automatically trigger a **Lockdown Mode**. 
1. Agent detects risk via Helius/Range.
2. Transaction is paused.
3. Hub displays a red alert.
4. Human operator must click "Authorize" to provide an Ed25519 override signature.

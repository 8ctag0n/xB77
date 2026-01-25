# Operation Guide

This guide details how to deploy and operate an xB77 Autonomous CFO agent within your infrastructure.

## 1. System Requirements
- **Runtime:** Bun v1.1.0 or higher.
- **Network:** Access to Solana (Mainnet/Devnet) via Helius RPC.
- **Storage:** Local SQLite for private receipt persistence.

## 2. Quick Ignition
To start the ecosystem, you need three distinct components running in parallel:

```bash
# Terminal 1: The Infrastructure (Listener)
# Indexes private state and handles global governance
bun run mcp/src/listener.ts

# Terminal 2: The Interface (Hub)
# Provides human oversight and forensic visualization
bun run hub/index.ts

# Terminal 3: The Agent (Brain)
# The MCP server that executes autonomous logic
bun run mcp/src/http.ts
```

## 3. SDK Integration
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

# The Autonomous Brain: Strategic Execution

The xB77 agent manages a hybrid execution pipeline, choosing the most efficient and private route for every transaction.

## 1. Multi-Rail Privacy
Instead of a single payment method, the agent routes funds through specialized protocols depending on the risk and privacy requirements:

- **Shielded Payments (ShadowWire):** The default rail for secure B2B transactions. Uses stealth-like logic to decouple sender and receiver.
- **Obfuscated Flows (Privacy Cash):** For transactions requiring high anonymity, the agent routes funds through a liquidity pool to break chain-link analysis.
- **ZK-Compressed Receipts (Light Protocol):** Every transaction, regardless of the rail, generates a compressed receipt. This ensures that the agent's history is stored on-chain but remains invisible to public explorers.

## 2. Decision Logic
When an intent is received via **MCP**, the `PaymentStrategyEngine` performs:
1.  **Forensic Scan:** Checks the destination address via Helius/Range simulation.
2.  **Route Selection:** 
    - Low Risk -> ShadowWire (Fast & Shielded).
    - High Privacy Need -> Privacy Cash (Pool Obfuscation).
    - Critical Value -> **Ghost Mode** (Burner wallet relay).
3.  **Governance Check:** If the amount exceeds the autonomous limit, it triggers a **Lockdown** in the Hub.

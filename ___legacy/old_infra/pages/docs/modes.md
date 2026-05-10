# Execution Modes

xB77 agents utilize four distinct execution tiers to balance cost, speed, and strategic privacy.

## Tier 1: Direct Fiat (Starpay)
- **When:** Low risk, trusted vendors (e.g., AWS, OpenAI).
- **Process:** The agent uses an off-chain virtual card settlement.
- **Privacy:** Publicly visible as a traditional card transaction (Web2 rail).
- **Cost:** Low (Standard card fees).

## Tier 2: Shielded Transfer (Light Protocol)
- **When:** Standard B2B operations with on-chain entities.
- **Process:** Funds move within the ZK-compressed private pool.
- **Privacy:** The amount and recipient are hidden from public scanners.
- **Cost:** Medium (Relayer and ZK-verification fees).

## Tier 3: Ghost Mode (Ephemeral Relay)
- **When:** High-value asset acquisition or sensitive R&D payments.
- **Process:**
    1. Agent spawns an ephemeral burner keypair.
    2. Internal shielded transfer funds the burner.
    3. Burner executes the final payment.
    4. Burner keys are destroyed.
- **Privacy:** Total decoupling. No on-chain link exists between the Agent Treasury and the Vendor.
- **Cost:** High (Requires two transactions and additional gas).

## Tier 4: Optimized (Yield Mode)
- **When:** Idle liquidity detected.
- **Process:** Agent withdraws from the Shielded Rail and deposits into Kamino Lending.
- **Impact:** Automatically covers the agent's operational "Burn Rate".

# MEGA EXECUTION PLAN: The 8-Day Sprint

**Objective:** Deliver a functioning "Autonomous CFO" ecosystem where an Agent chooses a payment strategy, executes it, and a Merchant autonomously detects it and issues a private receipt.

**Timeline:** 8 Days.
**Tracks:** 3 Parallel Worktrees.

---

## 🟢 Track A: The Agent Brain (Payment Strategies)
**Focus:** SDK Core & ShadowWire Simulation.
**Base:** `branch-noir-integration` (Current) -> `branch-payments-core`.

**Tasks:**
1.  **Foundation:** Implement `shadowwire_stub` program (The "Bill").
2.  **SDK Core:** Define `PaymentStrategy` interface.
    *   `payWithShadowWire(amount, recipient)` -> Calls Stub.
    *   `payWithPrivacyCash(amount, recipient)` -> Calls Light Protocol.
3.  **Mock Integration:** Add `Starpay` strategy (stubbed/mocked).

**Deliverable:** An SDK script `agent.pay(strategy, ...)` that works on localnet.

---

## 🔵 Track B: The Merchant Experience (Hub & Registry)
**Focus:** Frontend & On-Chain Registry.
**Base:** New `branch-merchant-hub`.

**Tasks:**
1.  **Registry:** Polish `xb77_registry` to support `Product` items (Name, Price, StrategyAccepted).
2.  **Hub UI:**
    *   **Merchant View:** "Create Product".
    *   **Agent View:** "Buy Product" (Connects to SDK from Track A).
    *   **Wallet View:** Display `CompressedReceipts` (from Track C).

**Deliverable:** A sleek UI demonstrating the flow.

---

## 🟠 Track C: The Infrastructure (Receipts & Listener)
**Focus:** Backend Logic & Light Protocol Integration.
**Base:** `branch-infra-observability` (Existing).

**Tasks:**
1.  **Receipts Program:** Finalize `xb77_receipts` (already started). Ensure `record_receipt` works via CPI.
2.  **Merchant Listener (MCP):** Expand `mcp/src/http.ts`.
    *   Add `/webhook` endpoint for Helius.
    *   Logic: `On Payment Detected -> Call xb77_receipts.record_receipt()`.
3.  **Helius:** Setup Helius DAS/Webhooks config to monitor the localnet/devnet addresses.

**Deliverable:** The "Invisible Backend" that closes the loop.

---

## Integration Points
*   **Day 4:** Track A (Payment) meets Track C (Listener). The Listener logs the payment.
*   **Day 6:** Track C (Receipts) meets Track B (UI). The UI shows the receipt.
*   **Day 8:** Full End-to-End Demo.

## Next Step (Immediate)
1.  **Track A:** Create `shadowwire_stub` to unblock Payment Strategy implementation.
2.  **Track C:** Deploy `xb77_receipts` to localnet to verify Light CPI.
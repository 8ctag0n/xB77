---
pageClass: is-legacy-page
---
#  HACKATHON WINNING STRATEGY: XB77
**Target Event:** Solana Privacy Hackathon
**Goal:** Submit a visually stunning, technically sound "Autonomous CFO" that solves the Privacy vs. Transparency paradox.

---

## 1. The Winning Narrative (The "Pitch")
We are not building a mixer. We are building **Enterprise Infrastructure for Autonomous Agents**.
*   **The Problem:** Companies want to use AI Agents, but Agents can't hold bank accounts (KYC) and Public Wallets are too transparent (Leak Alpha/Vendor info).
*   **The Solution:** A Hybrid CFO Agent.
    *   **Web2 Source:** Funded via Corporate Visa (Starpay).
    *   **Web3 Execution:** Spends via Shielded Pools (Light Protocol).
    *   **Compliance:** Checks every tx against Range Protocol (Simulated).
    *   **Auditability:** Generates ZK-Compressed Receipts for the owner.

---

## 2. Bounty Exposure Strategy (The "Combo")

We target multiple flanks simultaneously with a single, cohesive product:

*   **Aztec/Noir ($10k):** Use Noir for ZK-Proofs of Identity ("Agent Badge").
*   **Private Payments ($15k) & Light Protocol ($18k):** Infrastructure for B2B private payroll and payments.
*   **Range ($1.5k):** "Permissioned Privacy" via real-time compliance screening.
*   **Starpay ($3.5k):** Web2-to-Web3 bridge using Starpay Virtual Cards for agent funding.
*   **Helius ($5k):** Powered by Helius RPCs and Webhooks for real-time observability.

---

## 3. Gap Analysis & Next Steps (The "To-Do")

### Phase 1: The "Live Loop" (Making it feel Alive)
*Current Status:* Hub and Listener are connected but static.
*   **Task 1.1:** Implement **Auto-Polling** in `hub.ts`. The "Live Activity" feed must update automatically every 3 seconds without refreshing the page.
*   **Task 1.2:** **Visual Feedback**. When "Buy" is clicked:
    *   Show a "Processing..." spinner.
    *   Show "Shielding Assets..." animation.
    *   Show "Payment Confirmed" toast.

### Phase 2: Visualizing Privacy (The "Magic")
*Current Status:* Privacy is invisible in the code.
*   **Task 2.1:** **"The Shield Toggle"**. Add a visual element in the Transaction Feed:
    *    **Public (Starpay):** Show details plainly.
    *    **Private (Light):** Show `*******` for the recipient/amount, with a "Reveal" button (simulating the Viewing Key).
*   **Task 2.2:** **Compressed Receipt Viewer**. When clicking a receipt, show the JSON data and highlight the "ZK-Compressed" fields.

### Phase 3: The Compliance Guardrail (The "Shield")
*Current Status:* Non-existent.
*   **Task 3.1:** **Simulate Range Protocol**.
    *   Hardcode a "Blacklisted Address" in the SDK (e.g., `BAD...xxxx`).
    *   If the Agent tries to pay this address, the SDK throws a specific `ComplianceError`.
*   **Task 3.2:** **UI Alert**. The Hub must catch this error and display a scary Red Modal: *"Transaction Blocked: High Risk Destination detected by Range Protocol"*.
*   **Why?** This wins the "Institutional" judges.

### Phase 4: The One-Click Audit (The "Deliverable")
*Current Status:* Data exists in SQLite but is trapped there.
*   **Task 4.1:** **Audit View**. Create a simple HTML table view that lists all transactions.
*   **Task 4.2:** **Conciliation Check**. Show a summary: `Total In (Fiat) == Total Out (Crypto) + Fees`.

---

## 3. Detailed Runbook for Next Session

### Step 1: Ignite the System
```bash
# Terminal 1: The Brain
bun run mcp/src/listener.ts

# Terminal 2: The Face
bun run hub/index.ts
```

### Step 2: Implement "Live Polling" in Hub
*   **File:** `hub/hub.ts`
*   **Action:** Modify `refreshObservabilityPanel` to poll `/history` from the Listener every 3s.
*   **Goal:** Watch the feed populate automatically as we use the CLI tools.

### Step 3: Implement the "Compliance Mock"
*   **File:** `sdk/src/economy/payment_router.ts`
*   **Action:** Add a check `if (recipient === 'SANCTIONED_ADDRESS') throw new Error('Range: Risk High')`.
*   **Test:** Try to pay this address from the UI and verify the Red Alert.

### Step 4: UI Polish ("The Privacy Toggle")
*   **File:** `hub/hub.ts` (renderReceipts function)
*   **Action:** If `receipt.type === 'private'`, mask the text. Add a `[️]` button that unmasks it locally.

### Step 5: The Demo Recording Script (3 Minutes)
1.  **Intro (30s):** "Agents are the future, but they leak data. Meet xb77."
2.  **The Happy Path (1m):** Agent buys "AWS Credits" via Privacy Cash. Show the "Shielding" animation. Show the text masked in the feed. Reveal it with the key.
3.  **The Compliance Guard (45s):** Agent tries to send funds to a "Hacker". System blocks it. "Safe by Design."
4.  **The Audit (45s):** "Your accountant is happy." Show the conciliation table.
5.  **Outro:** "Built on Solana. Powered by Light Protocol."

---

## 4. Required Assets
- [ ] **Range Protocol Logo** (for the UI Alert).
- [ ] **Light Protocol Logo** (for the Privacy Shield icon).
- [ ] **Starpay Logo** (Mocked, for the Virtual Card).

## 5. Success Metrics
- **The "Pulse":** Does the UI update without touching it?
- **The "Block":** Does the red error box appear on the bad tx?
- **The "Reveal":** Can we click to see the hidden data?

*Ready to execute on next login.*

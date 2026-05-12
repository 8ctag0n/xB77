---
pageClass: is-legacy-page
---
#  xB77 Demo Script: "The Sovereign Agent"

**Target Duration:** 3 Minutes
**Goal:** Showcase Privacy, Compliance, and Autonomy.

## Scene 0: Setup (Pre-Record)
1.  **Clean State:** Delete `xb77_agent.db` (or `/tmp/...` if shared).
2.  **Start Services:**
    *   Terminal 1: `bun run mcp/src/listener.ts`
    *   Terminal 2: `bun run mcp/src/http.ts` (Ensure `XB77_KEYPAIR_PATH` is set)
    *   Terminal 3: `bun hub/index.ts`
3.  **Open Browser:** `http://localhost:7777`.
4.  **Connect Agent:** Go to "Control Plane", click "Refresh". Ensure Agent is **Online** and shows the **Noir Badge** (️ Identity Verified).

---

## Scene 1: The "Happy Path" (Standard Privacy)
**Narrator:** "Agents need to spend money, but public blockchains leak their entire history. xB77 gives them privacy by default."

**Action:**
1.  Go to **Terminal** tab.
2.  Click **"Buy Now"** on **AWS Credits ($95)**.
3.  **Look at Feed:**
    *   See `🤖 Analyzing optimal route...`
    *   See `️ Standard Privacy...`
    *   See `Payment Confirmed`.
4.  **The Reveal:** Click the **Lock Icon ()** on the feed item.
    *   Show that the amount was hidden (`*******`) and is now revealed locally.

## Scene 2: The Compliance Guard (Range Protocol)
**Narrator:** "But privacy can't be a tool for crime. We integrate Range Protocol to block sanctions in real-time."

**Action:**
1.  Click **"Buy Now"** on **Dark Web Data ($499)**.
2.  **Look at Screen:**
    *   **RED ALERT MODAL** appears immediately.
    *   "Risk Alert: Range Protocol".
    *   "Reason: Sanctioned Address".
3.  Click "Acknowledge". Transaction cancelled.

## Scene 3: The Unicorn Feature (Ghost Mode & Governance)
**Narrator:** "For high-value assets, the Agent switches to 'Ghost Mode' and requests human authorization via our Shadow Governance Protocol."

**Action:**
1.  Click **"Buy Now"** on **Quantum Farm ($50,000)**.
2.  **Alert:** "High Value Alert". Click **OK**.
3.  **Feed:** ` GHOST MODE ACTIVATED`.
4.  **Feed:** `️ Blocked... Requesting approval...`.
5.  **Switch Tab:** Go to **Governance**.
6.  **Action:**
    *   See "Encrypted Intent" (Lock icon).
    *   Click **"Decrypt & Inspect"**.
    *   Read details: "Asset Acquisition: Quantum Farm".
    *   Click **"Sign & Approve"**.
7.  **Switch Tab:** Go back to **Terminal**.
8.  **Wait 3s:** Watch the feed automatically update.
    *   `Agent Resuming...`
    *   `Payment Confirmed`.

## Scene 4: The Invoicing (Accounting)
**Narrator:** "Finally, privacy shouldn't break accounting. We reconstruct tax-compliant invoices from encrypted on-chain metadata."

**Action:**
1.  Find the $50,000 transaction in the feed.
2.  Click the **" Invoice"** button.
3.  **Modal Opens:** Show the detailed receipt with VAT breakdown.
4.  **Narrator:** "The Sovereign Bank for the Machine Economy."

**END RECORDING**

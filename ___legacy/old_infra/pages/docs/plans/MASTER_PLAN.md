# 🦅 xB77: MASTER PLAN & STRATEGY
> **Target:** Solana Privacy Hackathon (Deadline: Feb 1, 2026)
> **Mission:** "The Operating System for the Shadow Economy of AI Agents."
> **Current Date:** Jan 20, 2026. **Days Remaining:** 12.

---

## 🗺️ THE MAP (Architecture)
We are building a "Privacy Triad" to solve the Agent Economy's exposure problem.

### 1. THE VAULT (Worktree A - "Privacy Cash")
*   **Role:** Holds the money (Confidential Treasury).
*   **Tech:** **Arcium C-SPL** (Confidential Token Standard).
*   **Asset:** **USD1** (Privacy Cash) or USDC-Confidential.
*   **Key Feature:** "Shadow Balance". The CFO sees $1M, the public sees `encrypted_blob`.

### 2. THE BLACK BOX (Worktree B - "Light Protocol")
*   **Role:** Holds the history (Audit Trail).
*   **Tech:** **Light Protocol (ZK Compression)**.
*   **Asset:** **Compressed PDAs** (Receipts).
*   **Key Feature:** "Ghost Receipts". Every spend creates a permanent, compressed, encrypted record of *what* was bought, without leaking it on-chain.

### 3. THE GHOST BADGE (Root - "Identity")
*   **Role:** Authorizes the spender.
*   **Tech:** **Noir (Aztec)** on Solana.
*   **Key Feature:** "Proof of Authority". An agent proves it belongs to the Company Merkle Tree without revealing *which* agent it is.

---

## ⚡ EXECUTION STRATEGY (Divide & Conquer)

We are splitting the codebase into focused Worktrees to bypass infrastructure blockers.

| Component | Owner | Status | Blocker | Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Root (Noir)** | Main | 🟢 Ready | None | Compile Circuits & Generate Verifier. |
| **Worktree A** | Privacy | 🟡 Pending | Arcium Localnet | **Use Devnet directly.** Skip local docker if unstable. |
| **Worktree B** | Light | 🔴 Blocked | Local Validator | **Switch to Devnet / Mocking.** Develop contracts against mocked interfaces first. |

---

## 📅 THE 10-DAY SPRINT

### Days 1-3: The Foundation (Jan 20 - Jan 22)
*   **Root:** Finalize `agent_badge` circuit (Noir) and generate Solidity/Solana verifier.
*   **Tree A:** Deploy a basic C-SPL token on Arcium Devnet. Mint "Shadow USD".
*   **Tree B:** Finish `xb77_gateway` logic (Rust). Implement the "Receipt" struct in Light SDK. **Ignore local validator issues; use Devnet for deployment.**

### Days 4-6: The Integration (Jan 23 - Jan 25)
*   **Gateway:** Connect Noir Verifier -> Arcium Transfer.
*   **Receipts:** Gateway -> emits Compressed Receipt (Light).
*   **SDK:** Create `@xb77/sdk` to abstract all this complexity for the frontend.

### Days 7-9: The Interface (Jan 26 - Jan 28)
*   **UI:** Build the "Shadow Console" (Terminal style).
    *   View 1: **CFO Mode** (Decrypts everything).
    *   View 2: **Auditor Mode** (Verifies proofs).
*   **Agent:** Create a simple CLI agent that "buys" an API key using the system.

### Days 10-12: Polish & Demo (Jan 29 - Feb 1)
*   **Video:** Record the "Cinematic" demo.
*   **Docs:** Finalize `README.md` and submission forms.
*   **Submit:** Win.

---

## 🛠️ CONTINGENCY PLANS
*   **If Arcium fails:** Fallback to standard SPL Token with a "Mixer" pattern (less cool, but functional).
*   **If Light Validator fails:** Use **Devnet** exclusively. If Devnet is unstable, Mock the compression (store encrypted data in standard accounts) but keep the *interface* compatible.
*   **If Noir Verifier fails:** Use a simple Merkle Proof verification in Rust (standard) instead of ZK-Circuit.

---

## 🚀 NEXT IMMEDIATE ACTION
Check `docs/plans/WORKTREE_A_PRIVACY.md` and `docs/plans/WORKTREE_B_LIGHT.md` for specific tasks.

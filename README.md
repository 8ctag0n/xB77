# xB77: SOLANA PRIVACY HACKATHON MASTER PLAN
> **Objective:** SWEEP THE BOARD. Target $35k+ in prizes by integrating the "Privacy Triad".
> **Narrative:** "The Operating System for the Shadow Economy of AI Agents."

---

## 🏆 THE LOOT (TARGET PRIZES)
1.  **Grand Prize ($10,000):** Best overall project (Agent Infra Narrative).
2.  **Arcium Prize ($10,000):** Best use of C-SPL (Confidential Treasury).
3.  **Privacy Track ($15,000):** General privacy excellence (Noir Auth).
4.  **Light Protocol / Privacy Tooling:** Best use of ZK Compression (Private Audit Trail).
5.  **USD1 Bounty ($2,500):** Integration of Privacy Cash.
6.  **Helius Bounty:** Best use of RPC/DAS/Webhooks.

---

## 🏗 THE ARCHITECTURE: "THE PRIVACY TRIAD"

### 1. THE VAULT (ARCIUM C-SPL)
*   **Goal:** Hide the Money.
*   **Tech:** **Arcium Confidential Token Standard (C-SPL)**.
*   **Function:** The Corporate Treasury is a **C-SPL Account**.
    *   Funds (USD1/USDC) enter and become **Confidential**.
    *   The balance is encrypted. Only the CFO with the viewing key can see it.
    *   *Why this wins:* Real-world B2B use case for Arcium.

### 2. THE BLACK BOX (LIGHT PROTOCOL)
*   **Goal:** Hide the Data (History).
*   **Tech:** **Light Protocol (ZK Compression)**.
*   **Function:** Every transaction generates a "Ghost Receipt".
    *   We store the encrypted invoice details (Vendor, Item, Amount) in a **Compressed PDA**.
    *   Cost is near zero. Privacy is absolute.
    *   *Why this wins:* Solves the "Audit vs. Privacy" dilemma using ZK Compression.

### 3. THE GHOST BADGE (NOIR)
*   **Goal:** Hide the Actor (Identity).
*   **Tech:** **Noir (Aztec) Circuits**.
*   **Function:** The Agent proves "I am Authorized" without revealing its Public Key.
    *   Circuit: `verify_membership(merkle_root, private_key)`.
    *   *Why this wins:* Standard ZK identity, executed perfectly.

---

## ⚡ INFRASTRUCTURE RAILS
*   **Settlement:** **USD1** (Privacy Cash) is the native unit of account.
*   **Speed:** **Helius** Priority Fees ensure agents never get stuck.
*   **Events:** **Helius Webhooks** trigger the "Audit" indexing when a C-SPL transfer occurs.

---

## 📅 EXECUTION PLAN (7-DAY SPRINT)

### PHASE 1: THE CORE (Days 1-2)
*   [ ] **Scaffold:** Repo setup (DONE).
*   [ ] **Noir:** Implement `agent_badge.nr` in `./circuits`.
*   [ ] **Arcium:** Setup local devnet with C-SPL support (Docker).

### PHASE 2: THE INTEGRATION (Days 3-5)
*   [ ] **The Gateway:** Connect Noir Verifier -> Arcium C-SPL Transfer in `./contracts`.
    *   *Logic:* If Proof Valid -> Execute Confidential Transfer.
*   [ ] **Light SDK:** Implement `@xb77/audit` in `./sdk` to write compressed receipts.
*   [ ] **Agent SDK & "God Level" Tooling:** 
    *   `@xb77/client` (Typescript SDK) in `./sdk`.
    *   **MCP Server (Model Context Protocol):** Enabling LLMs (Claude/GPT) to see private balances.
    *   **LangChain Tool:** "Plug & Play" private payments for any AI Agent.

### PHASE 3: THE UI & POLISH (Days 6-7)
*   [ ] **Shadow Console:** Terminal UI for the CFO (Decrypt Balances & History) in `./web`.
*   [ ] **Demo Video:** A cinematic walkthrough of an Agent buying intel privately.

---

## 🚀 IMMEDIATE NEXT STEPS
1.  **Initialize Noir:** `./circuits`.
2.  **Initialize SDK:** `./sdk`.
3.  **Check Arcium Docs:** Verify C-SPL devnet availability.

## 🧪 LOCALNET TOOLING
Common helpers:
- `make localnet-start` (run Solana local validator)
- `make localnet-verifier` (build + deploy Sunspot verifier to localnet)
- `make localnet-gateway` (build + deploy gateway program)
- `make proof-badge` (generate proof + instruction data)
- `make localnet-init` (initialize gateway with verifier + root)
- `make localnet-verify` (send verify_badge with proof)

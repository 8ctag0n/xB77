# Solana Frontier Hackathon: "xB77 Sovereign Commerce" Demo Script

**Target Duration:** 3 minutes
**Goal:** Show xB77 as a fully autonomous, ZK-verified financial OS on Solana.

---

## Phase 1: The Sovereign Setup (0:00 - 0:45)

**Visual:** Split screen. Left: Terminal. Right: Browser showing a blank page (Gateway not started).

**Speaker (You):** 
> "Welcome to xB77. Today, setting up on-chain commerce means relying on SaaS platforms that hold your keys and data. We built xB77 to be different: a Sovereign Financial OS powered by Zig, Solana, and Zero-Knowledge proofs."

**Action (Terminal):**
Run the Gateway in the background:
```bash
zig build run -- gateway &
```

Run the interactive setup:
```bash
./zig-out/bin/xb77 merchant setup-shop
```
*(Type in the prompts live)*
- **Business Name:** Neo Tokyo Imports
- **Primary Service Name:** Neural Implant Consult
- **Price:** 50000000 *(0.05 SOL)*
- **Claim your .xb77 handle:** neotokyo

**Speaker:**
> "With a single command, we generate an AES-GCM encrypted Vault, claim a decentralized identity on our edge network, and deploy a WASM-powered merchant gateway. No cloud servers required."

**Action (Browser):**
Refresh `http://localhost:8080/p/neotokyo` (or the gateway URL).
Show the "Cyber-Audit" dashboard. Point out the Blink link and Sovereign status.

---

## Phase 2: MagicBlock & AI Reasoning (0:45 - 1:45)

**Speaker:**
> "Let's simulate a customer paying for this service via a Solana Blink."

**Action (Terminal):**
In a new tab, run the transaction simulator (or trigger a real devnet tx):
```bash
# Simulate a payment event hitting the Z-Node
export YELLOWSTONE_ENDPOINT="mock"
./zig-out/bin/xb77 agent run --profile default
```

**Speaker:**
> "Under the hood, our Z-Node listens to Solana via gRPC. When the payment hits, our local Gemma 4 AI model evaluates the transaction against our constitutional RAG rules. Since the volume is high, the Engine automatically routes the settlement via MagicBlock's Ephemeral Rollup—the HFT rail for Solana—achieving sub-millisecond finality."

*(Show the terminal logs where `[BRAIN ] Consulting Gemma 4...` and `[ENGINE] Routing via MagicBlock...` appear).*

---

## Phase 3: The Ghost Receipt & ZK Judge (1:45 - 3:00)

**Speaker:**
> "But how do we prove to auditors that the agent collected the correct infrastructure tax, without leaking the customer's identity or the exact amount? Enter the Ghost Receipt."

**Action (Terminal):**
Show the Prover logs in the terminal generating the ZK Proof.
Copy the `Commitment Hash` and the `Viewing Key` JSON generated in the terminal output.

**Action (Browser):**
Go to the **ZK-Receipt Verification Portal** at the bottom of the Gateway page.
1. Paste the `Commitment Hash` (e.g., `0xabc123...`).
2. Paste the `Viewing Key` (e.g., `{"amount":50000000,"tax_paid":1005500,"recipient_pubkey":"0x..."}`).
3. Click **VERIFY PROOF**.

**Speaker:**
> "The agent generated a Noir ZK-proof and anchored the Merkle root on-chain. Here, the auditor uses the Gateway's local WASM verifier. By providing the Viewing Key, they mathematically verify the ZK-Proof directly in the browser."

*(The screen flashes GREEN: ✅ PROOF VALID (GHOST RECEIPT) and decrypts the data).*

**Speaker:**
> "The Ghost Receipt proves the 2.011% tax was paid on-chain, while the transaction details remain completely private. xB77: True sovereignty for the agentic economy. Thank you."

---

## Behind the Scenes Tech Stack (For the Devpost submission)
- **Zig:** Core engine, Z-Node gRPC stream, WASM Gateway.
- **Rust/Anchor:** The on-chain ZK Judge (`xb77_core`).
- **Noir:** Plonk ZK-circuit for the Ghost Receipt.
- **MagicBlock:** Ephemeral Rollup integration for HFT routing.
- **Solana Actions/Blinks:** The customer-facing UI.
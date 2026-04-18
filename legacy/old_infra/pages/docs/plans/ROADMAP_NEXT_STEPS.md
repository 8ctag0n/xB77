# Roadmap: Next Steps (Jan 20 - Feb 1)

## Strategic Shift: Devnet-First
Due to persistent instability with the local Light Protocol validator environment (specifically dependency downloads), development will shift strategy:
1.  **Local Logic Validation:** Unit tests for Rust contracts (Gateway/Receipts) will run locally without the full validator stack where possible.
2.  **Devnet Deployment:** Integration testing will move directly to Solana Devnet using public RPCs (Helius/Light) to bypass local infrastructure issues.

## 1. Core Logic Refinement (Days 1-3)
**Goal:** Solidify the Rust contracts so they are ready for Devnet.

### Gateway Program (xb77_gateway)
- [ ] **Instruction hardening:** Ensure `verify_badge` and `submit_private_order` validate inputs strictly.
- [ ] **State Management:** Finalize the PDA structure for `GatewayState` and `OrderState`.
- [ ] **Unit Tests:** Write Rust unit tests (`cargo test`) to verify logic isolated from the chain.

### Receipts Program (xb77_receipts)
- [ ] **Compression Logic:** Implement the CPI call to Light Protocol's system program (even if mocked locally).
- [ ] **Structure:** Define the `CompressedReceipt` struct (Vendor, Item, Amount, Hash) clearly in Rust.

## 2. SDK Development (Days 3-5)
**Goal:** Build the client-side bridge (`@xb77/sdk`) to interact with the programs.

### Identity Module
- [ ] Wrap Noir proof generation (`generate_badge_proof.ts`) into a clean SDK method: `sdk.identity.prove()`.

### Payment Module (Worktree A)
- [ ] Integrate Arcium/USD1 SDK headers.
- [ ] Implement `sdk.payment.transfer_private(amount, recipient)`.

### Audit Module (Worktree B)
- [ ] Implement `sdk.audit.fetch_receipts()` using Light Protocol's DAS (Data Availability Service) API.
- [ ] Implement `sdk.audit.verify_receipt(hash)`.

## 3. Devnet Integration (Days 5-8)
**Goal:** Connect the pieces on the live test network.

- [ ] **Deploy Gateway:** Deploy `xb77_gateway` to Devnet.
- [ ] **Config:** Initialize Gateway with the Devnet Verifier address.
- [ ] **End-to-End Test:** Run a script that:
    1. Generates a Noir Proof.
    2. Submits it to the Devnet Gateway.
    3. Gateway validates and triggers a "Mock Transfer" (or real if Arcium is ready).
    4. Gateway emits a "Mock Receipt" (or real compressed if Light Devnet is stable).

## 4. UI & Demo Polish (Days 9-10)
**Goal:** Visuals for the Hackathon submission.

- [ ] **CLI Dashboard:** A simple terminal UI showing "Private Balance" vs "Public View".
- [ ] **Demo Video:** Record the flow: "Agent generates proof -> Gateway accepts -> Private Transfer happens".

## Contingencies
- **If Light Devnet fails:** We will store "Encrypted Logs" in standard Solana accounts as a fallback for the receipts, preserving the privacy narrative even if compression is mocked.
- **If Arcium Devnet fails:** We will use a standard SPL Token Transfer with a "Mixer" pattern (simulated privacy) for the demo.

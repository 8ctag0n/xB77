# Execution Plan: Noir ZK Integration
**Branch:** `branch-noir-integration`
**Parent:** `branch-core-program`

## Objective
Replace the mock verification in `xb77_gateway` with real Noir proof verification using the `agent_badge` circuit.

## Scope
1.  **Circuit Finalization**:
    *   Finalize `circuits/agent_badge/src/main.nr` to assert valid credit credentials.
    *   Compile circuit and generate Verifier Contract (or Rust Verifier logic).
2.  **Gateway Integration (`xb77_gateway`)**:
    *   Import Noir Verifier library/logic.
    *   Update `VerifyBadge` instruction to accept real proof bytes.
    *   Implement strict verification logic (replacing the `[1, 2, 3]` mock check).
3.  **SDK Update**:
    *   Update `generate_badge_proof.ts` to produce real proofs using `noir_js`.
    *   Update `demo_e2e.ts` to use real proofs in the transaction.

## Dependencies
*   Noir toolchain (`nargo`).
*   `xb77_gateway` (existing).

## Deliverables
*   Verified Noir circuit.
*   Hardened `xb77_gateway` rejecting invalid proofs.
*   Client-side proof generation script integrated.

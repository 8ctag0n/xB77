# Execution Plan: Noir ZK Integration
**Branch:** `branch-noir-integration`
**Parent:** `branch-core-program`
**Last Updated:** 2026-01-20

## Objective
Replace the mock verification in `xb77_gateway` with real Noir proof verification using the `agent_badge` circuit.

## Current Status (In Progress)
*   **Circuit**: `agent_badge` compiles and setup is complete (pk/vk generated).
*   **Sunspot Fix**: Pinned Sunspot to commit `7edafaf` to resolve "unexpected EOF" compatibility issue with `nargo 1.0.0-beta.13`.
*   **Verifier Code**: Created `scripts/vk-gen` tool to generate `badge_vk.rs` directly from the `.vk` file, bypassing `sunspot deploy` issues.
*   **Integration**: `badge_vk.rs` is now present in `xb77_gateway/src`.

## Completed Steps
1.  **Debug Sunspot Artifact Reading**: Solved by pinning Sunspot commit.
2.  **Pin Sunspot Version**: Done in `containers/sunspot/Containerfile`.
3.  **Alternative Path (Custom VK Gen)**: Implemented `scripts/vk-gen` and `scripts/generate-vk-rust.sh`.

## Next Session Strategy
1.  **Gateway Integration (`xb77_gateway`)**:
    *   Add `verifier-lib` (pinned commit) to `xb77_gateway/Cargo.toml`.
    *   Implement `verify_proof` logic in `processor.rs` using `badge_vk.rs`.
2.  **SDK Proof Generation**:
    *   Continue setting up `sdk/scripts/generate_badge_proof.ts`.

## Scope
1.  **Circuit Finalization** (Done):
    *   `circuits/agent_badge/src/main.nr` is ready.
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
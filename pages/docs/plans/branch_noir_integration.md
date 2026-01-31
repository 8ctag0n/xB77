# Execution Plan: Noir ZK Integration
**Branch:** `branch-noir-integration`
**Parent:** `branch-core-program`
**Last Updated:** 2026-01-21

## Objective
Replace the mock verification in `xb77_gateway` with real Noir proof verification using the `agent_badge` circuit.

## Strategy: Architecture Separation (Implemented)
To resolve severe dependency conflicts (Rust 2024 requirements in `blake3`/`verifier-lib` vs legacy Solana SBF toolchain), we have separated concerns:

1.  **Standalone Verifier Program (`verifier_program`)**:
    *   Contains the heavy ZK logic (`verifier-lib`, `arkworks`).
    *   Compiles in a dedicated Docker container (`xb77-solana-builder`) with modern Rust/Solana toolchain.
    *   Exposes a simple instruction interface to verify proofs.
2.  **Gateway Program (`xb77_gateway`)**:
    *   Remains lightweight and compatible with standard SBF build.
    *   Invokes `verifier_program` via CPI to verify proofs.
    *   Passes `[proof_len | proof | witness]` to the verifier.

## Current Status (Success)
*   **Circuit**: Complete.
*   **Verifier Program**: Implemented and compiling in Docker.
*   **Gateway**: Cleaned up and compiling locally. Calls Verifier via CPI.
*   **Tooling**: `scripts/build-verifier-docker.sh` and `containers/builder` created.

## Next Steps
1.  **Deploy & Init**: Run full deployment sequence on localnet.
2.  **Demo**: Verify end-to-end flow with `demo-private-order.sh`.
3.  **Documentation**: Update README with the new architecture instructions.

## Deliverables
*   `verifier_program.so` (Docker build).
*   `xb77_gateway.so` (Local build).
*   Integrated `verify_badge` flow via CPI.

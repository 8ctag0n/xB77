# Execution Plan: Receipts & CPI Integration
**Branch:** `branch-receipts-cpi`
**Parent:** `branch-core-program`

## Objective
Implement the `xb77_receipts` program utilizing Light Protocol (ZK Compression) for scalable receipt storage, and connect it to `xb77_core` via CPI.

## Scope
1.  **Receipts Program (`xb77_receipts`)**:
    *   Implement `InitReceipts` instruction.
    *   Implement `RecordReceipt` instruction (hashing + Merkle tree update).
    *   Integrate Light Protocol SDK/CPI logic for compressed state (state trees).
2.  **Core Integration (`xb77_core`)**:
    *   Update `RequestPayment` to CPI into `xb77_receipts::RecordReceipt`.
    *   Ensure atomic execution: Payment deduction + Receipt generation.
3.  **SDK Update**:
    *   Update `demo_e2e.ts` to verify the receipt was created (listen for logs or query compressed state).

## Dependencies
*   Light Protocol binaries (already in `containers/surfpool/bin`).
*   `xb77_core` (existing).

## Deliverables
*   Functional `xb77_receipts` program.
*   Updated `xb77_core` with CPI to receipts.
*   E2E test verifying receipt generation.

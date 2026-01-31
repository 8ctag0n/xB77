# Execution Plan: Receipts & CPI Integration
**Branch:** `branch-receipts-cpi`
**Parent:** `branch-core-program`

## Objective
Implement the `xb77_receipts` program utilizing Light Protocol (ZK Compression) for scalable receipt storage, and connect it to `xb77_core` via CPI.

## Scope
1.  **Receipts Program (`xb77_receipts`)**:
    *   [x] Implement `InitReceipts` instruction (Replaced by `RecordReceipt` atomic init).
    *   [x] Implement `RecordReceipt` instruction (hashing + Merkle tree update).
    *   [x] Integrate Light Protocol SDK/CPI logic for compressed state (state trees).
2.  **Core Integration (`xb77_core`)**:
    *   [x] Update `RequestPayment` to CPI into `xb77_receipts::RecordReceipt`.
    *   [x] Ensure atomic execution: Payment deduction + Receipt generation.
3.  **SDK Update**:
    *   [x] Update `demo_e2e.ts` to verify the receipt was created (listen for logs or query compressed state).

## Dependencies
*   Light Protocol binaries (already in `containers/light/bin`; surfpool container is now unused).
*   `xb77_core` (existing).

## Deliverables
*   [x] Functional `xb77_receipts` program.
*   [x] Updated `xb77_core` with CPI to receipts.
*   [x] E2E test verifying receipt generation.

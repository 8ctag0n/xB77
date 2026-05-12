---
pageClass: is-legacy-page
---
# Track C: Infrastructure, Observability & Receipts
**Branch Name:** `feat/infra-receipts-listener`
**Base Branch:** `base-integration` (Consolidated)

## 1. Objective
To build the "All-Seeing Eye" (Backend) that makes sense of the fragmented privacy activities. It acts as the unifying indexer that listens to On-Chain events (ShadowWire, SilentSwap, Privacy Cash) and Off-Chain Webhooks (Starpay) to produce a coherent audit trail and generate Compressed Receipts.

## 2. Core Components

### 2.1. The Unified Listener (MCP Server)
The central backend service.
*   **Path:** `mcp/src/listener.ts`
*   **Helius Integration:** Uses Helius Webhooks/DAS to detect on-chain transfers.
*   **Starpay Webhooks:** An Express/Fastify route to receive card transaction payloads.
*   **Logic:** Normalizes all events into a standard `TransactionEvent` format.

### 2.2. The Receipt Issuer (Light Protocol)
*   **Path:** `onchain/programs/xb77_receipts/`
*   **Task:** When the Listener confirms a payment (from ANY source), it invokes this program via CPI (or direct tx) to mint a **Compressed Receipt**.
*   **Importance:** This unifies the accounting. A fiat payment via Starpay creates a ZK-compressed receipt on Solana just like a native transfer.

### 2.3. Observability (Helius)
*   **Dashboard:** Configure Helius to tag and monitor the specific addresses of our Stubs and Registry.
*   **Alerts:** Set up notifications for high-value transfers (simulation of Range compliance alerts).

## 3. Integration Points

### Input from Track A & B
*   Tracks A & B generate the noise (txs). Track C listens.
*   **Compliance Hook (Range):** If implemented, this Track exposes an API endpoint `/check-compliance` that Track A calls before executing a tx.

### Output to Track B (Hub)
*   **Unified History API:** Exposes `GET /history` returning a mixed list of Crypto and Fiat operations.
*   **WebSocket:** Pushes updates to the Hub UI.

## 4. Execution Plan
- [x] **Receipts Program:** Finish `xb77_receipts` (Record Receipt instruction).
- [x] **Helius Setup:** Config script for Webhooks (`scripts/infra/setup_helius.ts`).
- [x] **Unified Listener:** Implement HTTP endpoint for card events and Helius (`mcp/src/listener.ts`).
- [x] **Normalization Logic:** "If Starpay Event -> Create Compressed Receipt".
- [x] **Persistence:** Added `SQLiteReceiptStore` (Native Bun SQLite) for offline/local history.
- [ ] **History API:** Simple endpoint for the Hub (Partially covered by `agent.receipts.list` tool).

## 5. Status Update (2026-01-23)
- **Completed:**
    - `xb77_receipts` program implemented with Light Protocol CPI.
    - `mcp/src/listener.ts` service running on port 7002.
    - Webhook handling for Starpay and Helius.
    - **SQLite Persistence**: Replaced in-memory store with `bun:sqlite` (`xb77_agent.db`).
- **Next Steps:**
    - Integrate WebSocket for real-time Hub updates.
    - Add signature verification for production security.

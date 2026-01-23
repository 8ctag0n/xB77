# Track A: Agent Core & Payment Strategies
**Branch Name:** `feat/agent-payments-core`
**Base Branch:** `base-integration` (Consolidated)

## 1. Objective
To implement the "Autonomous CFO" logic within the SDK. This goes beyond simple transfers; it builds a decision engine that enables the Agent to execute financial operations across three domains: **Local** (Solana Privacy), **Global** (Cross-Chain via SilentSwap), and **Real World** (Fiat via Starpay).

## 2. Core Components

### 2.1. The Payment Routing Engine
The central brain that accepts a high-level intent (e.g., "Pay AWS Bill", "Send funds to Base", "Pay Secret Agent") and selects the optimal rail.
*   **Path:** `sdk/src/economy/cfo_router.ts`
*   **Logic:** Evaluates availability, cost, and privacy requirements to route the transaction.

### 2.2. Strategy Interface & Adapters
We define a unified interface `PaymentStrategy` implemented by four distinct adapters:

#### A. Local Privacy Rail (Solana)
1.  **ShadowWire Adapter (Stubbed for now):**
    *   **Purpose:** Peer-to-Peer confidential transfers using Bulletproofs logic (simulated via Stub).
    *   **Component:** `ShadowWireAdapter` calling `onchain/programs/shadowwire_stub`.
2.  **Privacy Cash Adapter:**
    *   **Purpose:** High-frequency private state using Light Protocol (ZK Compression).
    *   **Component:** Refined `PrivacyCashAdapter` using Light SDK.

#### B. Global Mobility Rail (Cross-Chain)
3.  **SilentSwap Adapter:**
    *   **Purpose:** To enable "Identity Hopping" and cross-chain transfers (e.g., Solana -> Ethereum/Base).
    *   **Implementation:** An adapter that constructs the intent for a SilentSwap route.
    *   **Data Structure:** `CrossChainIntent { targetChain: 'ETH', token: 'USDC', obfuscationLevel: 'HIGH' }`.

#### C. Real-World Rail (Fiat Bridge)
4.  **Starpay Adapter:**
    *   **Purpose:** Instant issuance of Virtual Cards for Web2 payments (AWS, API keys).
    *   **Implementation:** HTTP Client integration with Starpay API.
    *   **Functions:** `createVirtualCard(amount)`, `topUpCard(cardId, amount)`.
    *   **Flow:** Agent locks Crypto -> Starpay issues Card Details -> Agent receives `PAN/CVV` (encrypted).

### 2.3. On-Chain Dependencies
*   **ShadowWire Stub:** We still need to deploy this to simulate the local rail transaction.
*   **SilentSwap Stub (Optional):** A mock program to simulate the "Exit" event on Solana if the real contract isn't available on localnet.

## 3. Integration Points (Context for other Tracks)

### Output to Track C (Infra Listener)
*   **Starpay Webhooks:** Track C must set up an HTTP endpoint to receive "Card Transaction" events from Starpay (simulated or real).
*   **On-Chain Events:** Track C must listen for `ShadowWire` and `SilentSwap` exit events to index them for the dashboard.

### Input for Track B (Merchant Hub)
*   **Capabilities API:** The Hub UI needs to know *what* the Agent can do.
*   **Method:** `agent.getCapabilities()` returns `{ starpay: true, silentSwap: true, shadowWire: true }`.
*   **Starpay UI:** Track B will need a UI component to display the generated Virtual Card (masked).

## 4. Execution Plan
1.  **Interface Definition:** Define `PaymentStrategy` and the `AutonomousCFO` class.
2.  **Starpay Integration:** Implement the REST API client for card issuance.
3.  **SilentSwap Logic:** Implement the intent construction for cross-chain swaps.
4.  **Local Rails:** Implement ShadowWire Stub (Rust) and Privacy Cash (SDK).
5.  **The Router:** Write the logic that allows `agent.pay()` to automatically pick the right adapter.

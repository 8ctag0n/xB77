---
pageClass: is-legacy-page
---
# Track A: Agent Core & Payment Strategies
**Branch Name:** `feat/agent-payments-core`
**Base Branch:** `base-integration` (Consolidated)

## 1. Objective
To implement the "Autonomous CFO" logic within the SDK, transforming the Agent from a simple spender into a **Liquidity Manager** that bridges the corporate fiat world (Starpay) with the private crypto economy (ShadowWire/PrivacyCash).

**Key Concept:** The Agent synchronizes treasury from Starpay (The Corporate Source) to `xb77_core` (The On-Chain Balance), enabling seamless operation.

## 2. Core Components

### 2.1. The Liquidity Manager (New!)
The bridge between Fiat Treasury and Crypto Execution.
*   **Path:** `sdk/src/economy/liquidity_manager.ts`
*   **Logic:**
    1.  **Poll Starpay:** Check corporate card limits/balance allocated by the human operator.
    2.  **Poll On-Chain:** Check `xb77_core` program state for current operational capital.
    3.  **Rebalance:** If On-Chain funds are low but Starpay has credit, initiate a Top-Up (mocked swap or bridge flow) to move value into the Private System.

### 2.2. The Payment Routing Engine (Brain)
*   **Path:** `sdk/src/economy/payment_router.ts`
*   **Safety Layer (Range):** Before any move, consult Range API. *"Is this destination safe?"*
*   **Routing Logic:**
    *   **Internal:** Use **Privacy Cash** (Light) or **ShadowWire** for Agent-to-Agent payments.
    *   **External:** Use **Starpay** Virtual Card for Web2 payments.
    *   **Escape:** Use **SilentSwap** to exit to other chains if Solana is congested or compromised.

### 2.3. Adapters (Toolkit)
*   **StarpayAdapter:** Read-Write. Reads balance (Funding) AND Issues cards (Spending).
*   **PrivacyCashAdapter:** Interface to `privacy-cash-sdk`.
*   **ShadowWireAdapter:** Interface to ShadowWire SDK.
*   **RangeAdapter:** Interface to Range Compliance API.

### 2.4. MCP Integration (Active Tools)
*   `cfo_check_treasury`: Returns combined balance (Fiat + Crypto).
*   `cfo_rebalance`: Moves funds from Starpay -> Crypto.
*   `cfo_pay`: Smart routing based on intent.

## 3. Integration with Existing Programs

### Link to `xb77_core`
*   This track's SDK interacts directly with the `xb77_core` program.
*   When rebalancing, the SDK calls an instruction on `xb77_core` (e.g., `deposit_liquidity`) to reflect the new funds available for the agent's logic.

### Link to `xb77_gateway`
*   The Agent uses its **Noir Proof** (`agent_badge`) to authenticate against the Starpay Adapter (simulated auth) and the `xb77_core` program, proving it is the authorized entity to manage these funds.

## 4. Execution Plan
1.  **Interfaces:** Define `LiquiditySource` (Starpay) and `PrivacyRail` (ShadowWire/Light).
2.  **Starpay Integration:** Implement `StarpayAdapter` focusing on the "Get Balance" and "Fund" flows.
3.  **Core Link:** Update SDK to read/write to `xb77_core` state.
4.  **Range Integration:** Add the `validateAddress` check in the Router.
5.  **MCP Tools:** Expose `check_treasury` and `rebalance`.
# Privacy Agent SDK (`@xb77/sdk`)

The core TypeScript SDK for the **Private Agent OS**. 
It combines **Identity** (Noir/Badge) and **Economy** (ShadowWire/Privacy Cash) into a single, easy-to-use `PrivacyAgent` class.

## Features

- **Identity:** Generate and verify Zero-Knowledge proofs of authority (Badge).
- **Economy:** Execute private payments (USD1, SOL, USDC) using ShadowWire.
- **Privacy:** All transfers are shielded (internal) or semi-shielded (external).

## Usage

### 1. Installation

```bash
bun install
```

### 2. Privacy Agent (Payments)

The `PrivacyAgent` is the main entry point.

```typescript
import { PrivacyAgent, Keypair } from '@xb77/sdk';

// Initialize with your Solana Keypair
const agent = new PrivacyAgent({ 
  keypair: myKeypair,
  debug: true // Enable logs
});

// Check Balance (ShadowWire Pool by default)
const balance = await agent.getBalance('USD1');
console.log(`Private Balance: ${balance.available}`);

// Make a Payment
// 'internal' = Private Amount (Receiver must be in pool)
// 'external' = Public Amount, Anonymous Sender (Receiver can be anyone)
await agent.pay(
  'RECIPIENT_ADDRESS_BASE58', 
  100,      // Amount in USD1/SOL (not lamports)
  'USD1'    // Token
);
```

### 2b. Optional Adapters (C-SPL Balance + Receipts)

If you are implementing C-SPL balances or compressed receipts in another branch,
you can plug them into `PrivacyAgent` without changing the payment flow:

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: myKeypair,
  balanceProvider: myBalanceProvider, // C-SPL adapter
  receiptStore: myReceiptStore        // compressed receipts adapter
});
```

Stubs and helpers are available in `sdk/src/economy/adapters.ts` to speed up wiring.

### 3. Running the Demo

We have a built-in demo script that generates a random identity and attempts a payment:

```bash
bun run sdk/scripts/demo_payment.ts
```

---

## Noir Identity (Legacy Docs)

To run:

```bash
bun run index.ts
```

To validate the Noir proof pipeline (Node.js):

```bash
node test_badge.mjs
```

To generate Groth16 proofs and instruction data for on-chain verification:

```bash
# Uses the Noir + Sunspot container runtime.
bun run scripts/generate_badge_proof.ts
# or
bun run proof:badge
```

Outputs:
- `sdk/target/agent_badge.instruction.bin` (binary `proof || public_witness`)
- `sdk/target/agent_badge.instruction.b64` (base64 for transport)

To (re)generate the Noir artifact used by the scripts (via container):

```bash
./scripts/build-noir-artifacts.sh
```

Proof inputs live in `sdk/fixtures/agent_badge_inputs.json`.

First run downloads the CRS into `sdk/.bb-crs` and requires network access.

This project was created using `bun init` in bun v1.3.3. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.

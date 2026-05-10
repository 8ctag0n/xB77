# Privacy Agent SDK (`@xb77/sdk`)

The core TypeScript SDK for the **Private Agent OS**. 
It combines **Identity** (Noir/Badge) and **Economy** (ShadowWire/Privacy Cash) into a single, easy-to-use `PrivacyAgent` class.

## Features

- **Identity:** Generate and verify Zero-Knowledge proofs of authority (Badge).
- **Economy:** Execute private payments (USD1, SOL, USDC) using ShadowWire and Privacy Cash adapters.
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

// Make a Payment (mocked in localnet by default)
// 'internal' = Private Amount (Receiver must be in pool)
// 'external' = Public Amount, Anonymous Sender (Receiver can be anyone)
await agent.pay(
  'RECIPIENT_ADDRESS_BASE58', 
  100,      // Amount in USD1/SOL (not lamports)
  'USD1'    // Token
);
```

### 2c. Payment Providers (ShadowWire / Privacy Cash)

You can select a provider per call or set a default in the agent config:

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: myKeypair,
  paymentProvider: 'privacy_cash'
});

await agent.pay(
  'RECIPIENT_ADDRESS_BASE58',
  50,
  'USDC',
  'external',
  'privacy_cash'
);
```

Localnet uses deterministic mock adapters by default. You can override with a custom
`paymentGateway` if you want to wire live SDK clients later.

### 2d. Mock vs Live (Localnet)

- Default: mock adapters for ShadowWire + Privacy Cash.
- Live ShadowWire requires a `walletSigner` and network access; Privacy Cash remains mock in this branch.
- If you want a live gateway later, pass `paymentGatewayOptions` with `mode: 'live'`.

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: myKeypair,
  paymentGatewayOptions: {
    mode: 'live',
    shadowwire: { walletSigner: myWalletSigner }
  }
});
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

### 3b. Helius RPC Smoke Test

Use the infra smoke test to validate your Helius RPC + priority fee setup:

```bash
bun run sdk/scripts/helius_rpc_smoke.ts --airdrop-sol 1 --lamports 1
```

RPC defaults come from `XB77_RPC_URL` or `XB77_HELIUS_API_KEY`.

### 4. Testing

```bash
cd sdk
bun test
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

Proof inputs live in `sdk/fixtures/agent_badge_inputs.json` and include `orderId` plus optional `nullifier`.

First run downloads the CRS into `sdk/.bb-crs` and requires network access.

This project was created using `bun init` in bun v1.3.3. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.

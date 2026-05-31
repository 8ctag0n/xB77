# Arbitrum & ZeroDev Integration

xB77 agents on Arbitrum leverage **ZeroDev Kernel v3.1** and **Stylus** to enable intent-based, account-abstracted financial operations. This integration allows agents to operate with session keys, paymasters, and on-chain semantic validation of their actions.

## Overview

The integration consists of three main components:
1. **SovereignPolicy.sol**: An EVM contract that bridges ZeroDev Kernel v3 with Arbitrum Stylus.
2. **Semantic Intent Vectors**: 128-dimensional vectors representing the agent's intent, validated on-chain against a Constitution.
3. **TypeScript SDK**: A specialized wrapper to manage Agent Accounts and session keys.

## Setup

To use the Arbitrum SDK, you need a ZeroDev Project ID from the [ZeroDev Dashboard](https://dashboard.zerodev.app/).

### Installation

```bash
npm install @xb77/sdk viem @zerodev/sdk @zerodev/permissions
```

## Usage

### 1. Initialize the Agent Account

The `ArbitrumAgentAccount` requires a `zerodevProjectId` to communicate with the bundler and paymaster RPCs.

```typescript
import { ArbitrumAgentAccount } from "@xb77/sdk";
import { createPublicClient, http } from "viem";
import { arbitrumSepolia } from "viem/chains";

const publicClient = createPublicClient({
  chain: arbitrumSepolia,
  transport: http("https://sepolia-rollup.arbitrum.io/rpc"),
});

const ZERODEV_PROJECT_ID = "your-project-id-here";
const agentAccount = new ArbitrumAgentAccount(publicClient, ZERODEV_PROJECT_ID);
```

### 2. Create an Agent Client

An Agent Client is a specialized Smart Account Client that uses session keys and carries semantic policies.

```typescript
const OWNER_PRIVATE_KEY = "0x...";
const SESSION_PRIVATE_KEY = "0x...";
const SOVEREIGN_POLICY_ADDR = "0x..."; // Your deployed SovereignPolicy contract

// 128-dimension vector representing the intent
const intentVector = new Array(128).fill(100); 

const client = await agentAccount.createAgentClient(
  OWNER_PRIVATE_KEY,
  SESSION_PRIVATE_KEY,
  SOVEREIGN_POLICY_ADDR,
  intentVector
);
```

### 3. Execute Intent-Based Transactions

Once created, the client works like any `viem` smart account client. Every transaction will carry the `intentVector` to the `SovereignPolicy` contract for validation.

```typescript
const hash = await client.sendTransaction({
  to: "0x...",
  value: 0n,
  data: "0x...",
});

console.log(`Transaction submitted: ${hash}`);
```

## On-Chain Validation (Stylus)

When the transaction reaches the `SovereignPolicy` contract on-chain:
1. It extracts the `intentVector` from the User Operation.
2. It forwards the vector to a **Stylus-based Constitution** module.
3. The Stylus module calculates the similarity or compliance of the intent.
4. If the intent violates the constitution (e.g., "malicious" vector), the transaction is reverted.

## Session Keys & EIP-7715

xB77 uses ZeroDev's session key implementation, allowing agents to sign transactions without the owner's constant presence. These keys are scoped by the `intentVector`, ensuring the agent can only act within its predefined semantic boundaries.

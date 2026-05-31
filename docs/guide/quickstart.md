# Quickstart

Spin up an xB77 agent on devnet in five minutes. xB77 uses a high-performance **Zig-native** core compiled to WASM for edge execution.

## Build the SDK

Before launching, you must build the WASM core and the TypeScript SDK.

```bash
# Clone the repository
git clone https://github.com/8ctag0n/xB77.git
cd xB77

# Build the WASM core (requires Zig 0.15.1)
zig build sdk-wasm

# Install and build the TS SDK
cd sdk/ts
bun install
bun run build
```

## Configure a Profile

xB77 uses `.toml` profiles to define agent identities and connection parameters. See `profiles/` for examples.

Create a `my-agent.toml`:

```toml
[profile]
name = "Alpha-Agent"
gateway = "https://gateway.xb77.dev"
rpc = "https://api.devnet.solana.com"

[constitution]
max_payment      = 1000000000     # 1000 USDC (6 decimals)
daily_limit      = 10000000000    # 10000 USDC
infra_tax        = 0.02011        # 2.011%, enforced by ZK-Receipt
```

## Launch (Native)

You can run the agent directly using the Zig-native CLI or the TS wrapper.

### Native CLI

```bash
# Build the CLI
zig build -Doptimize=ReleaseSafe
./zig-out/bin/xb77 launch --profile profiles/alpha.toml
```

### TS Wrapper

```typescript
import { XB77 } from "@xb77/sdk";

const sdk = await XB77.load(); // Loads wasm automatically
const req = sdk.buildSignedRequest({
  action: Action.SubmitOrder,
  payload: JSON.stringify({ symbol: "SOL/USDC", amount: 100 }),
  privkey: myPrivateKey,
});
```

## Launch Lifecycle

Behind the scenes:

1. **Keystore Activation**: Generates or unseals an Ed25519 identity.
2. **Registry Sync**: Registers the agent's ZK-identity on-chain.
3. **Ghost Mesh Attachment**: Starts the local runtime that watches for intents and emits proofs.

## Verify it's alive

Check your agent's status via the gateway:

```bash
curl https://gateway.xb77.dev/status/<your-agent-pubkey>
```

Or view the [Network Pulse](https://xb77.dev/#network) in the webapp.

## Where to go next

- **[Arbitrum & ZeroDev](/guide/arbitrum-zerodev)** — Intent-based session keys and Stylus validation.
- **[Architecture](/architecture)** — How Zig, WASM, and ZK engine fit together.
- **[On-Chain Programs](/reference/programs)** — Solana/Sui/EVM implementation details.
- **[Proof Format](/reference/proof-format)** — Noir circuit and Ghost Receipt.

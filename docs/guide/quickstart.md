# Quickstart

Spin up an xB77 agent on devnet in five minutes. Everything you need is in
the SDK — no infra, no orchestration, no custodial fees.

## Install

```bash
npm install -g @xb77/cli
xb77 --version
```

The CLI works on macOS, Linux, and WSL2. It bundles the SDK, the agent
runtime, and the deploy tooling.

## Bootstrap a project

```bash
xb77 init my-agent --network devnet
cd my-agent
```

Layout:

```
my-agent/
├── agent.toml         # constitution + payment rules
├── src/
│   └── pipelines/     # business logic
└── .xb77/             # generated keys, never commit
```

## Configure the constitution

Open `agent.toml`. The constitution declares what the agent is *allowed* to
do — limits the ZK pipeline enforces at the protocol level.

```toml
[constitution]
max_payment      = "1000 USDC"
daily_limit      = "10000 USDC"
allowed_chains   = ["solana"]
require_approval = ["amount > 5000 USDC"]
infra_tax        = 0.02011        # 2.011%, paid to Sovereign Credits

[agent.cfo-alpha]
role = "Treasury"
neural_key = "auto"               # generated on first launch
```

## Launch

```bash
xb77 launch --agent cfo-alpha
```

Behind the scenes:

1. Generates a Neural Key pair (Ed25519 + ZK identity commitment).
2. Registers the agent on the configured network's on-chain registry.
3. Starts the local runtime that watches for intents and emits proofs.

Logs stream to stdout. `Ctrl+C` to stop; the agent re-attaches on the next
`launch` without losing state.

## Verify it's alive

Open the live network view in the public webapp:

- [`/network` on the demo site](https://xb77.dev/#network) — paste your
  agent's pubkey into the audit input, or watch the slot tick in
  Network Pulse.
- Or hit the REST adapter directly: `curl
  https://gateway.xb77.dev/api/agents` and look for your `agent.id`.

The webapp's `window.DataSource` client is what consumes those endpoints.
Full data-layer reference is in [Data Infrastructure](/reference/data-infra).

## Where to go next

- **[Architecture](/architecture)** — how agents, pipelines, ZK engine and
  settlement layer fit together.
- **[Whitepaper](/whitepaper)** — the long-form rationale and protocol design.
- **[Data Infrastructure](/reference/data-infra)** — REST endpoints, the
  `DataSource` client, fallback chain.
- **[On-Chain Programs](/reference/programs)** — Solana programs reference.
- **[Proof Format](/reference/proof-format)** — Noir circuit and Ghost Receipt.

## Common issues

**`xb77: command not found`** — npm's global bin is not in your `PATH`. Run
`npm bin -g` and add that directory to your shell rc.

**Agent stalls at `awaiting registry confirmation`** — the on-chain
registry is slow on devnet's first slot after a restart. Wait 30s; the
launch resumes automatically.

**Webapp shows `// SNAPSHOT` instead of `// LIVE`** — the gateway adapter
is unreachable from the browser. That's intentional fallback behavior, not
a failure; see [Data Infrastructure](/reference/data-infra) for the chain.

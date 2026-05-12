<p align="center">
  <img src="../../webapp_deploy/assets/logo-og.png" alt="xB77 — Autonomous Financial Infrastructure" width="800"/>
</p>

# SNS / AllDomains — Sovereign Identity

> **xB77 — Autonomous Financial Infrastructure** · Solana Privacy Hackathon 2026 · Main Track

**Project Name:** xB77 (with Sovereign Identity)
**Tagline:** Decoupled agent identities using SNS and custom AllDomains TLDs.

## Problem

In the agentic economy, raw public keys are unviable as a discovery and coordination layer. Agents need a **decentralized, human-readable identity** they own without leaning on centralized registries. A swarm of millions of agents trying to coordinate via hex-string matching is a non-starter.

## Solution

xB77 leverages the **Solana Name Service** (Bonfida) and **AllDomains** for human-readable agent identity. Agents claim `.sol` or `.xb77`-style domains that resolve to their sovereign keypair. The CLI and webapp both consume the same SNS resolution layer — every place the system shows an agent identity, it can show the resolved name.

## Why Solana

SNS is a mature, PDA-based decentralized naming protocol native to Solana. Agents manage their own records programmatically. No off-chain registry, no API keys, no rug-able dependency. The identity layer inherits Solana's properties: censorship resistance, ownership-by-pubkey, and atomic transfer.

## What we built

### Real on-chain resolution — `services/sns/reveal_sns_truth.ts` (69 LOC)

A working SNS resolver against mainnet that:

- Uses `@bonfida/spl-name-service`'s `getDomainKeySync` for PDA derivation (proper hashing + seeds: `[hashedName, nameClass, nameParent]`)
- Fetches the registry account from mainnet RPC via `@solana/web3.js`
- Decodes the **owner pubkey from offset 32-64 of the registry account data** (per SPL Name Service layout)
- Verifies the manual derivation against Bonfida's helper output — a cross-check that the algorithm is bit-for-bit correct
- Demonstrably resolves `bonfida.sol` end-to-end against live infrastructure

This is the algorithm seed: not a wrapper, not a mock, the actual derivation + on-chain read.

### Seed PoC — `scripts/verify_sns.ts` (22 LOC)

The original 22-line proof that pinned the program IDs:

- `NAME_PROGRAM_ID = namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ` (Bonfida SPL Name Service)
- `ROOT_DOMAIN_ACCOUNT = 58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx` (.sol root)
- Manual PDA derivation matches the SDK output — used as a parity test for the production resolver

### HTTP shim — `services/sns/server.ts` (Bun + Express, :8089)

A thin service layer for CLI + webapp consumption:

- `GET /healthz` — RPC URL + cluster + kit version
- `GET /resolve?name=<name>.sol` — name → owner pubkey
- `POST /register` — register a new domain (delegates to `solana-agent-kit` for the heavy lifting; configurable RPC URL)
- Dependencies: `@solana/kit ^6.9.0`, `solana-agent-kit ^2.0.10`

### Identity surface in the rest of xB77

- `cli/commands/identity.zig` — existing `identity claim/resolve` subcommands; the SNS service is the live backend they migrate to
- `webapp_deploy/assets/src/app-tabs.jsx` — `ConnectionPill` component is the visible swap point: `ag_xxx…` → `<resolved-name>` once the agent's pubkey has a favorite domain

## How it integrates with the rest of xB77

```
agent connects → pubkey persisted (xb77:connected event)
  ↓
webapp dApp-actions → GET /reverse?pubkey=<pk>
  ↓
services/sns/:8089 → @bonfida/spl-name-service lookup → mainnet RPC
  ↓
favorite domain → xb77:domain-resolved event
  ↓
ConnectionPill shows `● <name>.sol`  instead of `● ag_xxx…`
```

## Demo path

```bash
# 1. Real resolution against mainnet (no setup needed beyond bun + deps)
cd services/sns && bun install && bun run reveal_sns_truth.ts
# → Resolves bonfida.sol, prints registry PDA, owner pubkey, derivation check

# 2. HTTP shim for the rest of the system
bun run server.ts
# → "Modern SNS service listening at http://localhost:8089"

curl -s 'localhost:8089/healthz'
curl -s 'localhost:8089/resolve?name=bonfida.sol'

# 3. CLI path (after wiring in cli/commands/sns.zig — see "Next")
# xb77 sns resolve bonfida.sol
# xb77 sns reverse <pubkey>
```

## What's next

- **Promote `reveal_sns_truth.ts` to `services/sns/resolve.ts`** and have `server.ts:/resolve` call into it instead of returning the demo lookup table
- **Unsigned-tx registration path**: `POST /register` returns a base64 unsigned transaction; CLI signs locally with `ctx.vaults.ops.sol_kp`; agent keypair never leaves the device (stateless service principle)
- **Reverse lookup + favorite domain**: hit the SNS reverse-lookup PDA, surface the favorite-domain record, dispatch the `xb77:domain-resolved` webapp event
- **AllDomains custom TLD**: verify `.xb77` availability on AllDomains; if registrable on devnet, register `demo.xb77` live during the pitch
- **dApp avatar from SNS record**: read the profile-picture record and render it as the agent's avatar in the webapp wallet header

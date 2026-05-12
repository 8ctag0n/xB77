<p align="center">
  <img src="../../webapp_deploy/assets/logo-og.png" alt="xB77 — Autonomous Financial Infrastructure" width="800"/>
</p>

# MagicBlock PER — Sovereign HFT Rail

> **xB77 — Autonomous Financial Infrastructure** · Solana Privacy Hackathon 2026 · Main Track

**Project Name:** xB77 (with MagicBlock PER)
**Tagline:** High-fidelity commerce rail for autonomous agents using Private Ephemeral Rollups.

## Problem

Autonomous AI agents need machine-speed settlement to coordinate at scale. Traditional L1 blockchains — even Solana — impose latency that bottlenecks high-frequency agentic commerce. A system built for human reaction times cannot serve a swarm of agents negotiating micro-services at millisecond intervals.

## Solution

xB77 wires MagicBlock's **Private Ephemeral Rollups (PER)** as an HFT rail underneath its agent payment flow. Agents open a PER session, dispatch ephemeral transactions to the sequencer for near-instant settlement, and commit back to Solana L1 only at session close — preserving auditability while collapsing per-tx latency.

## Why Solana

Solana is the anchor: final state, account delegation, and ZK commitment lives on L1. PER sits between the agent and the chain, absorbing burst rates without polluting block space.

## What we built

A two-layer integration spanning the native Zig core and a TypeScript operator console:

### Native Zig SDK — `core/chain/magicblock.zig` (175 LOC)

A first-class `MagicBlockSDK` struct exposing the PER session lifecycle:

- `Session` / `EphemeralTx` types with expiry + signature surfaces
- `openSovereignSession(agent_kp)` — generates a 32-byte session ID, anchors an L1 escrow on the xB77 program (PDA seeds `[b"per_escrow", agent_pubkey, session_id]`), prints `[MAGIC] PER Session Active: <id>` to the demo terminal
- `dispatchEphemeral(session, tx)` — POSTs a signed AWP packet to the sequencer endpoint
- `commitToSolana(session)` — close-and-settle ceremony
- Test-aware: `mock:` endpoint prefix short-circuits the L1 anchor for unit testing
- Adapter type `MagicBlockClient = MagicBlockSDK` for compatibility with the legacy Engine path

The SDK is wired into `core/mesh/mesh.zig:409` (`[SWARM ] Peer accepted loan. Executing L1 transfer via MagicBlock...`) and gated through `core/security/constitution.zig:14`'s `force_hft_rail` constitutional flag.

### TS operator console — `services/magicblock/server.ts` (Bun + Express, :8090)

A stateless HTTP shim that the xB77 gateway and webapp call against:

- `GET  /healthz` — sequencer URL + kit version
- `POST /session/open` — accepts `{ authority, amount, duration }`, returns session ID + L1 anchor sig
- `POST /tx/dispatch` — accepts `{ session_id, target, amount, payload_hash, signature }`, returns sequencer accept signature

Dependencies pinned: `@solana/kit ^6.9.0`, `solana-agent-kit ^2.0.10`, `axios ^1.16.0`. Configurable via `XB77_MAGICBLOCK_URL` and `XB77_SOL_RPC_URL`.

## How it integrates with the rest of xB77

```
agent (Zig CLI)
  ↓
core/chain/magicblock.zig  →  L1 escrow (xB77 program on Solana devnet)
  ↓
services/magicblock/:8090  →  POST /tx/dispatch → MagicBlock sequencer
  ↓
[MAGIC] session-close → commit back to L1
```

The `force_hft_rail` constitution flag lets the agent's brain (QVAC, see `QVAC.md`) decide at evaluation time whether to route a payment through PER or standard rails.

## Demo path

```bash
# 1. Spin up the operator shim
cd services/magicblock && bun install && bun run server.ts
# → "MagicBlock PER service listening at http://localhost:8090"

# 2. From another terminal, smoke-test
curl -s localhost:8090/healthz
curl -s -X POST localhost:8090/session/open \
  -H 'content-type: application/json' \
  -d '{"authority":"...","amount":2000000000,"duration":3600}'

# 3. The Zig SDK path is exercised by the swarm flow:
xb77 swarm peer accept --amount 0.5  # triggers [MAGIC] block in mesh.zig
```

## What's next

- **Live PER session against MagicBlock's devnet sequencer**: today the SDK signs the L1 escrow against xB77's own program; the next milestone is to additionally call the official MagicBlock Delegation Program (`DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh`) so sessions appear on the MagicBlock explorer
- **Replace the TS shim's mock response paths** (`/session/open`, `/tx/dispatch`) with real axios calls to the sequencer endpoint
- **Webapp PER pill**: `⚡ PER <session_id_short> · 12m 34s` in the dApp shell, dimming when no session is active
- **Auto-scaling**: open a new session per N agents based on intent-queue pressure

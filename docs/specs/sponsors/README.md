# Sponsor integration specs

Three sponsor tracks to be executed by an autonomous agent in a remote
environment (cloud GPU box for QVAC; cloud Solana RPC for MagicBlock /
SNS). The local team focuses on the bidirectional demo wiring; these
specs land independently and merge in.

| Spec | Sponsor | Track | GPU? | Cloud? |
|---|---|---|---|---|
| [`qvac.md`](qvac.md) | Tether QVAC | $10k side prize | Yes (dev) / CPU (deploy) | Yes (Runpod/Brev/similar) |
| [`magicblock.md`](magicblock.md) | MagicBlock | Main hackathon | No | Solana devnet (live) |
| [`sns.md`](sns.md) | Solana Name Service / AllDomains | Main hackathon | No | Solana devnet (live) |

## Pattern for the agent

Each spec is **self-contained**: the executing agent must be able to read
the file, clone the repo, discover what's there, fill in unknowns from
official sponsor docs, integrate, and commit back. No tribal knowledge.

## Branch strategy

Each track lands on its own short-lived branch off `feat/dapp-public-split`:

- `sponsor/qvac` ← Tether QVAC integration
- `sponsor/magicblock` ← MagicBlock PER live
- `sponsor/sns` ← SNS resolve + register

When green, fast-forward merge into the integration branch.

## Acceptance gate

A spec is "done" only when:

1. Code compiles (`zig build` for Zig changes; `bun build` for TS changes)
2. The dedicated smoke script in `scripts/` passes (each spec lists which)
3. The sponsor's product is observably live (a real session ID, a real
   domain resolved, a real model loaded — not a stub)
4. The demo orchestrator (`scripts/demo_e2e.sh`) shows the integration in
   its happy path

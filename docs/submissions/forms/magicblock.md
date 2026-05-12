# MagicBlock — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link to `demo_magicblock.mp4` (or current `demo_v2_480.mp4` if not ready yet)
- `<X_HANDLE>` — your X profile URL

> **Note:** A first version of this submission was made with the backup video. When the dedicated `demo_magicblock.mp4` finishes rendering, the recommended update is just the Demo Link (or a new comment with the link if the form is locked).

---

## Link to Your Submission

```
https://xb77-adapter.frontier247hack.workers.dev
```

## Tweet Link

```
<empty or your tweet URL>
```

## Project Title

```
xB77 — Sovereign HFT Rail via MagicBlock PER
```

## Project Description

```
xB77 is sovereign agent commerce infrastructure for Solana: a Zig-native CLI + on-chain agents that resolve identity (SNS native in Zig, matches Bonfida mainnet), reason on-device (QVAC heuristic engine + Gemma-ready architecture), and settle high-frequency trades via MagicBlock's PER (Persistent Ephemeral Rollup) lane.

The MagicBlock integration lives in core/chain/magicblock.zig and services/magicblock/server.ts. We implement the full PER session lifecycle from the Zig core:

  1. dispatchEphemeral — packs a JSON payload and ships it to the sequencer URL (supports a "mock:" prefix for deterministic CI; flips to the live devnet sequencer for prod)
  2. openSession — opens a PER session bound to the agent's xB77 vault keypair
  3. commitToSolana — anchors ephemeral state to Solana L1 via a ClosePerSession instruction on the xb77_gateway program (deployed on devnet at 83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4)

The agent decides when to take this rail through a constitutional flag (force_hft_rail in core/security/constitution.zig). When the brain reasons that a payment requires sub-second settlement, the router picks the PER lane; otherwise it goes through standard L1.

End-to-end demo: `zig build trident-smoke` opens a session, dispatches an ephemeral payload, and commits — visible as real terminal output in the 90s demo video.

Honest delta: the current commitToSolana targets our own xb77_gateway program for L1 escrow because we wanted the lifecycle to work inside the hackathon window. Next iteration calls MagicBlock's Delegation Program (DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh) directly so sessions appear on MagicBlock's explorer. The TS shim mocks session_id and sequencer_sig for the same reason; real axios to the live devnet sequencer is spec'd in docs/specs/sponsors/magicblock.md and gated behind XB77_MAGICBLOCK_URL.
```

## Project Github Link

```
https://github.com/8ctag0n/xB77v2
```

## Deployment Link

```
https://xb77-adapter.frontier247hack.workers.dev
```

## Demo Link

```
<YOUTUBE_URL>
```

## Project X Profile Link

```
<X_HANDLE>
```

## Your Program Pubkey (if program available)

```
83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4
```

## Anything Else?

```
Honest delta vs the spec — what's built, what's wired-up-but-stubbed, what's roadmap:

Built (verifiable):
  • PER session lifecycle in pure Zig (core/chain/magicblock.zig)
  • Constitutional routing flag (force_hft_rail) that lets the on-device brain decide when to take the ephemeral rail
  • TS shim at services/magicblock/ that bridges the Zig SDK to HTTP
  • L1 anchor via ClosePerSession (xb77_gateway program deployed on devnet, verifiable on Solscan)
  • End-to-end smoke: zig build trident-smoke

Wired but stubbed (next iteration):
  • Sequencer dispatches use mock:// prefix — real axios to XB77_MAGICBLOCK_URL=https://devnet.magicblock.app spec'd in docs/specs/sponsors/magicblock.md section 2
  • L1 escrow calls our own xb77_gateway program rather than MagicBlock's Delegation Program DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh

Useful links:
  • Spec: github.com/8ctag0n/xB77v2/blob/sponsors-and-deluxe-merge/docs/specs/sponsors/magicblock.md
  • Submission writeup: github.com/8ctag0n/xB77v2/blob/sponsors-and-deluxe-merge/docs/submissions/MAGICBLOCK.md
  • Worker /api/v1: https://xb77-adapter.frontier247hack.workers.dev/api/v1

Built end-to-end by one operator over the hackathon window — happy to walk through the dispatchEphemeral → commitToSolana code path live if useful.
```

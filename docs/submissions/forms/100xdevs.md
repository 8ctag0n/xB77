# 100xDevs — Frontier Side Track Submission

This is the **generic / meta** track — no sponsor tech to align with. Judging criteria from the brief:

1. **Technical Execution**
2. **Innovation**
3. **Real-World Use Case**
4. **User Experience**
5. **Completeness**

Copy below is tuned to hit those five.

> **Note**: 100xDevs requires submission BOTH on the Colosseum portal AND on Superteam Earn. Use this same copy on both.

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link (use `demo_v3.mp4` or any of the sponsor-specific cuts)
- `<X_HANDLE>` — your X profile URL

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
xB77 — Sovereign Agent Commerce Infrastructure for Solana
```

## Project Description

```
xB77 is end-to-end infrastructure for autonomous agents that need to transact on-chain without surrendering identity, reasoning, or settlement to third parties. Built across five Solana programs, a Zig-native CLI, a Cloudflare Worker gateway, an in-browser dApp, and three sovereign service planes (SNS identity / QVAC brain / MagicBlock HFT rail) — all deployed and verifiable today.

THE PROBLEM
As agents (LLM-driven or otherwise) start executing on-chain transactions on behalf of users, three things break:
  1. Identity is delegated to centralized resolvers (Bonfida API, RPC providers, custodial wallets)
  2. Reasoning happens in cloud LLMs, leaking intent + creating prompt-injection surface
  3. Settlement requires HTTP roundtrips, making sub-second decisions impossible

xB77 closes all three.

WHAT'S BUILT

Solana plane (5 programs, devnet):
  • xb77_core         — agent identity + credit line
  • xb77_gateway      — signed action surface (SubmitPrivateOrder + ClosePerSession)
  • xb77_registry     — merchant catalog
  • xb77.iopression  — Poseidon BN254 state anchors
  • xb77_zk_verifier  — chunked proof buffer

Zig CLI (~50 KLOC, builds in ~30s):
  • IDL-driven Solana client (wincode codec + tx assembly + signing) — no anchor-lang crate, no @solana/web3
  • Constitutional brain that gates every payment on declarative policy flags
  • Native SNS resolution matching Bonfida mainnet byte-for-byte
  • Vault + keystore (Ed25519 AES-GCM, password-derived)

Cloudflare Worker gateway (post-Pages Static Assets pattern):
  • Single workers.dev URL serves both the dApp (/app, /assets/*) and the signed REST API (/api/v1/*)
  • Wire schema 1.1: binary canonical signing, nonce replay protection, Ed25519 response signatures
  • 5 KV namespaces: AGENTS / ORDERS / NONCES / BUCKETS / IDEMP
  • One-shot deploy script (scripts/cf_deploy.sh) — idempotent KV creation via CF API, non-interactive secret put, full bring-up in ~3 minutes from a fresh token

In-browser dApp (React + esbuild, no framework):
  • 7 tabs: Wallet · Agents · Pipelines · Proofs · Merchants · Mesh · Explorer
  • Web Crypto Ed25519 signing on user device, never round-trips a private key
  • IDL-driven program decoding via pure-JS wincode (no @solana/web3 dependency)
  • Same-origin with the API (no CORS dance)

Sovereign services (Bun/TypeScript):
  • services/sns — SNS identity bridge
  • services/qvac_brain — on-device LLM shim (Gemma-ready architecture)
  • services/magicblock — PER session SDK

TECHNICAL EXECUTION
  • zig build test — 16 test suites passing (crypto / tx / store / zk / cmt / awp / brain / merchant / compression / strategist / orchestrator e2e / negotiation / onchain)
  • zig build trident-smoke — cross-service integration smoke (SNS native + brain + MagicBlock lifecycle)
  • zig build sns-test — Bonfida API vs native Zig parity assert
  • Worker conformance: 22 tests including SDK wire-1.1 suite
  • Live deployment health: curl-able /api/v1 endpoints

INNOVATION
  • Native Zig SNS resolution — every other SNS integration goes through Bonfida HTTP API or @solana/spl-name-service in JS. Ours derives the PDA in pure Zig and verifies against the registry account directly. 100% sovereign identity path.
  • Constitutional reasoning — the brain isn't a chat loop, it's a deterministic decision gate on declarative policy flags (force_hft_rail, privacy_floor, max_autonomous_lamports). Policy is code, not prompt.
  • One Worker serves dApp + API at the same origin (modern post-Pages Static Assets pattern) — eliminates CORS class of bugs entirely.

REAL-WORLD USE CASE
Agents are coming. Right now the infra forces them through centralized chokepoints — identity (resolver APIs), reasoning (cloud LLMs), settlement (wallet UIs). xB77 is the substrate where an agent can be ITS OWN wallet, ITS OWN reasoner, ITS OWN settler — and still talk to L1 like any other actor. Target users: high-frequency trading bots, autonomous merchant agents, AI-driven treasury managers, sovereign DAO tooling.

USER EXPERIENCE
  • One URL: https://xb77-adapter.frontier247hack.workers.dev
  • dApp loads from edge cache in <100ms
  • All 7 tabs work without a browser-installed wallet — keystore is in-browser, signing is Web Crypto
  • CLI is single-binary (`xb77`), zero runtime dependencies, builds in 30 seconds from source

COMPLETENESS
  • End-to-end working today: open the URL, connect via keystore, submit a private order, watch the daemon ingest the signature, see it appear in Pipelines tab — all real, all signed, all on devnet
  • Honest open ends: xb77_zk_verifier::verify() is a stub (anchors bytes, real crypto verifier on roadmap); MagicBlock's Delegation Program isn't yet wired; QVAC's native Gemma inference is gated. Each is documented with the exact line of code that flips it on.
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
73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3
```

(xb77_core. All 5 program IDs enumerated in Anything Else.)

## Anything Else?

```
Smoke tests anyone can run right now:

  curl -s https://xb77-adapter.frontier247hack.workers.dev/api/v1 | jq
  curl -s https://xb77-adapter.frontier247hack.workers.dev/api/v1/network/pulse | jq
  curl -sI https://xb77-adapter.frontier247hack.workers.dev/app | head -3
  zig build sns-test     # Bonfida vs native Zig parity

Five deployed programs on devnet (open in explorer.solana.com/?cluster=devnet):
  xb77_core         73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3
  xb77_gateway      83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4
  xb77_registry     HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1
  xb77.iopression  6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN
  xb77_zk_verifier  J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ

Docs (vitepress):
  Specs:        docs/specs/sponsors/{sns,qvac,magicblock}.md
  Submissions:  docs/submissions/{SNS,QVAC,MAGICBLOCK}.md
  API contract: docs/api-contract-v1.md

Built by one operator over the hackathon window. The honest delta is documented in every spec file — what's real, what's wired-up-but-stubbed, what's roadmap. No mocks dressed as production.
```

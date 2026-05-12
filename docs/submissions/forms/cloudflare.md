# Cloudflare Workers — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link (you can use `demo_v3.mp4` today, or a CF-specific cut later)
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
xB77 Gateway — Edge-Native Sovereign Agent Infrastructure on Workers
```

## Project Description

```
xB77's gateway is a Cloudflare Worker that serves both the dApp (static assets) and the API (signed REST) under a single workers.dev URL — using the post-Pages Static Assets pattern that became available in May 2026.

What's running at https://xb77-adapter.frontier247hack.workers.dev:

API (/api/v1/*):
  • Wire schema 1.1: binary canonical signing, nonce replay protection, agent_id correlation
  • 8 REST endpoints — 4 signed POST actions (register_agent, submit_order, claim_credits, query_pulse) + 4 read GETs (network/pulse, network/audit, agents/fleet, agents/:id, pipelines/recent, wallet/*)
  • Ed25519 response signing — every response carries X-Xb77-Gateway-Signature so the dApp + CLI can verify the gateway didn't tamper
  • Token-bucket rate limiting per agent_id, per tier
  • Idempotency key caching (IDEMP namespace, 24h TTL)
  • Watch daemon ingest endpoint (/api/v1/pipelines/ingest) with bearer auth for the off-Worker indexer

Static Assets (/ and /app):
  • Same origin = zero CORS dance with the API
  • All 7 dApp tabs (Wallet · Agents · Pipelines · Proofs · Merchants · Mesh · Explorer)
  • .assetsignore excludes the Remotion source tree (~670 MB of node_modules) so deploys stay lean
  • Edge cache served from Cloudflare PoP

5 KV namespaces in production: AGENTS · ORDERS · NONCES · BUCKETS · IDEMP

Deploy automation: scripts/cf_deploy.sh takes a CLOUDFLARE_API_TOKEN + ACCOUNT_ID and brings up the entire stack idempotently — creates KVs via CF API (no wrangler text-parsing fragility), generates a fresh Ed25519 signing keypair, sets secrets non-interactively, patches wrangler.toml, deploys. Re-runs are safe (reuses existing KVs by title).

The Worker code lives in gateway/worker/src/index.js (~1100 LOC, no framework). Tests in gateway/worker/test/. Conformance: 22 tests passing including the SDK wire-1.1 conformance suite.

Honest delta: this is the strongest piece of the project. Built end-to-end, deployed live, verifiable by curl.
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

(xb77_gateway — the program the Worker proxies via signed actions)

## Anything Else?

```
Smoke test commands (run from anywhere):
  curl -s https://xb77-adapter.frontier247hack.workers.dev/api/v1 | jq
  curl -s https://xb77-adapter.frontier247hack.workers.dev/api/v1/network/pulse | jq
  curl -sI https://xb77-adapter.frontier247hack.workers.dev/app | head -3

Key files:
  Worker code:      gateway/worker/src/index.js
  Wrangler config:  gateway/worker/wrangler.toml ([assets] block — Static Assets pattern)
  Deploy script:    scripts/cf_deploy.sh (one-shot bring-up)
  Wire schema spec: docs/api-contract-v1.md

Gateway pubkey (Ed25519, last 32B of seed||pubkey):
  46877b09dd8fd5e7afc068c6722a5ba9a3301a4f4dbab01742c52f01f0f1aa44

Built by one operator over the hackathon window. Happy to walk through the Worker → KV → Solana RPC → response sign loop live.
```

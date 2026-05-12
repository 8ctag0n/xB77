# Bonfida / SNS — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link to `demo_bonfida.mp4`
- `<X_HANDLE>` — your X profile URL (e.g. `https://x.com/dzkinha`)

---

## Link to Your Submission

```
https://xb77-adapter.frontier247hack.workers.dev
```

## Tweet Link

```
<deja vacío si no hay tweet del proyecto>
```

## Project Title

```
xB77 — Native .sol Resolution in Pure Zig
```

## Project Description

```
The first native SNS resolver written in Zig — no Bonfida HTTP API, no @solana/spl-name-service JS dependency, byte-for-byte parity with mainnet. Identity in xB77 is sovereign by default because the .sol lookup never leaves the agent.

THE RESOLVER (core/security/identity.zig)
  resolveSnsNative derives the SNS registry PDA from the domain hash + the SOL_TLD_REGISTRY constants directly in Zig, fetches the registry account via Solana RPC, decodes it, and returns the owner pubkey. Zero external API calls.

PROOF
  zig build sns-test runs the Bonfida public API AND our native derivation against the same RPC, then asserts the two pubkeys match:
    [SNS TEST] API Result:    Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v
    [SNS TEST] Native Result: Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v
    [SNS TEST]  MATCH! Native engine is 100% Sovereign.

LIVE INTEGRATION (in the dApp, post-deploy)
  • CLI: xb77 -p <profile> identity resolve <name>.sol — uses the native path
  • xb77 status — shows the resolved domain with a "Native Verified" badge when the local PDA matches the on-chain account
  • dApp ConnectionPill — swaps "ag_xxx…" for "<name>.sol" automatically once the keystore connects. Hooks into xb77:domain-resolved event fired by the browser-side reverse-lookup helper.
  • Worker endpoint GET /api/v1/sns/reverse?pubkey=<base58> — proxies to Bonfida's user/domains API, caches results in KV. Used by the browser helper.

You can test the live SNS path right now without cloning:
  curl "https://xb77-adapter.frontier247hack.workers.dev/api/v1/sns/reverse?pubkey=Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v"
  → {"ok":true,"sol":"<first-domain>.sol","cached":<bool>}

OPEN GAP (honest)
  The register flow (mint a fresh .sol from inside the dApp) is roadmap, not built. Today's scope is resolve-only: forward (.sol → wallet) and reverse (wallet → .sol). Spec for the register flow is in docs/specs/sponsors/sns.md section 2.
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
HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1
```

(xb77_registry — where merchants register with SNS-resolvable identities)

## Anything Else?

```
Code paths:
  • Native PDA derivation (Zig):   core/security/identity.zig:resolveSnsNative
  • Test harness:                   tests/sns_test.zig (zig build sns-test)
  • Worker reverse endpoint:        gateway/worker/src/index.js:handleSnsReverse
  • Browser helper:                 webapp_deploy/assets/src/lib/sns-reverse.js
  • ConnectionPill .sol swap:       webapp_deploy/assets/src/app-tabs.jsx:ConnectionPill

Specs + writeups:
  • Spec:               docs/specs/sponsors/sns.md
  • Submission narrative: docs/submissions/SNS.md

Smoke tests anyone can run right now (no clone needed):
  zig build sns-test               # local — matches mainnet, prints MATCH
  curl "https://xb77-adapter.frontier247hack.workers.dev/api/v1/sns/reverse?pubkey=Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v"

Built end-to-end by one operator. The native resolver is novel because every other SNS integration in the ecosystem (that I know of) either uses Bonfida's HTTP API or @solana/spl-name-service in JS — making them dependent on a third party. Our Zig path resolves directly from the on-chain registry account, and our Worker only uses Bonfida's API as an OPTIONAL reverse-lookup helper for the dApp UX (the resolver core itself doesn't need it).
```

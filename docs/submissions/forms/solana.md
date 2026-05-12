# Solana base (Anchor / L1 programs) — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link to `demo_solana.mp4`
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
xB77 — Five Solana Programs, One Sovereign Agent
```

## Project Description

```
xB77 is sovereign agent commerce infrastructure built natively on Solana. Five interconnected programs, all deployed on devnet, all integrated end-to-end through a single Zig binary:

  xb77_core (73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3)
    Agent registry + credit line management. The home base of every agent.

  xb77_gateway (83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4)
    InitGateway + SubmitPrivateOrder + verify_badge + ClosePerSession.
    The action surface where signed agent intents land on-chain.

  xb77_registry (HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1)
    Merchant registry. InitMerchant + AddCatalog + UpdateMerchant.
    Decoded in-browser via pure-JS wincode (no @solana/web3 dep for read).

  xb77_compression (6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN)
    Poseidon BN254 state transitions (anchorState). The ZK plane's base.

  xb77_zk_verifier (J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ)
    Chunked proof buffer (init/write/verify). Currently verify() is a stub
    that accepts proof bytes — the real Honk/Groth16 verifier is on the
    near-term roadmap.

The novel part is the Zig CLI driving all 5. From core/onchain/:
  - wincode.zig: Borsh-compatible binary codec
  - idl_client.zig: IDL-driven instruction builder (no anchor crate)
  - solana_tx.zig: tx assembly + signing + base58
  - solana_rpc.zig: HTTP RPC client

That stack lets us build, sign, and send transactions to any of the 5 programs from pure Zig — no anchor-lang Rust at the client side, no JS web3 SDK. The same client emits a binary tx blob that the Cloudflare Worker forwards or that the dApp signs in-browser via Web Crypto Ed25519 + the same wincode.

End-to-end demo: `zig build trident-smoke` opens a session, dispatches an ephemeral payload, commits to L1 — touching xb77_gateway and xb77_core in one Zig binary call.

Tests: `zig build test` runs 16 test suites including onchain unit tests (wincode codec + IDL client + tx assembly).
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

(xb77_core — the root program. All 5 enumerated in Anything Else.)

## Anything Else?

```
Five programs (all on devnet, all in explorer.solana.com/?cluster=devnet):

  xb77_core         73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3
  xb77_gateway      83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4
  xb77_registry     HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1
  xb77_compression  6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN
  xb77_zk_verifier  J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ

IDLs in idls/*.json. Each is consumed by the Zig CLI (core/onchain/idl_client.zig) AND the dApp (webapp_deploy/assets/js/lib/idl-client.js — same wire format, two implementations).

Honest delta:
  • xb77_zk_verifier::verify() is a stub. We anchor proof bytes + commitment hash today; real cryptographic verification (Groth16 or Honk on SBF) is the next pass.
  • xb77_compression batches state anchors via Poseidon BN254 but doesn't yet expose the rollup-style sequence interface — that's the layer the brain will exercise post-MVP.

Worker: https://xb77-adapter.frontier247hack.workers.dev/api/v1
dApp:    https://xb77-adapter.frontier247hack.workers.dev/app
```

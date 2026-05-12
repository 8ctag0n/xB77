# 🔁 HANDOFF — submit_order onchain + live pipelines feed CLOSED

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/docs-v2`
> **Branch**: `feat/dapp-public-split` @ `0946778`
> **Status**: Gaps #1 (submit_order onchain) and #2 (agent daemon → live feed) closed.
> **Local stack**: bootable in one shot via `scripts/full_local_stack.sh --keep-up`.

## What this session shipped

### Track A — SubmitPrivateOrder onchain via IDL
- `xb77 gateway init` — one-time idempotent admin tx that creates the
  `gateway_state` PDA. Uses the current profile's keypair as admin.
  `scripts/full_local_stack.sh` calls it automatically after `solana program
  deploy` if a profile exists (default: `myagent`).
- `xb77 gateway submit-order` — encodes `SubmitPrivateOrder` via IDL, derives
  `gateway_state` + `nullifier` PDAs (`crypto.findProgramAddress`), submits a
  real tx, waits for confirmation.
- Webapp: `submitOrderOnchain()` in `dapp-actions.js` mirrors the CLI path
  byte-identically. New "SUBMIT 📦" button in pipelines view loads
  `/idls/xb77_gateway.json`, derives PDAs in pure JS (`pda.js` —
  BigInt off-curve check, no deps), signs with Web Crypto Ed25519.
- IDL `xb77_gateway.json` gained `metadata.address`. Program ID realigned
  to `83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4` (matched the deployed
  keypair in `merge-onchain-deluxe`; the in-tree `declare_id!` constant is
  stale — that's a `merge-onchain-deluxe` cleanup task, not this session's).

### Track B — `xb77 gateway watch` daemon + live pipelines
- `xb77 gateway watch [--interval N] [--once]` polls
  `getSignaturesForAddress(<gateway_program>)` every N seconds (default 5)
  and POSTs new signatures to `${XB77_GATEWAY}/api/v1/pipelines/ingest`.
- Worker `POST /api/v1/pipelines/ingest` — bearer auth via
  `env.INGEST_TOKEN` (default `devtoken`). Writes one entry per tx to the
  `ORDERS` KV with TTL 1h. `handlePipelinesRecent` surfaces them
  automatically — no UI change.
- `scripts/full_local_stack.sh` boots the daemon after wrangler is up and
  cleans the PID on teardown.

### Plumbing additions
- `core/onchain/solana_rpc.zig`: `getSignaturesForAddress` + `getAccountOwner`
  + JSON-formatted error messages (was unreadable struct dump).
- `gateway/worker/wrangler.toml`: `INGEST_TOKEN_DEV = "devtoken"`.

## Verified live (smoke 2026-05-12)

```
[INIT]   signature: 53jQSruULXMWT1wpBjSFPCFCvoCHahJPCA63NadxaZrp3oZ5TZMaV2aigLeAse2BoS24f4tawWVBSApQ5bvWHFPd  → CONFIRMED
[SUBMIT] signature: 31ADHVU1oQnaSETc1AqCU3z43BMv2XuhatvVcH8NzLfh8XBYToDJCotjkzm7c5mPBzVRaq4ZUm8tF2ShShSUYkZH  → CONFIRMED
[WATCH]  tick: 2 new sigs, latest=31ADHVU1oQna (HTTP 200)

GET /api/v1/pipelines/recent:
  pipe:31ADHVU1oQna  VALID  (the SubmitPrivateOrder)
  pipe:53jQSruULXMW  VALID  (the InitGateway)
```

Tests: 50/50 webapp, `zig build` clean.

## What's still open

| # | Gap | Effort | Notes |
|---|---|---|---|
| 3 | ZK proof gen (Noir + bb) → `xb77_zk_verifier` chunked verdict GREEN visible in webapp | 2.5h | Container `xb77-zk` exists, `zk-upload-e2e` Zig binary exists, verifier deployed but `verify()` is a STUB (entropy check only). Scope: webapp Proofs tab + CLI `xb77 zk prove [--upload]` subcommand. |
| 4 | `xb77_registry` (merchants) integrated into the dApp UI | 1-2h | Low priority. |
| 5 | Receipts program | 2-3h | Separable. |
| – | Real cryptographic verification onchain (replace stub) | 4-6h | Post-demo; needs honkproof-on-SBF or hybrid commitment design. |
| – | Realign `declare_id!` in `merge-onchain-deluxe` to match deployed keypair | 15min | Maintenance — not blocking. |

## How to retake this branch

```bash
cd /home/exp1/Desktop/xB77/worktree/docs-v2
git log --oneline -3        # confirm 0946778 is HEAD
zig build                   # rebuild CLI
scripts/full_local_stack.sh --keep-up   # boots validator + worker + webapp + watch daemon

# Browser smoke:
#   open http://127.0.0.1:8080/app.html
#   login keystore → click SUBMIT 📦 → "submit tx: <16 chars>…" appears
#   refresh pipelines → onchain entry visible

# CLI smoke:
export XB77_PASSWORD=demo-pw
./zig-out/bin/xb77 -p myagent gateway init           # idempotent
./zig-out/bin/xb77 -p myagent gateway submit-order
curl http://127.0.0.1:8787/api/v1/pipelines/recent  # appears within 5s
```

## Suggested next sessions

**Session C — ZK e2e visible** (recommended next)
   Pipeline already works end-to-end via `xb77-zk` container and
   `zk-upload-e2e` binary. Missing: (1) a webapp "Proofs" tab that lists
   verifier PDA contents and triggers a prove+upload, (2) a clean
   `xb77 zk prove [--upload]` subcommand. The stub verifier is fine for
   the demo — call it out in copy ("entropy-attested" or "demo verifier").

**Session D — Devnet deploy**
   Now that A+B closed, mergeable. Redeploy programs to devnet, swap
   wrangler `ZNODE_RPC_URL` to devnet, the watch daemon points at the
   devnet RPC. Webapp + CLI work against a real public chain.

**Session E — Crypto verifier**
   Replace the stub `verify()` in `xb77_zk_verifier` with real
   cryptographic verification. Two pragmatic paths:
   1. Off-chain Groth16/PLONK verification + commitment hash onchain
      (cheap, but trust-shifts to the verifier service)
   2. Onchain Sunspot/Gnark verifier program reachable via CPI from
      `xb77_gateway::verify_badge` (heavy CU, may need precompiles)

## Frase de arranque sugerida

> "Vengo del cierre A+B en feat/dapp-public-split (HEAD `0946778`).
> submit_order + watch daemon ambos verdes onchain. Leé este HANDOFF.
> Próximo paso recomendado: Session C (ZK e2e visible en webapp)."

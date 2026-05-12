# HANDOFF — A+B+C+D onchain + sponsors-deluxe trident MERGED

> **Branch**: `sponsors-and-deluxe-merge`
> **Status**: A + B + C + D + sigverify + DEMO refresh closed AND sponsors-deluxe (SNS + QVAC + MagicBlock + brand) merged in.
> **Local stack**: bootable in one shot via `scripts/full_local_stack.sh --keep-up`.
> **Sovereign trident snapshot**: see `HANDOFF-TRIDENT.md` for the deluxe-side close-out (commit `f09fc73`).

## What's shipped in this branch (5 sessions + sponsors-deluxe merge)

### Track A — `SubmitPrivateOrder` onchain (commit `0946778`)
- `xb77 gateway {init, submit-order}` IDL-driven.
- Webapp `submitOrderOnchain()` + SUBMIT 📦 button.
- Pure-JS PDA derivation (`pda.js`, BigInt off-curve check).
- Stack autoboot includes `gateway init`.

### Track B — Watch daemon + live pipelines (commit `0946778`)
- `xb77 gateway watch [--interval N] [--once]` polls gateway + verifier
  programs and POSTs new sigs to worker `/api/v1/pipelines/ingest`
  (bearer auth via `INGEST_TOKEN`).
- Pipelines view refreshes within one tick (~5s) without browser RPC.
### Track C — ZK e2e visible (commit `e3661fc`)
- `xb77 zk {prove, upload, run}` CLI:
  - `prove` shells `nargo prove` via the `xb77-zk` podman container.
  - `upload` chunked-uploads via `core.chain.zk_uploader.uploadAndVerify`
    (1 init + N write + 1 verify).
  - `run` chains both.
- Watch daemon extended to poll the verifier program too. Pipelines
  records gain a `kind` field (`gateway` or `zk`).
- Webapp **Proofs** tab filters `kind=zk` and lists init/write/verify
  with verdict badges. Read-only; demo hint shown inline.

### Track D — Merchants onchain (commit `fc8331c`)
- `xb77_registry` built via `cargo build-sbf` inside `xb77-solana`
  container, deployed at `HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1`.
- `xb77 merchant register --id <slug> [--methods N]` now IDL-driven
  (replaces the legacy `RegistryManager` path).
- Webapp **Merchants** tab: REGISTER form + list of merchants via RPC
  `getProgramAccounts` + pure-JS wincode decoder for `MerchantAccount`.
- `idl_client.zig` gained `bytes` and `string` primitive support
  (mapped to `vecU8`).

### Polish — sigverify + DEMO refresh (commit `5e07656`)
- Webapp verifies `X-Xb77-Gateway-Signature` on every signed-action
  response. Lazy fetch of `gateway_pubkey` from `/api/v1`, cached.
  Non-strict by default; set `window.XB77_STRICT_RESP_SIG = true` to
  enforce.
- DEMO.md grew from 6 steps to 10 — covers ANCHOR / SUBMIT / Merchants /
  ZK prove+upload / response-sig verify. New "sovereignty checklist"
  section enumerates the trust properties the demo proves.

## Live state

**Programs deployed on the local validator (5 total):**

| Program | Program ID | What it does |
|---|---|---|
| `xb77_core` | `73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3` | Agent + credit line core |
| `xb77_compression` | `6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN` | Poseidon BN254 state transitions (anchorState) |
| `xb77_zk_verifier` | `J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ` | Chunked proof buffer + (stub) judge |
| `xb77_gateway` | `83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4` | InitGateway + SubmitPrivateOrder + verify_badge |
| `xb77_registry` | `HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1` | Merchant registry + catalog |

**Webapp tabs (`/app.html`):** Wallet · Agents · Pipelines · Proofs ·
Merchants · Mesh · Explorer.

**CLI surface:**
```
xb77 gateway {meta, register, order, claim, pulse, reads, anchor,
              submit-order, init, watch}
xb77 zk {prove, upload, run}
xb77 merchant {status, add, setup-shop, blink, publish, register,
               dispute, plan}
xb77 brain think "<directiva>"        # NEW: QVAC on-device reasoning
xb77 identity resolve <name>.sol      # NEW: SNS native (Bonfida-equiv)
xb77 services                          # NEW: trident dashboard (SNS+QVAC+MB)
```

**Tests:** 50/50 webapp · `zig build` clean.

## What's still open (out of scope until sponsors merge)

| # | Gap | Effort | Notes |
|---|---|---|---|
| – | Devnet deploy (CF Pages + Worker + programs) | 1-2h | Held until sponsor programs land — they'll bundle into the same devnet redeploy. |
| – | Real crypto ZK verifier (replace stub) | 4-6h | Post-demo; Groth16/Honk on SBF or hybrid commitment. |
| – | `xb77_registry::AddCatalog` UI | 1h | Webapp Merchants tab today shows registrations only — no catalog add. |
| – | Receipts compressed program integration | 2-3h | Separable. |
| – | Sponsor integration (SNS, MagicBlock, QVAC, Tether, +?) | per sponsor 1-2h | Coming from remote sessions. Each gets 3 layers: UI hook + worker endpoint + CLI cmd. |
| – | Realign `declare_id!` in `merge-onchain-deluxe` for xb77_gateway | 15min | Maintenance — current local ID `83nP…` is the deployed keypair's, not the source's. |

## How to retake this branch

```bash
cd /home/exp1/Desktop/xB77/worktree/docs-v2
git log --oneline -6        # confirm 5e07656 is HEAD
zig build                   # rebuild CLI
XB77_PASSWORD=demo-pw XB77_INIT_PROFILE=myagent \
  scripts/full_local_stack.sh --keep-up

# Browser smoke:
#   open http://127.0.0.1:8080/app.html
#   keystore login → walk tabs: Wallet → Pipelines (ANCHOR + SUBMIT) →
#                    Merchants (REGISTER) → Proofs

# CLI smoke (in another terminal):
export XB77_PASSWORD=demo-pw
./zig-out/bin/xb77 -p myagent gateway anchor
./zig-out/bin/xb77 -p myagent gateway submit-order
./zig-out/bin/xb77 -p myagent merchant register --id cafe-soberano
./zig-out/bin/xb77 -p myagent zk prove --upload
curl http://127.0.0.1:8787/api/v1/pipelines/recent | jq .
```

## Suggested next sessions (post-sponsors)

**Session F — Sponsor integration cascade**
   Wait for sponsor sessions (SNS, MagicBlock, QVAC, Tether) to land.
   For each sponsor, add 3 layers in a single PR:
   1. Webapp surface (badge/section/icon) that proves the integration
      is wired.
   2. Worker endpoint (`/api/v1/sponsors/<name>/...`) for any CPI
      proxying or off-chain mediation.
   3. CLI subcommand (`xb77 sponsor <name> ...`).
   Merge sequentially with a smoke test per sponsor.

**Session G — Devnet deploy**
   Once all sponsors are in, redeploy programs to devnet, switch
   wrangler `ZNODE_RPC_URL`, deploy webapp to CF Pages and worker via
   `wrangler deploy`. Run the same demo against real public chain.

**Session H — Real crypto verifier**
   Replace `xb77_zk_verifier::verify()` stub. Two paths:
   1. Off-chain Groth16/PLONK verification + commitment hash onchain.
   2. Onchain Honk verifier via CPI from gateway, heavy CU.

## Frase de arranque sugerida

> "Vengo del cierre A+B+C+D+polish + sponsors-deluxe merge en
> `sponsors-and-deluxe-merge`. Stack local 5 programas + 3 servicios
> sovereign (SNS/QVAC/MagicBlock) + brand Remotion. dApp con tabs
> onchain + Proofs + Merchants + signatures deluxe. CLI con
> gateway+zk+merchant+brain+identity.sol+services dashboard."

## Sponsors deluxe — what was merged in

Brought over from `sponsors-deluxe` (commits `3997cef` → `f09fc73`):

- **SNS** (`services/sns/`, `core/security/identity.zig`): native `.sol` resolution in Zig — matches Bonfida mainnet PDA `Crf8hzfthWGbGbLTVCiqRqV5MVnbpHB1L9KQMd6gsinb`. HTTP shim on `:8087`. Validated by `zig build sns-test`.
- **QVAC** (`services/qvac_brain/`, `core/intelligence/brain.zig`, `deps/llama.h`): on-device brain. TS shim on `:8088` (active path), llama.cpp prep (`loadModel` commented behind compile flag), heuristic fallback if shim is down.
- **MagicBlock** (`services/magicblock/`, `core/chain/magicblock.zig`): PER session SDK + L1 settlement via `ClosePerSession`. Mock support via `mock:` URL prefix.
- **Brand** (`webapp_deploy/remotion/`, logos deluxe v2/v3, OG images): Remotion SoT for receipt-seal mark, intro, HeroLoop. Static SVG/JSX mirrors in `webapp_deploy/assets/`.
- **CLI**: `xb77 brain think "<directiva>"` + `xb77 services` trident dashboard (SNS+QVAC+MagicBlock health) added.
- **Tests**: `zig build trident-smoke` for cross-service smoke.
- **Docs**: `docs/submissions/{MAGICBLOCK,QVAC,SNS}.md` for hackathon judge view.

## Post-merge follow-ups (priority order)

### MagicBlock — close the gap to live PER
- `core/chain/magicblock.zig:74` ALSO calls MagicBlock Delegation Program `DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh` so sessions appear on their explorer
- `services/magicblock/server.ts:38-49`, `:56-72` → real axios to `XB77_MAGICBLOCK_URL` (`https://devnet.magicblock.app`)
- Add `cli/commands/magicblock.zig` (`start / status / close / probe`) per `specs/sponsors/magicblock.md` §2
- Webapp PER pill in dApp shell — `PER <id_short> · 12m 34s`

### QVAC — flip on real inference
- `services/qvac_brain/server.ts:22-26` uncomment `loadModel({ modelSrc: GEMMA_3_4B_IT_Q4_0 })`, deploy on Runpod T4 (~$0.30/h)
- `core/intelligence/brain.zig:98` wire actual llama.cpp via `deps/llama.h`
- Optional Noir witness over `{ constitution_hash, decision, agent_pubkey }`

### SNS — promote PoC to production
- Move `services/sns/reveal_sns_truth.ts` logic into `services/sns/resolve.ts`, wire `server.ts:32-45` `/resolve` to call into it
- Add `cli/commands/sns.zig` (`resolve / reverse / register / set-favorite`) per `specs/sponsors/sns.md` §2
- Unsigned-tx registration; keypair never leaves device
- Webapp `ConnectionPill` swaps `ag_xxx…` for `<name>.sol` after `xb77:domain-resolved`

### Mega-demo
- See `DEMO-MEGA.md` for the 5-minute end-to-end script that exercises EVERY sponsor + the onchain track in one run.

## Hygiene / watch-out

- `webapp_deploy/remotion/node_modules` (~674 MB), `services/qvac_brain/node_modules` (~4 GB), `webapp_deploy/remotion/out/` (renders) all gitignored — verify before staging
- Don't run `git config --global` — user identity is per-command via `-c` flags
- `force_hft_rail` flag in `core/security/constitution.zig:14` gates brain → MagicBlock PER routing
- 17 SNS PoC scripts in `scripts/{check_*,test_*,reveal_pda*,verify_sns_*}` are kept as exploratory artifacts — prune in a `chore(scripts): drop SNS PoC` commit if they get in the way

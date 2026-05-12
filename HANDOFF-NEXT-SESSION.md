# HANDOFF — Sponsors deluxe, post-brand + submissions ready

> **Branch**: `sponsors-deluxe` @ `e977ca9`
> **Author config**: per-command via `git -c user.name="dzkinha" -c user.email="195769325+dzkinha@users.noreply.github.com"` (NOT in `.git/config`)
> **Working tree**: clean — 4 commits ready to push
> **Last session deliverable**: brand system (Remotion + mirrors), 3 honest sponsor submissions, propagated tagline "Autonomous Financial Infrastructure"

## What landed this session

```
e977ca9 feat(sns): on-chain resolution + HTTP shim — sovereign identity         29 files +1391/-14
dc4044b feat(qvac): on-device brain — Zig core + TS service                     14 files +1060/-37
1080468 feat(magicblock): PER session SDK + ops shim — sovereign HFT rail        9 files  +899/-5
3997cef feat(brand): receipt-seal mark — Remotion source + site mirrors         33 files +5501/-16
```

## Immediate (submission window)

- `git push origin sponsors-deluxe` — nothing is on the remote yet
- README.md hero rewrite: banner OG already there, but add a "Per sponsor" section linking to `docs/submissions/{MAGICBLOCK,QVAC,SNS}.md` and a 30-second demo run block (`bun run` lines for each service)
- Demo video 60–90s: extend `webapp_deploy/remotion/out/intro.mp4` (3s stamp, exists) with screencast of `xb77 swarm peer accept` + `xb77 brain think "..."` + `bun run reveal_sns_truth.ts`. Render with `cd webapp_deploy/remotion && npm run render:intro` for the source clip
- Sanity-check the 3 submission `.md` rendering on GitHub — the banner uses relative path `../../webapp_deploy/assets/logo-og.png`; verify it works in the GitHub UI before the deadline
- If the hackathon platform needs slides: `/create-pitch-deck` skill reads the submission files + commits as input

## Post-submission, in priority order

### MagicBlock — close the gap to live PER

- `core/chain/magicblock.zig:74` currently signs an L1 escrow against the xB77-owned program `73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3`. To match the submission's roadmap, ALSO call MagicBlock's Delegation Program `DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh` so sessions appear on their explorer
- `services/magicblock/server.ts:38-49` and `:56-72` return mock session IDs and sequencer sigs. Replace with real axios calls to `XB77_MAGICBLOCK_URL` (`https://devnet.magicblock.app`)
- Add `cli/commands/magicblock.zig` with `start / status / close / probe` subcommands per `specs/sponsors/magicblock.md` section 2
- Webapp PER pill in dApp shell — `⚡ PER <id_short> · 12m 34s`, dim when no session

### QVAC — flip on real inference

- `services/qvac_brain/server.ts:22-26` has `loadModel({ modelSrc: GEMMA_3_4B_IT_Q4_0, modelType: "llm" })` commented. Uncomment and deploy on Runpod T4 (~$0.30/h). Container outline in `specs/sponsors/qvac.md` section 4
- `core/intelligence/brain.zig:98` reads `QVAC_MODEL_PATH` env var with heuristic fallback — wire actual llama.cpp binding via the `deps/llama.h` header that's now committed
- Optional: Noir witness over `{ constitution_hash, decision, agent_pubkey }` per `Insight.zk_proof_tag` strings already produced (`qvac_local_verified_airgapped` etc.)

### SNS — promote PoC to production path

- `services/sns/reveal_sns_truth.ts` (69 LOC) is the actual working resolver. Move its logic into `services/sns/resolve.ts` and have `server.ts:32-45` `/resolve` call into it instead of the hardcoded lookup table
- `cli/commands/sns.zig` does NOT exist yet — implement `resolve / reverse / register / set-favorite` per `specs/sponsors/sns.md` section 2
- Unsigned-tx registration: `POST /register` should return base64 unsigned tx; CLI signs locally with `ctx.vaults.ops.sol_kp`; keypair never leaves device
- Webapp `ConnectionPill` swap: after `xb77:connected`, fire `xb77:domain-resolved` event from `dapp-actions.js` once the favorite-domain reverse lookup resolves, then have `app-tabs.jsx` listen and replace `ag_xxx…` with `<name>.sol`

## Hygiene / nice-to-have

- 17 SNS PoC scripts in `scripts/{check_*,test_*,reveal_pda*,verify_sns_*}` are committed as exploratory artifacts in `e977ca9`. If they get in the way, prune in a `chore(scripts): drop SNS PoC` commit
- `services/sns/sns.log` is now gitignored by the local `.gitignore` added before commit 4
- The brand system source-of-truth flow is documented in `webapp_deploy/remotion/README.md` — read that before editing the seal
- Memory store at `/root/.claude/projects/-content-xB77v2/memory/` has 4 entries capturing user preferences and project conventions (Colab outputs, no-emoji/no-attribution rule, brand direction, brand architecture)

## Watch out for

- Don't commit `webapp_deploy/remotion/node_modules` (674 MB), `services/qvac_brain/node_modules` (4 GB) — all gitignored, verify before staging
- Don't run `git config --global` — user identity is meant to stay per-command via `-c` flags or scoped to this repo only (no `--global`)
- The `force_hft_rail` constitutional flag in `core/security/constitution.zig:14` gates whether the brain routes a payment through MagicBlock PER vs standard rails. Keep this contract when changing brain.zig

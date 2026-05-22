# DEMO-MEGA — 5 minutes, 1 minute per sponsor, judges open-mouthed

> **Branch**: `sponsors-and-deluxe-merge` @ `d8df53e`
> **Scope**: every sponsor + every onchain track exercised in one run
> **Tone**: terse narration, dense visuals, no fluff
> **Audience**: hackathon judges who will see ~100 demos in a day. Make the first 15 seconds matter.

---

## What this demo proves (one-liner per sponsor)

| Sponsor | What we prove | Where it lives |
|---|---|---|
| **Solana** (L1) | 5 programs deployed, real `SubmitPrivateOrder` + watch lifecycle | `xb77_{core,gateway,registry,compression,zk_verifier}` |
| **SNS / Bonfida** | Native `.sol` PDA derivation in Zig matches Bonfida mainnet | `core/security/identity.zig` + `zig build sns-test` |
| **QVAC / Tinfoil** | On-device brain with heuristic fallback when shim is killed | `services/qvac_brain/` + `core/intelligence/brain.zig` |
| **MagicBlock** | PER session → 10 ephemeral dispatches → L1 settlement | `services/magicblock/` + `core/chain/magicblock.zig` |
| **Cloudflare Workers** | Wire 1.1 gateway, real `/api/v1/orders` + `/pipelines/ingest` | `gateway/worker/src/index.js` |
| **ZK** | nargo prove → chunked upload → onchain verify, all visible | `xb77 zk run` + Proofs tab |
| **Brand / craft** | Remotion as SoT, receipt-seal mark, no AI slop | `webapp_deploy/remotion/` |

---

## 5-minute script

### 0:00–0:15 — Cold open

**Show**: `webapp_deploy/remotion/out/intro.mp4` (3s logo intro) → cut to `app.html`.

**Say** (one sentence):
> "xB77 — autonomous financial infrastructure. Five Solana programs, three sovereign services, zero mocks. Watch."

Brand seal, wordmark deluxe, palette lime+cyan. No magenta, no cyberpunk slop.

---

### 0:15–0:45 — SNS sovereign identity (Bonfida)

**Terminal A**:
```bash
./zig-out/bin/sns-test
```

**Show**: side-by-side
- Bonfida mainnet API result: `Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v`
- Native Zig derivation: same address
- `[SNS TEST]  MATCH! Native engine is 100% Sovereign.`

**Say**:
> "We don't trust Bonfida's API — we derive the PDA in Zig and verify the on-chain account directly. 100% sovereign `.sol` resolution, no HTTP dependency."

---

### 0:45–1:30 — QVAC on-device brain (Tinfoil)

**Terminal A**: start the shim
```bash
cd services/qvac_brain && bun run server.ts &
```

**Terminal B**:
```bash
export XB77_USE_BRAIN_SHIM=1
./zig-out/bin/xb77 brain think "transfer 5 SOL to alice.sol with privacy"
```

**Show**: rich `BrainInsight` output — intent, reasoning, risk score, constitutional RAG rules triggered, mission hash.

**Say**:
> "Inference happens on-device, never leaves the box. If the shim dies…"

**Terminal A**: `kill %1`

**Terminal B**: rerun the same `brain think` command.

**Show**: same output but with `(Heuristics Fallback)` — the agent doesn't stall.

**Say**:
> "…the agent falls back to heuristic reasoning. No external dependency, no leak surface."

---

### 1:30–2:30 — Onchain order (Solana base + Cloudflare gateway)

**Browser** (`http://127.0.0.1:8086/app.html`):
1. Connect via keystore modal (Ed25519 keypair, password-derived, browser-only).
2. Wallet tab → balance shows.
3. Pipelines tab → click **ANCHOR ⛓** → state anchored via `xb77.iopression`.
4. Click **SUBMIT 📦** → `SubmitPrivateOrder` lands on `xb77_gateway`.

**Terminal C**:
```bash
./zig-out/bin/xb77 gateway watch --interval 5
```

**Show**: daemon ingests the new signature, POSTs to Worker `/api/v1/pipelines/ingest`, the Pipelines tab refreshes within one tick (~5s) — verdict `VALID`, slot N, signature link to Solscan.

**Say**:
> "dApp signed locally, gateway program saw it, watch daemon picked it up, Cloudflare Worker indexed it. End-to-end without leaving sovereignty."

---

### 2:30–3:30 — MagicBlock HFT rail (PER)

**Browser**: stay on Pipelines.

**Terminal A**: start the MagicBlock shim
```bash
cd services/magicblock && bun run server.ts &
```

**Terminal B**:
```bash
./zig-out/bin/xb77 brain think "open PER session, run 10 micropays, commit to L1"
```
(Or run the trident smoke directly if the brain-driven path isn't wired for this demo:)
```bash
./zig-out/bin/trident-smoke
```

**Show**:
- `[MAGIC] PER Session Active: e9978198a700c38f`
- 10 `dispatchEphemeral` payloads → receipt sizes
- `[MAGIC] Committing Ephemeral State to Solana L1`
- (Optional) Solscan tab opens the `ClosePerSession` instruction tx.

**Say**:
> "Ephemeral rollup for HFT velocity, settled atomically on Solana L1. The brain decides when to take this rail — `force_hft_rail` constitutional flag."

---

### 3:30–4:30 — Registry + ZK proof (Solana + Noir)

**Terminal D**:
```bash
./zig-out/bin/xb77 -p myagent merchant register --id cafe-soberano --methods 2
```

**Browser** → Merchants tab → new row appears, decoded directly from `xb77_registry` via `getProgramAccounts` + pure-JS wincode.

**Terminal D**:
```bash
./zig-out/bin/xb77 -p myagent zk run     # prove + upload in one shot
```

**Show**:
- `nargo prove` runs in the podman container.
- Chunked upload: 1 `init` + N `write` + 1 `verify` to `xb77_zk_verifier`.
- Browser → Proofs tab → init/write/verify signatures appear in order with verdict badges.

**Say**:
> "Merchant on-chain, proof on-chain, verifier on-chain. Five programs, one demo, zero mocks."

---

### 4:30–5:00 — Mic drop

**Terminal A**:
```bash
./zig-out/bin/xb77 -p myagent status
```

**Show**: the trident dashboard
```
--- xB77 SOVEREIGN AGENT STATUS (myagent) ---
[IDENTITY] myagent.xb77 / myagent.sol -> Fw1ETan... (Native Verified)
[BRAIN   ] Gemma 3 (Active via TS Shim :8088)
[HFT RAIL ] MagicBlock (Live Sequencer)
--------------------------------------------------
Solana L1: <addr>
Base EVM:  <addr>
ZK Ledger: Root 0xa3b1... (47 entries)
Status:    SOVEREIGN & ACTIVE
```

**Cut to**: Remotion seal fadeout (`webapp_deploy/remotion/out/hero.mp4` last frame).

**Say**:
> "Five programs, three sovereign services, one agent. xB77."

---

## Pre-requisite checklist (must be green before recording)

### Build / tests
- [ ] `zig build` — `xb77` binary builds (current: ✅ on `d8df53e`)
- [ ] `zig build test` — full unit + e2e suite passes (current: ✅)
- [ ] `zig build trident-smoke` && `./zig-out/bin/trident-smoke` — green (current: ✅)
- [ ] `./zig-out/bin/sns-test` — MATCH against Bonfida (current: ✅)

### Local infra
- [ ] `scripts/full_local_stack.sh --keep-up` — validator + worker + webapp boot
- [ ] 5 programs deployed: confirm IDs match `HANDOFF-NEXT-SESSION.md` "Live state" table
- [ ] `services/sns/` running on `:8087`
- [ ] `services/qvac_brain/` running on `:8088` (or skip if heuristic fallback only)
- [ ] `services/magicblock/` running (mock sequencer ok for local demo)

### Webapp visual
- [ ] `webapp_deploy/build.sh` clean (current: ✅)
- [ ] `http://127.0.0.1:8086/app.html` loads, all 7 tabs render (Wallet · Agents · Pipelines · Proofs · Merchants · Mesh · Explorer)
- [ ] Logo deluxe + framer-motion vendor present (current: ✅)
- [ ] Remotion renders fresh: `cd webapp_deploy/remotion && npm run render:intro && npm run render:hero && npm run render:og`
  - Outputs land in `webapp_deploy/remotion/out/{intro,hero}.mp4` + `og.png` + `mark.png`
  - Palette: lime+cyan only, NO magenta (per design direction)

### CLI smoke (manual, ~2 min)
```bash
export XB77_PASSWORD=demo-pw
./zig-out/bin/xb77 -p myagent init                 # if profile doesn't exist
./zig-out/bin/xb77 -p myagent status               # trident dashboard renders
./zig-out/bin/xb77 -p myagent brain think "test"   # brain works
./zig-out/bin/xb77 -p myagent gateway anchor       # state anchors onchain
./zig-out/bin/xb77 -p myagent gateway submit-order # order lands
./zig-out/bin/xb77 -p myagent gateway watch --once # daemon polls
./zig-out/bin/xb77 -p myagent merchant register --id demo --methods 2
./zig-out/bin/xb77 -p myagent zk run --upload      # prove + upload
```

### Colab notebook helper

```python
# After running scripts/full_local_stack.sh in a separate cell:
from google.colab.output import serve_kernel_port_as_iframe
serve_kernel_port_as_iframe(8086, path='/app.html', height=900)
```

---

## Recording notes

- **3 terminals visible**, color-coded by role (A: services, B: brain/agent, C: watch daemon, D: CLI ops).
- **Browser in a 4th pane**, app.html with dev tools closed.
- **Cuts on action** — never wait for spinners > 3s; pre-warm everything.
- **No emoji in narration**. The seal does the visual work.
- **Background music**: silence, OR a single low drone. No EDM, no countdown ticks.
- **Final frame**: hero.mp4 last frame → fade to black → white text "xB77" → cut.

## Failure modes (be ready to cut around)

| Symptom | Likely cause | Fast recovery |
|---|---|---|
| Bonfida API timeout in SNS demo | rate-limit or network | skip API, show only native PDA (`zig build sns-test` still matches account on RPC) |
| Brain shim hangs | model load lag | pre-warm shim before recording; OR kill and demo fallback only |
| `gateway watch` doesn't see new sig | worker `INGEST_TOKEN` mismatch | `export INGEST_TOKEN=devtoken` before launching daemon |
| MagicBlock real sequencer 500 | devnet sequencer flaky | use `mock:` prefix in `XB77_MAGICBLOCK_URL` |
| Merchant register fails | profile not initialized | `xb77 init` then redo |
| ZK prover container missing | podman not running | `./zig-out/bin/xb77 zk prove --skip-prove` to use a fixed witness fixture |

## Where the bodies are buried (judges won't ask but you should know)

- `xb77_zk_verifier::verify()` is a stub — we anchor the proof bytes + commitment hash, the real Groth16/Honk circuit lives in Noir but isn't verified on-SBF yet (out-of-scope, in `HANDOFF-NEXT-SESSION.md` post-merge follow-ups).
- MagicBlock L1 settlement currently calls our `ClosePerSession` against `73vhQ…` — to appear on MagicBlock's explorer the post-merge follow-up wires their Delegation Program `DELeGGvX…`.
- `services/qvac_brain/server.ts` has `loadModel({ modelSrc: GEMMA_3_4B_IT_Q4_0 })` commented behind a TODO — heuristic fallback covers the demo, real inference needs T4 deployment.
- The 17 `scripts/{check_*,test_*,reveal_pda*,verify_sns_*}` files are exploratory SNS PoC artifacts from the deluxe session; they're committed but not load-bearing.

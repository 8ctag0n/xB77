<p align="center">
  <img src="../../webapp_deploy/assets/logo-og.png" alt="xB77 — Autonomous Financial Infrastructure" width="800"/>
</p>

# Tether QVAC — Sovereign AI Brain

> **xB77 — Autonomous Financial Infrastructure** · Solana Privacy Hackathon 2026 · Tether QVAC side track ($10k pool)

**Project Name:** xB77 (with QVAC Brain)
**Tagline:** Sovereign Financial OS with on-device LLM risk evaluation.

## Problem

AI agents today are mostly cloud-bound clients that lean on third-party LLM APIs. An agent that ships its strategy and "weights" to a cloud provider is not truly autonomous. The machine economy demands **on-device reasoning** to protect strategic alpha and operational sovereignty.

## Solution

xB77 wires Tether's **QVAC** as the agent's brain. Every risk-bearing decision — flash loan acceptance, order pre-trade gating, merchant trust — is evaluated locally against a cryptographically pinned **Sovereign Constitution**. The brain returns a structured `{ decision, risk_score, reasoning }` that the rest of the stack consumes. No cloud LLM. No API keys. No leak.

## Why Solana

Solana anchors the *outcome* of brain decisions. The reasoning stays private and on-device; the resulting signed action commits to Solana, optionally wrapped in a Noir ZK-proof of constitutional compliance. The brain decides, Solana records.

## What we built

### Native Zig brain — `core/intelligence/brain.zig` (358 LOC)

A `Brain` struct that takes a constitutional reference and exposes:

- `reasonWithGemma(directive)` — main entry, returns an `Insight` with directive + zk_proof tag
- `QVAC_MODEL_PATH` environment-variable gate for the real on-device model; gracefully falls back to constitution-aware heuristics when the model is unavailable (visible as `[BRAIN ] QVAC_MODEL_PATH not set: ... Using fallback heuristics.`)
- ZK proof tags emitted per decision path: `qvac_austerity_override_v1`, `qvac_local_verified_airgapped`, `qvac_rag_rejected_by_constitution`
- Direct constitution consultation (`core/security/constitution.zig`) before any LLM is touched — the brain cannot violate the constitution even if the model misbehaves

### CLI surface — `cli/commands/brain.zig`

```
xb77 brain think "<directive>"
  → loads the agent's vault, instantiates the Brain with the agent's constitution,
    calls reasonWithGemma, prints the formatted insight
```

The CLI is the same surface a judge can use to verify the integration shape without a GPU.

### TS micro-service — `services/qvac_brain/server.ts` (Bun + Express, :8088)

A drop-in `/evaluate` endpoint that wraps the QVAC SDK:

- Imports `loadModel` and `GEMMA_3_4B_IT_Q4_0` from `@qvac/sdk` directly — real SDK constants, not a stand-in
- `GET /healthz` — model name + load state + ms-per-tok signal for the webapp's `● running on-device · QVAC` indicator
- `POST /evaluate { scenario, context }` — returns `{ decision, risk_score, reasoning, model, ms_inference }`
- Three scenario types implemented: `loan_request`, `submit_order`, `merchant_trust`
- Model load is gated for resource-constrained environments; flip on by uncommenting the `loadModel` call once running on a box with the model file present

### Constitutional integration

`core/security/constitution.zig:14` exposes `force_hft_rail` and similar flags. The brain consults the constitution BEFORE any model call, so policy violations are short-circuited deterministically — the LLM only weighs in on borderline cases.

## How it integrates with the rest of xB77

```
agent action (e.g. peer-loan request, submit_order)
  ↓
brain.reasonWithGemma(directive)   # core/intelligence/brain.zig
  ↓
constitution check                  # deterministic gate
  ↓ (if borderline)
QVAC model.generate(prompt) | fallback heuristics
  ↓
Insight { decision, risk_score, zk_proof_tag }
  ↓
signed by agent → committed to Solana (optionally with Noir ZK proof)
```

The brain is **client-side by design** — the gateway never calls it. The agent's keypair signs the outcome after the brain decides locally. The on-device promise is structurally preserved.

## Demo path

```bash
# Option A: CLI (no GPU needed; runs heuristic fallback)
xb77 brain think "should I accept a 0.5 SOL loan from peer ag_a9f?"

# Option B: TS service (needs Bun + @qvac/sdk installed)
cd services/qvac_brain && bun install && bun run server.ts
# → "QVAC brain service listening at http://localhost:8088"

curl -s -X POST localhost:8088/evaluate \
  -H 'content-type: application/json' \
  -d '{"scenario":"loan_request","context":{"amount":500000000}}'
# → { decision: "approve", risk_score: 0.05, reasoning: "Micro-loan...", ... }
```

## What's next

- **Enable real Gemma 3 4B inference**: uncomment the `loadModel` call in `services/qvac_brain/server.ts` and bake the model into the deploy container (~4GB image; `infra/Containerfile.qvac` outlined in the spec)
- **Fine-tune for financial reasoning**: distill a smaller QVAC-compatible model specialized for risk-score-with-reasoning, drop image size below 1GB
- **Multi-agent QVAC**: agents share encrypted "learnings" across the swarm via QVAC's secure inference primitives
- **Noir circuit binding**: each `Insight.zk_proof_tag` becomes a real Noir witness over `{ constitution_hash, decision, agent_pubkey }`, anchored on Solana

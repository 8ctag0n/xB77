# Spec — Tether QVAC integration (Sovereign AI Brain)

> **Sponsor**: Tether
> **Track**: Side prize — Frontier builders who integrate QVAC into their project ($10k pool)
> **Submission deadline**: May 11, 2026 (Superteam Earn listing)
> **Repo branch to target**: `sponsor/qvac` (cut from `feat/dapp-public-split`)

## Why this spec exists

xB77 is already pitched as *"sovereign agents with local LLM evaluation"*
(see `README.md` line 88: *"Other agents use their local LLM (Gemma 4) to
evaluate the risk and autonomously provide a micro-loan"*). That LLM
slot is currently a **placeholder**. QVAC IS the natural fill: it ships
exactly the local-LLM capability the narrative demands, on-device, no
cloud, no API keys. Filling that slot with QVAC turns the existing
narrative into a working sponsor integration.

The Tether judging criteria weight technical depth at 40%, product value
at 30%, innovation at 20%, demo quality at 10%. The integration must NOT
be a wrapper or demo — it has to be a **functional component of what
we're building**. We satisfy that by making the QVAC Brain the **actual
decision-maker** for Swarm flash loans and `submit_order` risk gates.

## What "done" means

A reviewer can clone the repo, `podman build` one container, `podman run`
it, and the rest of the xB77 stack (CLI + webapp + gateway) routes
all risk-evaluation decisions through it. The container has Gemma loaded,
serves inference over local HTTP on `:8088`, and returns structured
JSON. The webapp shows a *"running on-device · QVAC"* badge. The CLI
exposes `xb77 brain evaluate "<scenario>"` that hits the same endpoint.

## Required reading before starting

1. **QVAC docs root**: https://docs.qvac.tether.io
2. **QVAC quickstart**: https://docs.qvac.tether.io/sdk/getting-started/quickstart/
3. **QVAC GitHub**: https://github.com/tetherto/qvac (npm packages live there)
4. **xB77 README.md** — find the *"Other agents use their local LLM"*
   paragraph and the *"Brain"* references — those are the narrative hooks
5. **`scripts/demo_frontier.sh`** — has the `[BRAIN] Consulting Gemma 4
   (Local Sovereign Model)` placeholder line; that is the exact slot
6. **`core/intelligence/brain.zig`** — current state of the brain code in
   the Zig core. Inventory what exists; figure out if it's used or stub
7. **`core/intelligence/`** directory more broadly — there may be related
   modules to wire through

## Implementation plan (the agent fills in details)

### 1. Bootstrap on a GPU box (dev environment)

- Recommended rental: **Runpod T4** (~$0.30/hr) or Brev.dev free tier
- Clone the repo into `/workspace/xb77`
- Install bun, zig (matches `build.zig`'s required version), node 22
- `npm install @qvac/sdk @qvac/llm-llamacpp` — verify the install works
  with the box's GPU (Vulkan or CUDA). If install fails, fall back to
  CPU mode (QVAC supports it, slower but still on-device)

### 2. Pick the model

Tradeoffs (numbers approximate, validate on your box):

| Model | Size (Q4 GGUF) | RAM | Latency (50-tok response) |
|---|---|---|---|
| Gemma 3-1B Q4 | ~700 MB | 2 GB | ~3 s CPU / ~0.5 s T4 |
| Gemma 3-4B Q4 | ~2.5 GB | 4 GB | ~7 s CPU / ~1 s T4 |
| Gemma 2-2B Q4 | ~1.4 GB | 3 GB | ~5 s CPU / ~0.7 s T4 |

**Default choice: Gemma 3-4B Q4** — better reasoning for the 70%
judging weight on depth + product value. Drop to 1B only if container
size becomes a deploy concern.

### 3. Build the brain service

Create `services/qvac_brain/`:

```
services/qvac_brain/
├── server.js            # HTTP server on :8088
├── prompts.js           # Risk-evaluation prompt templates
├── package.json         # @qvac/sdk + @qvac/llm-llamacpp pinned
└── README.md            # Service ergonomics
```

**Endpoint contract** (must match what webapp + CLI consume):

- `GET  /healthz` → `{ ok: true, model: "gemma-3-4b-q4", loaded: true, ms_per_tok: 12 }`
- `POST /evaluate` body:
  ```json
  { "scenario": "loan_request", "context": { /* scenario-specific */ } }
  ```
  response:
  ```json
  {
    "decision": "approve" | "reject" | "negotiate",
    "risk_score": 0.0..1.0,
    "reasoning": "free-form LLM output, <120 tokens",
    "model": "gemma-3-4b-q4",
    "ms_inference": 1234
  }
  ```

Implement at least three `scenario` types in `prompts.js`:
- `loan_request` — Swarm flash loan eval (matches existing README narrative)
- `submit_order` — pre-trade risk check before `submit_order` action
- `merchant_trust` — incoming Blink payment trust evaluation

Each scenario has a system prompt + structured user prompt + JSON
response schema enforcement (use llama.cpp grammar mode if available, or
post-parse).

### 4. Containerize

`infra/Containerfile.qvac`:

```dockerfile
FROM node:22-bookworm-slim

# Vulkan loader + build deps for native modules (llama.cpp)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 vulkan-tools build-essential cmake git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY services/qvac_brain /work
RUN npm ci --omit=dev

# Bake model into the image (build-time download; reproducible)
ARG MODEL_URL=https://models.qvac.io/google/gemma-3-4b-it-q4_0.gguf
ARG MODEL_SHA256=aeda25e63ebd698fab8638ffb778e68bed908b960d39d0becc650fa981609d25
RUN curl -L -o /opt/model.gguf "$MODEL_URL" \
    && echo "$MODEL_SHA256  /opt/model.gguf" | sha256sum -c
ENV QVAC_MODEL_PATH=/opt/model.gguf

EXPOSE 8088
CMD ["node", "server.js"]
```

**Image size budget**: ~4-5 GB (3 GB model + 1 GB base + 1 GB deps).

### 5. Zig rewrite path (performance option)

If wall-clock latency from Node + JS startup matters for demo, the agent
MAY rewrite the inference layer in Zig: bind to llama.cpp's C API via
`@cImport`, expose the same HTTP contract via Zig's `std.http.Server`.

This is **optional** and only worth doing if benchmarks show Node startup
or JS interop dominates. The judging criterion is *"meaningful integration
of QVAC's local AI capabilities"* — a Zig HTTP shell around llama.cpp is
still QVAC compliant (it's the same engine) and gives Tether-judges a
narrative win: *"we rewrote the inference layer for performance, still
using QVAC's stack underneath"*.

**Decision rule**: keep Node if `/evaluate` latency on the chosen model
is <2s end-to-end. Migrate to Zig only if it's >3s.

### 6. Wire into xB77

#### CLI

Add `cli/commands/brain.zig`:

```zig
xb77 brain status                    # GET /healthz
xb77 brain evaluate <scenario> --context <json>
xb77 brain swarm-decide <peer> <amount>  # convenience for the loan scenario
```

Each subcommand POSTs to `${XB77_BRAIN_URL:-http://127.0.0.1:8088}/...`
and prints the JSON response with simple ANSI styling.

#### Webapp

- Add a **Brain** widget to the dApp shell (top bar or new tab)
- Badge: `● running on-device · QVAC` (green when `/healthz` passes)
- Demo button: *"Evaluate scenario"* with 3 preset scenarios + free text
- Show `risk_score` as a gauge, `reasoning` as a chat bubble
- Visible model name + ms_inference

#### Gateway integration

Before `submit_order` lands an order, the gateway optionally calls the
brain for a pre-trade risk check. **Implementation hint**: this can be
either:

- Server-side (gateway calls brain) — coupled, breaks the on-device promise
- Client-side (CLI/webapp calls brain before signing the action) —
  preserves on-device, gives the agent autonomy

**Choose client-side**. The brain decision is a local concern; the
gateway just records the signed result. Document this architectural
choice in the spec README.

### 7. Deliverables checklist (acceptance gate)

- [ ] `infra/Containerfile.qvac` builds clean
- [ ] `services/qvac_brain/` runs and serves `/healthz` + `/evaluate`
- [ ] `xb77 brain {status,evaluate,swarm-decide}` works against the container
- [ ] Webapp Brain widget shows live model status + can fire `/evaluate`
- [ ] `scripts/smoke_qvac.sh` exists and passes (container up + 3 scenario
      evaluations + non-stub response text)
- [ ] `scripts/demo_e2e.sh` extended to include a Brain evaluation step
- [ ] `README.md` has a *"Sponsor: Tether QVAC"* section explaining the
      integration, with a screenshot of the Brain widget
- [ ] Commit on `sponsor/qvac` branch with subject `feat(qvac): tether
      local-AI brain — on-device risk evaluator`

### 8. Cost / time budget

- Cloud GPU dev: 4-6 hours T4 = **~$2 USD**
- Container build + push: included in above
- Local pull + smoke: 30 min on the demo box (image pull is the long pole)
- Wiring CLI + webapp: ~2 hours of code

## Open questions the agent must resolve

1. **Exact model URL + SHA256**: pick from https://huggingface.co/ggml-org
   or `bartowski/gemma-2-2b-it-GGUF` etc. Pin the SHA256 in the Dockerfile.
2. **QVAC SDK exact version**: pin in `package.json`. Inspect what
   `@qvac/sdk` and `@qvac/llm-llamacpp` actually export (use `bun` or
   `npm` to introspect after install).
3. **JSON-schema enforcement**: does `@qvac/llm-llamacpp` expose grammar
   or function-calling? If yes, use it for structured `/evaluate`
   responses. If no, post-parse with retry-on-malformed.
4. **GPU vs CPU runtime detection**: container should auto-detect at boot
   and log which backend it's using. Don't fail if no GPU — use CPU.
5. **Model warmup**: serve `/healthz` only after the model is loaded and
   one warmup token has been generated. Document the cold-start time.

## What this spec must NOT do

- Don't call out to OpenAI / Anthropic / any cloud LLM as a fallback. The
  whole point is on-device. A fallback to cloud disqualifies the
  submission.
- Don't bake API keys into the container. There are none.
- Don't store user data anywhere. The brain is stateless; each
  `/evaluate` is independent.

## Reference

- Tether QVAC docs: https://docs.qvac.tether.io
- QVAC GitHub: https://github.com/tetherto/qvac
- Tether WDK (related, optional bonus): https://wdk.tether.io
- Side track listing: Superteam Earn (find the live URL when submitting)
- xB77 narrative tie-in: `README.md` Section "Swarm Intelligence (Agentic Flash Loans)"

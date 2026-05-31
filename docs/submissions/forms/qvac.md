# QVAC / Tinfoil — Frontier Track Submission

## Placeholders to fill before pasting

- `<YOUTUBE_URL>` — unlisted YouTube link to `demo_qvac.mp4`
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
xB77 — Sovereign Agent Reasoning, On-Device First
```

## Project Description

```
xB77's brain is a Zig-native reasoning layer that decides — locally, before any network call — what payment rail an agent takes, what privacy floor it enforces, and whether a transaction needs human sign-off. The architecture is QVAC (Quantitative Valve for Autonomous Commerce) and lives in core/intelligence/brain.zig.

Three-layer reasoning hierarchy:
  1. NATIVE LLM (planned): native llama.cpp integration via deps/llama.h, gated behind QVAC_USE_NATIVE_LLM. The code is prepared and commented to avoid linker pain in the hackathon window.
  2. TS SHIM (active): http://127.0.0.1:8088/evaluate runs the @qvac/sdk in services/qvac_brain/. The loadModel call for Gemma 3 4B Q4_0 is wired but currently commented — the shim returns high-fidelity heuristic responses that match the structured contract.
  3. HEURISTIC FALLBACK: pure-Zig decision tree in brain.interpret() that produces the same BrainInsight (decision, risk_score, reasoning, mission_hash, zk_proof_tag, RAG hits) regardless of network state.

The kill-switch test sells it: same `xb77 brain "transfer 50 SOL"` command runs through layer 2 with the shim alive, then we curl-bomb the port and re-run — layer 3 picks up with no perceptible quality drop. The brain doesn't stall; the agent doesn't hang.

Constitutional gating: every decision consults core/security/constitution.zig:Constitution, which carries flags like force_hft_rail (routes a payment through MagicBlock PER vs standard L1) and privacy_floor. These are not soft preferences — the brain mathematically gates execution on them.

Output is a structured BrainInsight:
  • decision: approve / negotiate / reject
  • risk_score: 0.0 - 1.0
  • reasoning: full reasoning chain (sent to telegram-shaped report)
  • mission_hash: 12-char hex of the directive identity
  • zk_proof_tag: "qvac_local_verified_airgapped" or similar — Noir witness over (constitution_hash, decision, agent_pubkey) ready to land

Honest delta: layer 1 (native llama.cpp inference) is not running in this hackathon submission. The shim's loadModel({ modelSrc: GEMMA_3_4B_IT_Q4_0 }) call is commented out at services/qvac_brain/server.ts:22-25 — uncomment, deploy on Runpod T4 (~$0.30/hr), and the actual Gemma inference comes online without any other change in the Zig agent. The architecture is model-ready; we chose heuristic-fidelity for the demo to ensure determinism.
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

(xb77_core — where the brain's approved decisions actually pay)

## Anything Else?

```
Brain code:           core/intelligence/brain.zig
TS shim:              services/qvac_brain/server.ts (port :8088)
Constitution:         core/security/constitution.zig
Spec:                 docs/specs/sponsors/qvac.md
Submission writeup:   docs/submissions/QVAC.md

To run the live shim:
  cd services/qvac_brain && bun install && bun run server.ts

To test the kill-switch resilience yourself:
  XB77_USE_BRAIN_SHIM=1 ./zig-out/bin/xb77 -p demo brain "transfer 50 SOL"
  fuser -k 8088/tcp
  XB77_USE_BRAIN_SHIM=1 ./zig-out/bin/xb77 -p demo brain "transfer 50 SOL"
  # Same structured output, just with "Shim Unreachable. Falling back."

The trident integration (zig build trident-smoke) shows the brain feeding decisions into the MagicBlock PER lane vs standard rails based on constitutional flags.
```

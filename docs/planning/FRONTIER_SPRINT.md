# xB77 Frontier Sprint: Mission Control (Deadline: May 11, 2026)

## 1. Vision & Strategy
Build the "Sovereign Agent Gateway" — a high-performance, easy-deploy interface for agents that bridges Solana mainnet with high-velocity ZK-verified intent execution.

- **Frontend/Gateway:** Cloudflare Workers (Zig/WASM) + Telegram Bot.
- **Core Engine:** Zig-based Z-Node for state persistence and AWP streaming.
- **Identity:** SNS-integrated registry.
- **Intelligence:** QVAC-powered local agent directives.

## 2. Workstreams (Parallel Execution)

### WS 1: Core & Stability (Node: Engine)
- **Goal:** Stable Z-Node core and passing test suite.
- **Milestones:**
  - [ ] Fix `cmt_keccak256` in `compression.zig`.
  - [ ] Pass all 17 tests.
  - [ ] Standardize `agent.toml` schema for auto-provisioning.

### WS 2: Gateway & Deployment (Node: Gateway)
- **Goal:** Consumer-facing Agent deployment via Telegram.
- **Milestones:**
  - [ ] Deploy Cloudflare Worker (Zig) for Telegram bot.
  - [ ] Implement `/deploy` flow (Blink integration + Z-Node provision).
  - [ ] Infrastructure payment billing logic (2.011% tax).

### WS 3: Identity & Policy (Node: Trust)
- **Goal:** SNS-backed agent identity and on-chain Constitution.
- **Milestones:**
  - [ ] SNS subdomain registry integration.
  - [ ] Constitution (Solana program) rule enforcement (SNS-aware).

### WS 4: Intelligence (Node: Brain)
- **Goal:** Local QVAC directive parsing.
- **Milestones:**
  - [ ] Directives (NL) -> AWP Intent generation pipeline.
  - [ ] RAG on Constitution rules for intent validation.

### WS 5: Agent Commerce (Node: APP / Merchant)
- **Goal:** Implement the Agent Payments Protocol (APP) for full-lifecycle commerce.
- **Milestones:**
  - [ ] Extend AWP with APP messages: `Quote`, `Hire`, `Escrow`, `Dispute`.
  - [ ] Merchant "Two-Click" onboarding (Auto-Blink generator).
  - [ ] Integration with MagicBlock for private Escrow logic.

## 3. Communication & Integration
- **Interfaces:** `core/protocol/types.zig` is the source of truth for all modules.
- **Integration Policy:** No "Frankenstein" commits. Every merge to main MUST pass `zig build test`.
- **Sync:** Daily status check-in at session start.

## 4. Submission Checklist (Frontier T1)
- [ ] MagicBlock PER integration (PER session setup).
- [ ] SNS registry flow (Domain acuñada).
- [ ] Tether QVAC local directive parsing (Air-gapped demo).
- [ ] 100xDevs overall submission quality (README + Video).

---
*Mission: Sovereignty through speed and machine-verified trust.*

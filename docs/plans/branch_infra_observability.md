# Branch Plan: Infra + Observability (Helius + Receipts)

## Objective
Provide reliable infrastructure (Helius RPC/webhooks) and receipts (Light or mock) for the demo, aligned with the SDK/MCP payment flow and the on-chain gateway/receipts path, with Hub as the command plane for observability.

## Scope
- Helius RPC integration and priority fee config (smoke test + env guidance).
- Optional Helius webhooks for observability.
- Receipts layer using Light or a mock compatible interface, including CPI wiring.
- SDK receipts adapter + MCP list/latest alignment.
- Demo scripts for devnet/localnet runs (e2e + receipt builder).
- Localnet infra scripts for Light validator when devnet is unstable.
- Hub wiring to surface gateway/payment/receipt state for demo observability (merchant views as extensions of the Hub).

## Out of Scope
- Payment rail logic details (handled in Payments branch).
- New Hub UI features beyond wiring observability into existing flows.

## Milestones
1) Helius RPC path validated with a simple tx (smoke test).
2) Receipt write path implemented (Light or mock) and surfaced to SDK receipts module.
3) Demo script produces logs + receipts via gateway -> payment -> receipt (SDK/MCP).

## Deliverables
- Config guidance for Helius endpoints + smoke test script.
- Receipt adapter + CPI builder script.
- MCP/SDK receipt integration notes (list/latest).
- Demo script for e2e flow.
- Hub panel that surfaces live receipts, balances, and recent payment status (merchant-focused).

## Dependencies
- Helius API key / endpoint.
- Light RPC endpoints (compression/prover) or localnet validator.
- On-chain gateway/receipts programs deployed.
- MCP/SDK receipt interface availability.

## Risks
- Light infra instability or RPC rate limits.
- Webhook setup friction.
- Receipt interface drift between SDK/MCP and on-chain programs.

## Fallback
- Mock receipts stored in standard accounts + local logs.
- Expose receipts via SDK list/latest with mocked data if Light is unstable.
- Use localnet Light validator scripts for demos.

## Decisions
- Demo target: localnet first; devnet only if time allows.
- Merchant hub: treated as an extension of the main Hub UI (merchant-focused panels).

## Breakpoints
- BP1: Helius RPC tx confirmed.
- BP2: Receipt written or mocked and visible via SDK receipts.
- BP3: Demo script produces observable output.

## TODOs (Reproducible)
- Standardize RPC/Helius/Light env vars across SDK/MCP/Hub and document defaults.
- Run Helius smoke test and capture a reference signature + RPC URL.
- Validate Light receipts with `sdk/scripts/build_receipt_light.ts` (devnet) and store a sample payload.
- Run `sdk/scripts/demo_e2e.ts` and verify SDK receipts list/latest output.
- Wire Hub to MCP/SDK state for receipts, balances, and latest payment status.
- Validate Hub rendering with latest receipts and a recent payment.
- Prepare localnet Light fallback (scripts + minimal runbook).
- Document the demo execution order (step-by-step, reproducible).

## 7-Day Execution Checklist (Localnet Demo)
Day 1: Hub + MCP wiring
- Run MCP in HTTP mode and register agent in Hub (`/tool` endpoint).
- Verify Hub observability panel shows balance/receipts via MCP tools.
- Consolidate env vars for MCP/SDK/Hub (`XB77_*`, `MCP_HTTP_PORT`).

Day 2: Receipts pipeline
- Run `sdk/scripts/build_receipt_light.ts` against localnet Light.
- Validate receipt payload + accounts JSON output.
- Confirm SDK receipt list/latest returns consistent data.

Day 3: E2E demo (localnet)
- Run `sdk/scripts/demo_e2e.ts` and capture output logs.
- Confirm gateway -> receipt path emits expected receipts.
- Capture a “golden run” transcript for demo.

Day 4: Merchant Hub extension
- Add/confirm merchant-focused labels and sections in Hub panel.
- Ensure merchant flow maps to receipts and balance state.

Day 5: Infra hardening
- Run Helius smoke test (for optional devnet path).
- Validate localnet Light fallback scripts and document runbook.

Day 6: Demo rehearsal
- Full dry run: Hub + MCP + demo flow.
- Record common failure cases and quick fixes.

Day 7: Final polish
- Freeze env + scripts + runbook.
- Final demo run and screenshots/logs.

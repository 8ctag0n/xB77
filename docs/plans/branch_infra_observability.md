# Branch Plan: Infra + Observability (Helius + Receipts)

## Objective
Provide reliable infrastructure (Helius RPC/webhooks) and receipts (Light or mock) for the demo, with reproducible scripts.

## Scope
- Helius RPC integration and priority fee config.
- Optional Helius webhooks for observability.
- Receipts layer using Light or a mock compatible interface.
- Demo scripts for devnet runs.

## Out of Scope
- On-chain program changes.
- Payment rail logic.
- MCP server orchestration.

## Milestones
1) Helius RPC path validated with a simple tx.
2) Receipt write path implemented (Light or mock).
3) Demo script produces logs + receipts.

## Deliverables
- Config guidance for Helius endpoints.
- Receipt adapter and script.
- README snippet for devnet demo.

## Dependencies
- Helius API key / endpoint.
- Light SDK access (if available).

## Risks
- Light infra instability.
- Webhook setup friction.

## Fallback
- Mock receipts stored in standard accounts + local logs.

## Breakpoints
- BP1: Helius RPC tx confirmed.
- BP2: Receipt written or mocked.
- BP3: Demo script produces observable output.

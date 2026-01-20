# Branch Plan: Infra + Observability (Helius + Receipts)

## Objective
Provide reliable infrastructure (Helius RPC/webhooks) and receipts (Light or mock) for the demo, aligned with the SDK/MCP payment flow and reproducible scripts.

## Scope
- Helius RPC integration and priority fee config.
- Optional Helius webhooks for observability.
- Receipts layer using Light or a mock compatible interface.
- MCP/SDK alignment for the gateway -> payment -> receipt flow.
- Demo scripts for devnet runs.

## Out of Scope
- On-chain program changes.
- Payment rail logic details (handled in Payments branch).

## Milestones
1) Helius RPC path validated with a simple tx.
2) Receipt write path implemented (Light or mock) and surfaced to SDK receipts module.
3) MCP/SDK demo script produces logs + receipts via gateway -> payment -> receipt.

## Deliverables
- Config guidance for Helius endpoints.
- Receipt adapter and script.
- MCP/SDK receipt integration notes (list/latest).
- README snippet for devnet demo.

## Dependencies
- Helius API key / endpoint.
- Light SDK access (if available).
- MCP/SDK receipt interface availability.

## Risks
- Light infra instability.
- Webhook setup friction.
- Receipt interface drift between SDK and MCP.

## Fallback
- Mock receipts stored in standard accounts + local logs.
- Expose receipts via SDK list/latest with mocked data if Light is unstable.

## Breakpoints
- BP1: Helius RPC tx confirmed.
- BP2: Receipt written or mocked and visible via SDK receipts.
- BP3: MCP demo script produces observable output.

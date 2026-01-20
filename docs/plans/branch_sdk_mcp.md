# Branch Plan: SDK Unified + MCP Server

## Objective
Ship a unified SDK and a local MCP wrapper so each agent can operate via a stable API that abstracts proof, credit state, and payments.

## Scope
- SDK package with modules: identity, credit_state, shadowwire, privacycash, receipts.
- Local MCP wrapper exposing tools like: agent.credit, agent.transfer_private, agent.pay, agent.status, agent.receipts.list, agent.receipts.latest, agent.state.get.
- MCP is tied to the agent runtime (CLI/local/devbox); not a shared multi-tenant backend.
- Thin orchestration over other branches (no heavy business logic here); MCP just surfaces SDK/agent actions.
- Orchestrate sequence: gateway -> payment -> receipt.
- ShadowWire wallet signature requirement handled by SDK wrapper.

## Out of Scope
- On-chain program implementation.
- Payment rail implementation details.
- Helius integration or receipts wiring (handled in Infra branch).
- Multi-tenant MCP service; defer to a future enterprise/gateway mode.

## Milestones
1) SDK skeleton + configs + example usage.
2) MCP server running with tool definitions.
3) End-to-end call from MCP to SDK adapters following gateway -> payment -> receipt.

## Adapter Expectations
- ShadowWire adapter must accept a `wallet.signMessage` hook and enforce transfer `type`.
- payment_request.currency maps to ShadowWire `token` (USD1 default).
- If ShadowWire throws `RecipientNotFoundError`, fallback to `external` transfer.
- Privacy Cash adapter should implement `deposit` + `withdraw` (SOL) and `depositSPL` + `withdrawSPL` (SPL).
- Privacy Cash requires `RPC_url` and `owner` in client setup.
- Privacy Cash returns `tx` on deposit/withdraw; map to `payment_result.tx_sig`.

## MCP Data Access Expectations
- MCP should expose recent receipts (latest and list) via SDK receipts module.
- MCP should expose latest agent state/credit snapshot for tooling (read-only).

## Deliverables
- SDK package with types and minimal docs.
- MCP server with tool registry and example prompts.
- Demo script that triggers one full flow.

## Dependencies
- Interfaces from Core Program and Payments branches.
- RPC config (Helius endpoint preferred).

## Risks
- MCP tool surface too broad or unstable.
- Version drift between SDK adapters.

## Fallback
- Expose minimal tool set (credit + transfer) and defer advanced flows.

## Breakpoints
- BP1: SDK usage example runs locally.
- BP2: MCP server answers a tool call.
- BP3: MCP tool triggers a real payment flow.

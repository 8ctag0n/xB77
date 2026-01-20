# Branch Plan: Core Program + Credit State (Arcium)

## Objective
Create a new on-chain program that integrates with the existing programs and anchors the flow: verify identity, update encrypted credit state, and emit a payment request that the SDK can fulfill.

## Scope
- New program scaffolding and instruction set (init, verify_and_credit, request_payment).
- Integration points with existing programs (CPI or shared state contracts).
- Explicit compatibility with `xb77_gateway` and `xb77_receipts`.
- Define interface contracts that allow SDK flow: gateway -> payment -> receipt.
- Arcium encrypted state model for agent credit lines (credit/debit).
- Minimal Noir proof verification hook (can be stubbed if verifier integration is blocked).

## Out of Scope
- ShadowWire or Privacy Cash SDK integration.
- MCP server and client SDK orchestration.
- UI or demo video.

## Milestones
1) Program skeleton and state layout finalized.
2) Credit line state update works (credit/debit).
3) Verify hook wired (real or stub) and request emitted.

## Integration Points
- `xb77_gateway` (preferred CPI): new program exposes `verify_and_credit` and is invoked by gateway after proof validation.
- `xb77_gateway` (fallback client-side): SDK calls `verify_and_credit` directly after a successful gateway verify.
- `xb77_receipts` (preferred CPI): new program calls receipts on payment request.
- `xb77_receipts` (fallback client-side): SDK writes receipts when CPI is blocked.
- Shared state: define PDA seeds so the new program can read/write credit line state without conflicting with existing PDAs.

## Interface Contract v0 (gateway -> payment -> receipt)
**payment_request**
- request_id (u64 or bytes32)
- agent_id (pubkey or hash)
- amount (u64)
- currency (USD1/USDC/other enum)
- vendor (pubkey or hash)
- memo_hash (bytes32, optional)
- proof_ref (bytes32)

**payment_result**
- request_id
- tx_sig
- status (success/failed)
- paid_amount
- timestamp

**receipt_payload**
- request_id
- vendor
- item_hash
- amount
- metadata_hash
- payment_tx_sig

Sequence:
1) Gateway validates proof and emits payment_request.
2) SDK executes private payment (ShadowWire or Privacy Cash) and returns payment_result.
3) SDK writes receipt (Light or mock) using receipt_payload.

## Deliverables
- Program source + build scripts.
- One local/devnet script to init and update credit state.
- README snippet with commands.

## Dependencies
- Arcium state SDK or schema definition.
- Noir verifier address or stub interface.
- Existing program interfaces (`xb77_gateway`, `xb77_receipts`).

## Risks
- Arcium API or encrypted state schema unclear.
- CPI vs client-side update complexity.

## Fallback
- Use a mock encrypted blob with deterministic hashing to preserve interface.

## Breakpoints
- BP1: Program builds and deploys.
- BP2: Credit state updates verified by script.
- BP3: Payment request emitted and consumed by SDK.

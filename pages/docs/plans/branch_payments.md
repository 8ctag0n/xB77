# Branch Plan: Payments (ShadowWire + Privacy Cash)

## Objective
Integrate private payment rails for the demo: ShadowWire private transfers and Privacy Cash SDK flows, both callable from the unified SDK surface.

## Scope
- ShadowWire transfer integration (bulletproofs, private amount).
- Privacy Cash SDK integration (private lending/whale wallet flow).
- USD1 usage where supported by the SDKs.
- Payment sequence contract: gateway -> payment -> receipt (SDK-driven).

## Out of Scope
- On-chain program changes (handled in Core Program branch).
- MCP server integration (handled in SDK/MCP branch).
- Light receipts integration (handled in Infra branch).

## Milestones
1) ShadowWire transfer works in devnet or in a mock harness.
2) Privacy Cash flow works in devnet or in a mock harness.
3) Common interface contract documented for SDK consumption (gateway -> payment -> receipt).

## Interface Mapping (ShadowWire)
- payment_request.amount -> `transfer.amount` (ShadowWire uses token units, not smallest units).
- payment_request.currency -> `transfer.token` (USD1 supported).
- payment_request.agent_id -> `transfer.sender` (wallet address).
- payment_request.vendor -> `transfer.recipient` (wallet address).
- payment_request.memo_hash -> optional `transfer.memo` (if SDK supports metadata, else store in receipt_payload.metadata_hash).
- payment_result.tx_sig <- `result.tx_signature`.
- payment_result.paid_amount <- `transfer.amount`.
- payment_result.status <- success if `tx_signature` returned, else failed.
- Wallet signature auth required: SDK must pass `wallet.signMessage`.

## Notes (ShadowWire)
- Transfer `type` choice:
  - `internal` when recipient is a ShadowWire user (amount hidden).
  - `external` for non-users (amount visible, sender anonymous).
- Proof generation default: backend proofs; client-side proofs optional.

## Interface Mapping (Privacy Cash)
- payment_request.amount -> `deposit.lamports` (SOL) or `depositSPL.base_units`/`amount` (SPL).
- payment_request.currency -> SPL mint selection (USDC/USDT or USD1 if available).
- payment_request.agent_id -> `owner` in PrivacyCash client (private key or keypair).
- payment_request.vendor -> `withdraw.recipientAddress`.
- payment_result.tx_sig <- `withdraw` response `tx` (signature string).
- payment_result.paid_amount <- `withdraw` amount (lamports or base_units).
- payment_result.status <- success if withdraw returns `tx`.
- Optional metadata from withdraw: `isPartial`, `fee_in_lamports` or `fee_base_units`.

## Notes (Privacy Cash)
- Flow is 2-step: deposit -> withdraw to recipient.
- For SPL tokens, use `depositSPL` / `withdrawSPL` with mint address.
- SDK uses a relayer backend and returns `{ tx: signature }` for deposits.

## Deliverables
- Payment adapter modules with example scripts.
- README snippet for each flow.
- Minimal mock layer if SDKs are unstable.

## Dependencies
- ShadowWire SDK + example reference.
- Privacy Cash SDK + example reference.

## Risks
- SDK instability or missing localnet support.
- Wallet/key handling friction for demo.

## Fallback
- Mock payment execution with signed memo + interface-compatible return.

## Breakpoints
- BP1: ShadowWire transfer success path.
- BP2: Privacy Cash flow success path.
- BP3: Unified adapter surface validated by SDK branch.

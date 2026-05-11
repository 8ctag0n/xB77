---
pageClass: is-legacy-page
---
# Worktree B Plan: Vault (C-SPL) + Light Receipts

## Objective
Ship the vault and private audit trail path: C-SPL confidential treasury + Light Protocol compressed receipts.

## Scope
- C-SPL vault account creation and transfer flow (real or mock, but API-compatible).
- Light Protocol receipt schema and write path.
- Gateway program updates to call these integrations after verification.

## Out of Scope
- Privacy Cash / ShadowWire payment path (Worktree A).
- UI polish or demo video (later).

## Milestones
1) **Vault baseline**
   - Define vault accounts and minimal config in gateway state.
   - Implement C-SPL transfer (or mock with feature flag).
2) **Light receipts**
   - Define receipt payload (vendor/item/amount/hash).
   - Write compressed receipt on-chain.
3) **Gateway flow**
   - Sequence: verify -> transfer -> receipt.
   - Add tests or localnet script to validate.

## Deliverables
- Gateway instruction flow updated.
- Minimal scripts to run vault + receipt demo.
- README update describing the flow.

## Dependencies
- Arcium C-SPL docs / SDK.
- Light Protocol SDK.

## Risks
- C-SPL CPI complexity; localnet support gaps.
- Light SDK API changes.

## Fallback
- Mock vault transfer + local receipt log while keeping API contracts.

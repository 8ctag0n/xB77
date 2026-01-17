# Worktree A Plan: Privacy Cash / ShadowWire Integration

Status: Completed (ShadowWire path integrated; demo ready)

## Objective
Deliver a working private payment path (USD1/ShadowWire/Privacy Cash) triggered from the gateway flow, usable for demo and prize track.

## Scope
- Integrate Privacy Cash SDK or ShadowWire transfer path.
- Connect to gateway verify output (client-side or CPI) for a real private transfer.
- Provide a minimal CLI/SDK entry point for demo (`agent.pay`).

## Out of Scope
- Full treasury/vault implementation (C-SPL).
- Light Protocol receipts (handled in Worktree B or later).

## Milestones (Completed)
1) **Discovery & SDK setup**
   - Compared ShadowWire vs Privacy Cash; selected ShadowWire for USD1 support.
   - Identified SDK/API entry points for private transfer.
2) **Gateway linkage**
   - Defined integration point (client-side, post-verify).
   - Implemented callable function with inputs from gateway state.
3) **Demo path**
   - SDK entry point: `PrivacyAgent.pay(...)`.
   - Scripted demo: `sdk/scripts/demo_payment.ts` and `make demo-payment`.

## Deliverables (Shipped)
- Working private transfer call via ShadowWire.
- SDK structure split: `identity/` and `economy/`.
- Manual signing flow in `AgentWallet` for ShadowWire compatibility.
- Unified entry point: `PrivacyAgent` (`agent.pay`).
- README snippet and Makefile target for demo.
- Demo script: `sdk/scripts/demo_payment.ts`.

## Dependencies
- ShadowWire SDK docs.
- USD1 integration details.

## Risks
- SDK instability or lack of localnet support.
- CPI path too complex; fallback to client-side tx.

## Fallback
- Mock transfer with on-chain memo and receipt for demo, while showing SDK call path.

## Notes
- Localnet flow validated via demo script and Makefile target.

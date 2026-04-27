# Worktree A Plan: Privacy Cash / ShadowWire Integration

## Objective
Deliver a working private payment path (USD1/ShadowWire/Privacy Cash) triggered from the gateway flow, usable for demo and prize track.

## Scope
- Integrate Privacy Cash SDK or ShadowWire transfer path.
- Connect to gateway verify output (client-side or CPI) for a real private transfer.
- Provide a minimal CLI/SDK entry point for demo (`agent.pay`).

## Out of Scope
- Full treasury/vault implementation (C-SPL).
- Light Protocol receipts (handled in Worktree B or later).

## Milestones
1) **Discovery & SDK setup**
   - Confirm SDK/API entry points for private transfer.
   - Minimal localnet/devnet test transfer.
2) **Gateway linkage**
   - Define integration point (post-verify client-side or program CPI).
   - Implement callable function with inputs from gateway state.
3) **Demo path**
   - CLI command or SDK function: `agent.pay(amount, recipient)`.
   - Scripted flow that can be run in demo.

## Deliverables
- Working private transfer call.
- README snippet with commands.
- Demo script (or Makefile target).

## Dependencies
- Privacy Cash / ShadowWire SDK docs.
- USD1 integration details.

## Risks
- SDK instability or lack of localnet support.
- CPI path too complex; fallback to client-side tx.

## Fallback
- Mock transfer with on-chain memo and receipt for demo, while showing SDK call path.

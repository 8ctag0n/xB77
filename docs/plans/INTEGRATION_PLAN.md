# Integration Plan: 4 Branches -> E2E Demo

## Objective
Integrate the four parallel branches into a working end-to-end flow: gateway -> payment -> receipt, exposed through the SDK and MCP server.

## Phase 0: Contracts and Interfaces (Day 1)
- Lock interface contract v0 and adapters.
- Confirm payment sequence: gateway -> payment -> receipt.
- Define config variables (RPC, Helius, keys).

**Breakpoint:** Interface contract v0 approved and shared across branches.

## Phase 1: Payments + SDK/MCP (Days 1-4)
- Branch Payments: ShadowWire adapter + Privacy Cash adapter.
- Branch SDK/MCP: SDK wrappers + MCP tools for credit/pay/status.
- Ensure adapters map to Interface Contract v0.

**Breakpoint:** SDK can call ShadowWire and Privacy Cash via a single `agent.pay` path.

## Phase 2: Core Program + Infra (Days 3-6)
- Branch Core Program: new program skeleton and credit state.
- Branch Infra: Helius RPC config + receipts (Light or mock).
- Expose receipt adapter in SDK.

**Breakpoint:** SDK can produce receipt payloads (mock ok), Helius RPC validated.

## Phase 3: Integration + Demo (Days 6-9)
- Merge branch outputs into integration branch.
- Run E2E script: verify -> credit update -> payment -> receipt.
- Add fallback paths (client-side receipts, external transfer).

**Breakpoint:** End-to-end demo script runs on devnet.

## Phase 4: Polish + Submission (Days 9-10)
- Update README with runnable steps.
- Record demo walkthrough.
- Smoke tests with default configs.

**Breakpoint:** Demo + docs ready for submission.

## Fallbacks
- If Light blocked: mock receipts in standard accounts.
- If ShadowWire internal fails: external transfer.
- If Privacy Cash relayer unstable: reduce flow to deposit-only + mock withdraw.

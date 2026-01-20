# Mega Execution Plan: Core Program & Infra Stabilization

**Context:** Merging "Branch Core Program" objectives with immediate "Worktree B" infrastructure fixes.
**Date:** Jan 20, 2026

## Phase 0: Infrastructure Stabilization (The "Now")
*Goal: Fix the local development environment to support Light Protocol (ZK Compression) binaries so we can eventually build the Receipt flow.*

1.  **Finalize Validator Script**:
    *   Complete `scripts/localnet/start-validator-light.sh` (as seen in git diff).
    *   Ensure it correctly loads:
        *   `Light System Program`: `SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7`
        *   `Compressed Token`: `cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m`
        *   `Account Compression`: `compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq`
2.  **Commit Research & Fixes**:
    *   Commit the updated `RESEARCH_REPORT_B.md` (documenting the binary loading strategy).
    *   Commit the new start script.
3.  **Verify**:
    *   Run `./scripts/localnet/start-validator-light.sh`.
    *   Verify RPC is up and programs are loaded.

## Phase 1: Core Program Scaffolding
*Goal: Create the `xb77_core` program structure defined in the branch plan.*

1.  **Workspace Setup**:
    *   Initialize `onchain/programs/xb77_core`.
    *   Update root `Cargo.toml` to include the new member.
2.  **State Definition (Arcium Style)**:
    *   Define `CreditLine` struct:
        *   `owner`: Pubkey (Agent ID)
        *   `balance`: u64 (Encrypted placeholder or plain u64 for v0)
        *   `limit`: u64
        *   `last_update`: i64
    *   Define `CoreConfig` (Global registry).
3.  **Instruction Interface**:
    *   `Initialize`: Setup global config.
    *   `RegisterAgent`: Init credit line for an agent.
    *   `VerifyAndCredit`: The critical hook called by Gateway.

## Phase 2: Logic & Integration
*Goal: Connect the Gateway's Badge Proof to the Core's Credit System.*

1.  **Gateway Integration**:
    *   Implement `verify_and_credit` in `xb77_core`.
    *   Update `xb77_gateway` to (optionally) CPI into `xb77_core` upon successful badge verification.
2.  **Payment Logic**:
    *   Implement `request_payment` in `xb77_core`.
    *   Logic: Check `CreditLine` balance -> Deduct -> Emit `PaymentRequest` event.
    *   *Constraint*: This event is what the SDK listens to.

## Phase 3: The "Receipt" Loop (SDK)
*Goal: Close the loop using the infrastructure from Phase 0.*

1.  **SDK Update**:
    *   Listen for `PaymentRequest` events.
    *   (Mock) Execute payment.
    *   (Real) Create **Light Protocol Receipt** using the local binaries from Phase 0.
2.  **End-to-End Test**:
    *   Script: `scripts/demo_full_flow.ts`
    *   Flow: `Verify Badge` -> `Core Credit Update` -> `Payment Request` -> `SDK Receipt`.

---

## Execution Queue

### Step 1: Commit Current Work (Infra)
- [ ] Save `scripts/localnet/start-validator-light.sh`
- [ ] Save `RESEARCH_REPORT_B.md`
- [ ] Git Commit: "chore: fix localnet validator with manual light binary loading"

### Step 2: Scaffold Core
- [ ] `cargo new onchain/programs/xb77_core --lib`
- [ ] Define `CreditLine` state.

### Step 3: Connect Gateway
- [ ] Implement `VerifyAndCredit` instruction.

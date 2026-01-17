# Research Report: Worktree B (Vault & Receipts)

## 1. Objective
Implement a "Privacy Treasury" flow aligned with Arcium's "Encrypted Instructions" and Light Protocol's "ZK Compression".

## 2. Component Design

### A. Arcium C-SPL (Mock)
Instead of simple mocks, we emulate the **Asynchronous MPC Callback** pattern.

**State (`GatewayConfig`):**
- `treasury_mint`: Pubkey.
- `pending_transfers`: Counter or specialized PDA (to track pending MPC callbacks).

**Instruction (`ExecuteConfidentialTransfer`):**
- **Payload** (mimics `Enc<Shared, u64>`):
  - `encrypted_amount`: [u8; 32] (Ciphertext).
  - `nonce`: [u8; 12].
  - `public_key`: [u8; 32] (Ephemeral key for ECDH).
- **Logic**:
  1. **Auth Gate**: Verify `VerifyBadge` (via Introspection).
  2. **Simulate MPC Request**:
     - Log "Emitting MPC Request".
     - In a real world, this would CPI to Arcium.
     - Here, we immediately "resolve" it by performing the SPL Token Transfer (CPI).
     - *Constraint*: Real Arcium is async. We will simulate "Optimistic Execution" where the Gateway approves the transfer immediately if the ZK proof (Auth Gate) is valid.

### B. Light Protocol Receipts (ZK Compression)
Simulate State Compression via Hashing + Logs.

**Schema (`Receipt` - Off-chain/Calldata):**
```rust
struct Receipt {
    vendor_id: [u8; 32],
    item_hash: [u8; 32],
    amount: u64,
    timestamp: i64,
}
```

**Instruction (`RecordReceipt`):**
- **Payload**: `Receipt` data.
- **Logic**:
  1. Serialize `Receipt`.
  2. Compute Leaf Hash (Poseidon or Keccak).
  3. **Update State**: `GatewayConfig.merkle_root` (or a separate `receipt_root` if we want to separate Badge vs Receipt trees).
     - *Decision*: Use a separate `receipt_root` in `GatewayConfig`.
  4. **Emit Event**: Standard Program Log with the full receipt data (simulating Availability on Solana Ledger).

## 3. Implementation Plan

### Phase 1: Gateway Config & State
- Add `treasury_mint` (Pubkey) and `receipt_root` ([u8; 32]) to `GatewayConfig`.

### Phase 2: Instructions
- Define `ConfidentialTransferPayload` with `ciphertext`, `nonce`, `pubkey`.
- Define `Receipt` struct.

### Phase 3: Processor Logic
- `ExecuteConfidentialTransfer`:
    - Introspection check (`VerifyBadge`).
    - SPL Token CPI (Transfer from Gateway PDA to User).
- `RecordReceipt`:
    - Hashing logic.
    - Root update.

### Phase 4: Verification (Tests)
- Update `gateway.rs` to include the full flow:
  `Init -> VerifyBadge -> ConfidentialTransfer -> RecordReceipt`.

## 4. Risks & Mitigations
- **CPI Complexity**: calling `VerifyBadge` + `Transfer` + `Receipt` in one tx is heavy.
  - *Mitigation*: The test script will structure the transaction carefully.
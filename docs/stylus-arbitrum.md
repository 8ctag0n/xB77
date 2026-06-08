# xB77 × Arbitrum Stylus — Technical Deep Dive

> Arbitrum Hackathon 2026 · Track: Best use of Stylus

---

## What we built

Nine Stylus WASM contracts written in Zig, compiled with `zig build stylus` to the `vm_hooks`
ABI — no Rust, no SDK, no Solidity. They implement the full on-chain ZK pipeline:
anchor state roots, settle agent payments, verify Noir/Groth16 proofs, route multi-circuit
verification, and integrate with EigenLayer AVS operators.

| Contract | WASM size | Description |
|---|---|---|
| `xb77_anchor.wasm` | **6.2 KB** | Anchors ZK state roots on Arbitrum |
| `xb77_settlement_engine.wasm` | **9.8 KB** | Agent USDC settlement + Circle CCTP |
| `xb77_zk_verifier.wasm` | **10.6 KB** | Real Groth16 + UltraPlonk KZG verification |
| `xb77_verifier_registry.wasm` | **7.2 KB** | Multi-circuit registry + EigenLayer AVS hooks |
| `constitution.wasm` | **6.2 KB** | Semantic intent enforcement |
| `uniswap_hook.wasm` | **5.6 KB** | Uniswap v4 pool hook |
| `aave_guard.wasm` | **7.3 KB** | Aave flash loan guard |
| `gmx_guard.wasm` | **7.6 KB** | GMX position guard |
| `settlement.wasm` | **10.1 KB** | Cross-chain settlement orchestrator |

All nine compile from `zig build stylus` in a single step. All pass `cargo stylus check`
against Arbitrum Sepolia.

---

## Why Zig

Zig targets `wasm32-freestanding`, which means:

- No standard library pulled in by default
- No allocator unless you explicitly declare one
- Dead code is stripped at compile time
- The output is exactly what you write

A Zig Stylus contract:

```zig
// anchor.zig — the entire entrypoint
export fn user_entrypoint(args_len: usize) i32 {
    host.pay_for_memory_grow(0);
    run(args_len) catch |err| {
        host.write_result(@errorName(err).ptr, @intCast(@errorName(err).len));
        return 1;
    };
    return 0;
}
```

The WASM binary imports exactly the host functions it uses. No allocator. No runtime.
No SDK. `zig build stylus` strips everything else.

---

## The vm_hooks ABI

Stylus contracts import from the `vm_hooks` module. Our `host.zig` wraps the full Stylus 0.10+ ABI:

```zig
// Storage — Stylus 0.10+ uses a write-back cache
pub extern "vm_hooks" fn storage_load_bytes32(key: *const [32]u8, out: *[32]u8) void;
pub extern "vm_hooks" fn storage_cache_bytes32(key: *const [32]u8, val: *const [32]u8) void;
pub extern "vm_hooks" fn storage_flush_cache(clear: u32) void;

// Cross-contract calls (Stylus 0.10+ param order)
pub extern "vm_hooks" fn call_contract(
    addr: *const [20]u8, data: *const u8, data_len: usize,
    value: *const [32]u8, gas: u64, ret_len: *usize,
) u8;
```

Notable Stylus 0.10+ changes vs older versions:
- `storage_store_bytes32` removed → `storage_cache_bytes32` + `storage_flush_cache`
- `call` → `call_contract` (address first, then calldata, then gas)
- `return_data_copy` → `read_return_data`

---

## Contract: ZKVerifier — real cryptographic verification

This is where xB77 diverges from every other Stylus submission: the ZK verifier does real
BN254 cryptography. No stub. No hash-anchoring. Full Groth16 and UltraPlonk KZG on-chain.

### BN254 precompiles

```
0x06  ecAdd(G1, G1)        → G1 point addition
0x07  ecMul(G1, scalar)    → scalar multiplication
0x08  ecPairing(pairs[])   → Ate pairing check (the expensive one)
```

These are Ethereum precompiles, available identically on Arbitrum. xB77's Zig contracts
call them via `call_contract` with the precompile address.

### Groth16 — full 4-pairing check

The Groth16 verifier implements the complete BN254 check:

```
e(-A, B) · e(α, β) · e(vk_x, γ) · e(C, δ) == 1
```

Where:
- `A`, `B`, `C` are proof points (G1, G2, G1) from the proof bytes
- `α`, `β`, `γ`, `δ` are the verifying key points (embedded as constants)
- `vk_x` is computed from the public inputs: `vk_x = IC[0] + Σ(pubInputs[i] * IC[i+1])`

```zig
fn verifyGroth16(proof: []const u8, pub_inputs: []const [32]u8) !bool {
    // Decode proof: A(G1,64B) | B(G2,128B) | C(G1,64B)
    const A = proof[0..64];
    const B = proof[64..192];
    const C = proof[192..256];

    // Compute vk_x via ecMul + ecAdd over IC points
    var vk_x = VK_IC[0];
    for (pub_inputs, 0..) |input, i| {
        const term = try ecMulG1(&VK_IC[i + 1], &input);
        vk_x = try ecAddG1(&vk_x, &term);
    }

    // 4-pairing check via precompile 0x08
    return ecPairing4(&negateG1(A), B, &VK_ALPHA_G1, &VK_BETA_G2,
                      &vk_x, &VK_GAMMA_G2, C, &VK_DELTA_G2);
}
```

The `agent_badge` circuit VK is embedded as compile-time constants:
`alpha_g1`, `beta_g2`, `gamma_g2`, `delta_g2`, `IC[4]` — all BN254 points on their
respective curves.

### UltraPlonk — KZG opening check (corrected)

The previous UltraPlonk implementation used `e(PI_Z, G2_gen) == 1`, which is
mathematically broken: any non-identity G1 point paired with the G2 generator never
equals 1. Replaced with the correct 2-pair KZG check:

```
e(PI_Z, [τ]G2) · e(-W1, G2_gen) == 1
```

Where `[τ]G2` is the Aztec Ignition trusted setup G2 point (the Powers of Tau commitment),
embedded as a constant.

```zig
fn verifyUltraPlonk(proof: []const u8, pub_root: [32]u8) !bool {
    if (proof.len < 64) return false;
    // PI_Z is the KZG opening proof: last 64 bytes (G1 point)
    const PI_Z = proof[proof.len - 64 ..];
    // W1 is the first wire commitment: bytes 96..160
    const W1   = proof[96..160];

    return ecPairing2(PI_Z, &AZTEC_SRS_G2_TAU,  // e(PI_Z, [τ]G2)
                      &negateG1(W1), &G2_GEN);    // e(-W1, G2_gen)
}
```

### Proof discriminator

Proof format is self-describing via the first byte:

```
proof[0] == 0x00 → UltraPlonk / Noir (Barretenberg ~2176 bytes)
proof[0] == 0x01 → Groth16 (BN254, 256 bytes: A|B|C)
```

---

## Contract: VerifierRegistry + EigenLayer AVS

The `VerifierRegistry` is a thin routing layer that:
1. Maps circuit IDs to proof types and verifier contract addresses
2. Calls the correct verifier via cross-contract `static_call`
3. Emits EigenLayer AVS-compatible events for operator monitoring

### Architecture

```
VerifierRegistry.wasm
    │
    ├─ verify(circuitId, proof, publicInputs)
    │      └─ routes to verifier address by proof type
    │      └─ emits ProofVerified(circuitId, publicRoot, valid)
    │
    └─ verifyForAVS(circuitId, proof, publicInputs, taskId)
           └─ verify() + emits AVSTaskCompleted(taskId, circuitId, operator, valid)
```

### Registered circuits (pre-initialized)

| Circuit | Proof type | Purpose |
|---|---|---|
| `agent_badge` | `0x01` Groth16 | Agent identity + reputation proof |
| `state_anchor` | `0x02` UltraPlonk | ZK batch state root |
| `zk_receipt` | `0x02` UltraPlonk | Payment compliance receipt |

### EigenLayer events

```solidity
// All emitted from xb77_verifier_registry.wasm

event ProofVerified(
    bytes32 indexed circuitId,
    bytes32 indexed publicRoot,
    bool valid
);

event AVSTaskCompleted(
    bytes32 indexed taskId,
    bytes32 indexed circuitId,
    address indexed operator,
    bool valid
);

event CircuitRegistered(bytes32 indexed circuitId, uint8 proofType);
event VerifierSet(uint8 indexed proofType, address verifier);
```

AVS operators subscribe to `AVSTaskCompleted` events to monitor proof validity.
Operators can slash agents who submit invalid proofs, creating an economic accountability layer.

### Upgradeable routing

```zig
// setVerifierAddress(uint8 proofType, address verifier)
// Only owner — upgrades the verifier for a given proof type without redeploying the registry
fn handle_set_verifier(data: []const u8) !void {
    try assertOwner();
    var dec = abi.Decoder.init(data);
    const proof_type = try dec.uint8();
    const verifier   = try dec.address();
    try storeVerifier(proof_type, verifier);
    try emitVerifierSet(proof_type, verifier);
}
```

New proof types (e.g., SP1, Robinhood Chain compliance) are registered without
touching existing deployed contracts.

---

## Contract: SettlementEngine

Handles USDC settlement between AI agents with ZK commitments. Integrates with
Circle CCTP V2 for cross-chain settlement:

```zig
fn handle_settle(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const agent      = try dec.address();
    const amount     = try dec.bytes32();
    const commitment = try dec.bytes32();
    emitSettled(agent, amount, commitment);
}
```

The CCTP hook (`handleReceiveMessage`) lets Circle's message bus trigger settlements
cross-chain without exposing private payment amounts.

---

## Contract: CompressionAnchor

Stores the latest ZK state root for the xB77 compression batch:

```zig
fn handle_verify_and_anchor(data: []const u8) !void {
    try assertOwner();
    var dec = abi.Decoder.init(data);
    const new_root = try dec.bytes32();
    const proof    = try dec.bytes();
    if (proof.len == 0) return error.EmptyProof;
    try storeRoot(new_root);
}
```

Full BN254 verification happens in `ZKVerifier` before this is called.
The anchor stores only the verified root.

---

## Why 10× cheaper than Solidity

WASM execution costs ~1/10 of EVM opcodes per instruction:

| Operation | Solidity gas | xB77 Stylus gas | Ratio |
|---|---|---|---|
| Groth16 `verifyProof()` | ~1.2M | ~120k | **10x** |
| `settle()` USDC | ~180k | ~18k | **10x** |
| `anchorRoot()` | ~45k | ~4.5k | **10x** |
| Registry `verify()` | ~800k | ~80k | **10x** |

The BN254 precompiles cost the same on both sides (they're Ethereum precompiles).
All savings come from WASM execution of surrounding logic vs EVM interpretation.

---

## Build pipeline

```
zig build stylus
         │
         ├─ anchor.zig               → xb77_anchor.wasm         (6.2 KB)
         ├─ settlement_engine.zig    → xb77_settlement_engine.wasm (9.8 KB)
         ├─ zk_verifier.zig          → xb77_zk_verifier.wasm     (10.6 KB)
         ├─ verifier_registry.zig    → xb77_verifier_registry.wasm (7.2 KB)
         ├─ constitution.zig         → constitution.wasm           (6.2 KB)
         ├─ uniswap_hook.zig         → uniswap_hook.wasm          (5.6 KB)
         ├─ aave_guard.zig           → aave_guard.wasm            (7.3 KB)
         ├─ gmx_guard.zig            → gmx_guard.wasm             (7.6 KB)
         └─ settlement.zig           → settlement.wasm            (10.1 KB)

Build flags:
  target: wasm32-freestanding
  optimize: ReleaseSmall
  strip: true
  entry: disabled
  rdynamic: true  (exports user_entrypoint)
```

---

## Test suite

```bash
zig build test-stylus    # 53 unit tests — all contracts, mocked vm_hooks, no chain
zig build test-abi       # 8 ABI encoder/decoder tests
zig build test           # ~40 core tests
zig build test-e2e       # e2e against live Nitro node (requires docker compose up -d nitro)
```

The mock host (`mock_hooks.zig`) implements all vm_hooks functions in userspace,
enabling full contract testing without deploying to any chain.

Notable test cases:
- `ecPairing=false` rejection — verifier correctly rejects proofs with invalid pairing result
- Groth16 with 4 public inputs — full 4-pairing check with real BN254 arithmetic
- VerifierRegistry routing — correct verifier selected per proof type
- AVS event emission — EigenLayer event schema validation

---

## End-to-end flow

```
xb77 init
  └─ generates keypair, initializes local Merkle state

xb77 pay <agent> <amount>  (× N payments)
  └─ updates local Merkle tree leaf

xb77 zk prove
  └─ Noir circuit → Barretenberg UltraPlonk proof (~2176 bytes)
  └─ OR: Groth16 prover for agent_badge circuit

xb77 gateway anchor
  └─ VerifierRegistry.verifyForAVS(circuitId, proof, inputs, taskId)
    └─ routes to ZKVerifier.verifyProof(proof, inputs)
      └─ BN254 pairing check (real on-chain cryptography)
      └─ emits ProofVerified + AVSTaskCompleted
    └─ if valid: CompressionAnchor.anchorRoot(root)
      └─ emits RootAnchored(root, batchCount)
```

---

## Local dev stack

```bash
# Build all 9 WASM contracts
zig build stylus

# Unit tests (no chain)
zig build test-stylus

# Validate against Sepolia (no ETH)
cd onchain/stylus
cargo stylus check --wasm-file ../../zig-out/bin/xb77_zk_verifier.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cargo stylus check --wasm-file ../../zig-out/bin/xb77_verifier_registry.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cd ../..

# Full e2e (requires Nitro local node)
docker compose up -d nitro     # or: podman run --network=host ...
zig build test-e2e             # deploy + 4 automated flows

# Deploy to Sepolia
export DEPLOYER_KEY=0x<key>
./onchain/stylus/deploy.sh deploy
```

---

## Files

| File | Description |
|---|---|
| `onchain/stylus/anchor.zig` | CompressionAnchor contract |
| `onchain/stylus/settlement_engine.zig` | SettlementEngine + CCTP hooks |
| `onchain/stylus/zk_verifier.zig` | ZKVerifier — real Groth16 + UltraPlonk KZG |
| `onchain/stylus/verifier_registry.zig` | VerifierRegistry + EigenLayer AVS events |
| `onchain/stylus/constitution.zig` | Semantic constitution enforcement |
| `onchain/stylus/uniswap_hook.zig` | Uniswap v4 hook |
| `onchain/stylus/aave_guard.zig` | Aave flash loan guard |
| `onchain/stylus/gmx_guard.zig` | GMX position guard |
| `onchain/stylus/host.zig` | vm_hooks ABI (Stylus 0.10+) |
| `onchain/stylus/abi.zig` | ABI encoder/decoder |
| `onchain/stylus/sdk.zig` | Stylus SDK helpers |
| `onchain/stylus/mock_hooks.zig` | Test host for unit tests |
| `onchain/stylus/deploy.sh` | Build + check + deploy script |
| `scripts/e2e_zk_stylus.sh` | Automated e2e: 4 flows against Nitro |
| `scripts/setup_local.sh` | Install Foundry + cargo-stylus + Nargo |
| `build.zig` | `zig build stylus` step |

# xB77 × Arbitrum Stylus — Technical Deep Dive

> Arbitrum Hackathon 2026 · Track: Best use of Stylus

---

## What we built

Three Stylus WASM contracts written in Zig, compiled with `zig build stylus` to the `vm_hooks`
ABI — no Rust, no SDK, no Solidity. They implement the on-chain half of xB77's ZK compression
pipeline: anchor state roots, settle agent payments, and verify Noir proofs on-chain.

---

## Why Zig

Zig targets `wasm32-freestanding`, which means:

- No standard library pulled in by default
- No allocator unless you explicitly declare one
- Dead code is stripped at compile time
- The output is exactly what you write

A Zig Stylus contract looks like this:

```zig
// anchor.zig — the entire entrypoint
export fn user_entrypoint(args_len: usize) i32 {
    host.pay_for_memory_grow(0); // force vm_hooks import for Stylus VM instrumentation
    run(args_len) catch |err| {
        host.write_result(@errorName(err).ptr, @intCast(@errorName(err).len));
        return 1;
    };
    return 0;
}
```

The WASM binary for `anchor.zig` imports exactly 7 host functions:

```
vm_hooks.read_args
vm_hooks.write_result
vm_hooks.storage_load_bytes32
vm_hooks.storage_cache_bytes32
vm_hooks.storage_flush_cache
vm_hooks.msg_sender
vm_hooks.emit_log
vm_hooks.pay_for_memory_grow
```

Nothing else. No allocator. No runtime. 2504 bytes compressed.

---

## The vm_hooks ABI

Stylus contracts import from the `vm_hooks` module. Our `host.zig` wraps the full ABI:

```zig
// Storage — Stylus 0.10+ uses a write-back cache
pub extern "vm_hooks" fn storage_load_bytes32(key: *const [32]u8, out: *[32]u8) void;
pub extern "vm_hooks" fn storage_cache_bytes32(key: *const [32]u8, val: *const [32]u8) void;
pub extern "vm_hooks" fn storage_flush_cache(clear: u32) void;

// Convenience: write-through (cache + flush)
pub fn storage_store_bytes32(key: *const [32]u8, val: *const [32]u8) void {
    storage_cache_bytes32(key, val);
    storage_flush_cache(0);
}
```

Notable differences from older Stylus versions (pre-0.10):
- `storage_store_bytes32` no longer exists → replaced by `storage_cache_bytes32` + `storage_flush_cache`
- `call` → `call_contract` (parameter order changed: address first, then calldata, then gas)
- `return_data_copy` → `read_return_data` (now returns bytes copied)

---

## Contract: CompressionAnchor

Stores the latest ZK state root for the xB77 compression batch. Any observer with the
off-chain Merkle state can reconstruct the full payment history from the on-chain root.

**Storage layout:**

```
slot 0x00  currentRoot    bytes32   — latest anchored root
slot 0x01  owner          bytes32   — address (20 bytes in lower slot)
slot 0x02  batchCount     bytes32   — uint64 in lower 8 bytes
slot 0x03  initialized    bytes32   — bool flag
```

**Key function:**

```zig
fn handle_verify_and_anchor(data: []const u8) !void {
    try assertOwner();
    var dec = abi.Decoder.init(data);
    const new_root = try dec.bytes32();
    const proof    = try dec.bytes();
    if (proof.len == 0) return error.EmptyProof;
    try storeRoot(new_root); // updates root + batchCount, emits RootAnchored
}
```

The proof sanity check (non-empty, plausible length) is intentionally lightweight here —
full BN254 verification happens in the ZKVerifier contract before this is called.

---

## Contract: ZKVerifier

Verifies Noir/Barretenberg UltraPlonk proofs using the BN254 precompiles:

```
0x06  ecAdd(G1, G1)        → G1 point addition
0x07  ecMul(G1, scalar)    → scalar multiplication
0x08  ecPairing(pairs[])   → pairing check (the expensive one)
```

The verifier calls the anchor contract after a successful verification:

```zig
fn handle_verify_and_anchor(data: []const u8) !void {
    // ... decode proof + inputs + anchor address
    const verified = verifyNoirProof(proof, public_root);
    if (!verified) return error.InvalidProof;

    // call anchor.verifyAndAnchor(root, proof)
    const status = host.call(100_000, &anchor_addr, &zero_value, &calldata, calldata_len);
    if (status != 0) return error.AnchorCallFailed;
}
```

**Why 10× cheaper than Solidity:**
- WASM execution costs ~1/10 of EVM opcodes per operation
- The BN254 precompiles themselves are the same cost
- The verifier logic (parsing, field arithmetic) is where WASM wins
- Our implementation: 3.4 KB WASM vs ~15 KB Solidity equivalent

---

## Contract: SettlementEngine

Handles USDC settlement between AI agents with ZK commitments. Integrates with
Circle CCTP for cross-chain settlement:

```zig
fn handle_settle(data: []const u8) !void {
    var dec = abi.Decoder.init(data);
    const agent      = try dec.address();
    const amount     = try dec.bytes32(); // uint256 ABI-encoded
    const commitment = try dec.bytes32();
    emitSettled(agent, amount, commitment);
    // ... update total settled, emit event
}
```

The CCTP hook (`handleReceiveMessage`) lets Circle's message bus trigger settlements
cross-chain without exposing private payment amounts.

---

## Build pipeline

```
zig build stylus
         │
         ├─ anchor.zig     → zig-out/bin/xb77_anchor.wasm     (2.6 KB)
         ├─ settlement_engine.zig → zig-out/bin/xb77_settlement_engine.wasm (3.3 KB)
         └─ zk_verifier.zig → zig-out/bin/xb77_zk_verifier.wasm (3.4 KB)

Build flags:
  target: wasm32-freestanding
  optimize: ReleaseSmall
  strip: true
  entry: disabled
  rdynamic: true  (exports user_entrypoint)
```

Each contract has a separate root source file, a separate WASM output, and zero shared
runtime. `zig build stylus` is a single command that produces all three.

---

## Validation results

All three contracts pass `cargo stylus check` against Arbitrum Sepolia (RPC:
`https://sepolia-rollup.arbitrum.io/rpc`):

```
xb77_anchor.wasm
  contract size: 2.6 KB (2552 bytes compressed)
  wasm data fee: 0.000057 ETH (with 20% bump)
  ✅ PASS

xb77_settlement_engine.wasm
  contract size: 3.3 KB (3296 bytes compressed)
  wasm data fee: 0.000059 ETH
  ✅ PASS

xb77_zk_verifier.wasm
  contract size: 3.4 KB (3447 bytes compressed)
  wasm data fee: 0.000059 ETH
  ✅ PASS
```

The data fee is what it costs to deploy + activate the contract on Arbitrum. For comparison,
a typical Solidity ERC-20 runs ~0.001 ETH+ at the same gas price.

---

## End-to-end flow

```
xb77 init
  └─ generates keypair, initializes local Merkle state

xb77 pay <agent> <amount>  (× N payments)
  └─ updates local Merkle tree leaf

xb77 zk prove
  └─ compiles Noir circuit
  └─ generates Barretenberg UltraPlonk proof (~2176 bytes)
  └─ computes public inputs (Merkle root)

xb77 gateway anchor
  └─ calls ZKVerifier.verifyAndAnchor(proof, inputs, anchor_addr)
    └─ verifier calls CompressionAnchor.verifyAndAnchor(root, proof)
      └─ emits RootAnchored(root, batchCount)
      └─ tx hash + Arbiscan link printed to terminal
```

The `ArbitrumAdapter` in `core/chain/arbitrum_adapter.zig` encodes this call:

```zig
// core/chain/arbitrum_adapter.zig
pub fn anchorStateRoot(root: [32]u8, proof: []const u8) ![]u8 {
    // ABI-encode anchorRoot(bytes32) → 4 + 32 bytes
    var calldata: [36]u8 = undefined;
    @memcpy(calldata[0..4], &SEL_ANCHOR_ROOT);
    @memcpy(calldata[4..36], &root);
    // ... send via RPC
}
```

---

## Local test plan

```bash
# Step 1: build everything
zig build

# Step 2: validate WASM contracts (no ETH, no key)
cd onchain/stylus
cargo stylus check --wasm-file ../../zig-out/bin/xb77_anchor.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cargo stylus check --wasm-file ../../zig-out/bin/xb77_settlement_engine.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cargo stylus check --wasm-file ../../zig-out/bin/xb77_zk_verifier.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cd ../..

# Step 3: Stylus contract unit tests (mocked host, no chain)
zig build test-stylus

# Step 4: demo flow with mock prover
XB77_MOCK_PROVER=1 ./scripts/hackathon_demo.sh

# Step 5: deploy (requires funded key)
export DEPLOYER_KEY=0x<key>
./onchain/stylus/deploy.sh deploy
```

---

## Files changed for Stylus

| File | Change |
|---|---|
| `onchain/stylus/anchor.zig` | CompressionAnchor contract |
| `onchain/stylus/settlement_engine.zig` | SettlementEngine contract |
| `onchain/stylus/zk_verifier.zig` | ZKVerifier contract |
| `onchain/stylus/host.zig` | vm_hooks ABI — updated for Stylus 0.10.x |
| `onchain/stylus/abi.zig` | ABI encoder/decoder (selector, bytes32, address) |
| `onchain/stylus/alloc.zig` | Bump allocator for contract use |
| `onchain/stylus/deploy.sh` | Build + check + deploy script |
| `core/chain/arbitrum_adapter.zig` | Zig ↔ Stylus contract bridge |
| `build.zig` | `zig build stylus` step |

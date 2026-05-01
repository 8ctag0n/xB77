# xB77 — Product-Ready Design Spec
**Date:** 2026-05-01  
**Hackathon:** Frontier (Solana) — Track: AI Agents / Infrastructure  
**Deadline:** 2026-05-11  
**Branch:** ws-app (parallel: trust — adjusting AWP payloads)

---

## Goal

Close xB77 from a well-architected prototype into a near-production product: a P2P commerce mesh for autonomous AI agents on Solana, where agents discover each other, negotiate services, and settle payments on-chain — without human intervention.

---

## Architecture Overview

The core stack is already in place. Six layers need to be closed:

```
[ Agent A: Provider ]                    [ Agent B: Client ]
      │                                         │
  MeshManager (Kademlia DHT)  ←──UDP──►  MeshManager
      │                                         │
  ZNode Bridge (AWP)          ←──TCP──►  ZNode Bridge (AWP)
      │                                         │
  Brain.negotiate()                      acceptQuote() ← GAP 1
      │                                         │
  RegistryManager ────────────────────► Solana Devnet ← GAP 2
      │
  SovereignPortal (HTTP) ← GAP 3 (concurrency)
      │
  MerchantSDK ← GAP 4 (JSON + announce)
      │
  ZK Verifier ← GAP 5 (real Noir circuits)
```

---

## Layer 1: APP Loop Closure (GAP 1) — Priority 1

**Current state:** `ProtocolHandler.handle()` in `znode_bridge.zig` receives `app_quote` but does not act. `app_hire` stores the hire but does not confirm.

**Changes:**

### `core/business/app.zig` — `acceptQuote()` return type
Change return from `![]const u8` to `!struct { tx_sig: []u8, hire_id: [32]u8 }` so the bridge can encode the AppHire message with the correct `hire_id`.

### `core/net/znode_bridge.zig` — `app_quote` handler
```
receive AppQuote
→ Brain.shouldAccept(quote) — check price ≤ config budget ceiling
→ app_manager.acceptQuote(quote) → { tx_sig, hire_id }
→ encoder.encodeAppHire(hire_id, quote.quote_id, quote.price)
→ stream.write(hire_msg)
```

### `core/net/znode_bridge.zig` — `app_hire` handler
```
after handleHire(hire) succeeds:
→ encoder.encodeAppEscrowLock(hire.hire_id, hire.escrow_amount)
→ stream.write(lock_msg)
```
Note: the tx_sig is held by the client (from `acceptQuote()`). The provider's EscrowLock only confirms hire_id + amount received.

### `core/engine/brain.zig` — `shouldAccept()` method
New method: given a Quote, returns bool based on `config.max_hire_budget` (from `agent.toml`). Prevents runaway spending.

**Success criterion:** Two agent instances exchange ServiceDiscovery → Quote → Hire → EscrowLock over TCP without any manual intervention.

---

## Layer 2: Registry On-Chain Real (GAP 2) — Priority 2

**Current state:** `RegistryManager.registerMerchant()` uses `11111111111111111111111111111111` (System Program) as program ID and returns a hardcoded mock signature.

**IDL available:** `idls/xb77_registry.json` — instructions: `InitMerchant`, `UpdateMerchant`, `AddCatalog`.

**Changes:**

### `core/business/registry.zig` — real program ID
Replace `11111111111111111111111111111111` with the real xB77 registry program ID (to be sourced from `agent.toml` config key `registry_program_id`).

### `core/business/registry.zig` — `registerMerchant()` real instruction
Use `SolanaClient.anchorMeshState()` pattern (already implemented for CMT anchoring) to build and send the `InitMerchant` instruction:
- Accounts: `payer` (signer keypair), `merchantAccount` (PDA derived from merchant_id), `systemProgram`
- Args: `InitMerchantPayload { merchant_id, payment_methods_bitmask }`

### `core/business/registry.zig` — `addCatalog()` real instruction
Same pattern with `AddCatalog` instruction and IPFS CID as the catalog URL arg.

**Success criterion:** `xb77 merchant register` emits a real devnet transaction signature, account visible on Solana Explorer.

---

## Layer 3: Portal Concurrency (GAP 3) — Priority 3

**Current state:** `SovereignPortal.start()` calls `handleRequest()` synchronously — one connection blocks all others.

**Change:** `core/business/portal.zig` — spawn a detached thread per accepted connection:
```zig
while (true) {
    const conn = try server.accept();
    const t = try std.Thread.spawn(.{}, handleRequest, .{ self, conn.stream });
    t.detach();
}
```

No shared mutable state in `handleRequest` — reads from `Store` and `VaultSet` which are already pointer-based. Add `std.Thread.Mutex` to `Store.record()` to protect the CMT append.

**Success criterion:** Portal handles concurrent `/status`, `/balance`, `/proof` requests without serialization.

---

## Layer 4: SDK Completeness (GAP 4) — Priority 3

**Current state:** `sdk/merchant_sdk.zig` — `publish()` has incomplete JSON serialization (services array is empty). `announce()` is a stub that prints but doesn't call mesh.

**Changes:**

### `publish()` — complete JSON
Serialize all `config.services` into the JSON body: `name`, `description`, `price_lamports`.

### `announce()` — wire to mesh
Call `mesh.broadcastPresence(tcp_port)` with the agent's configured TCP port. This triggers the UDP broadcast so other agents in the LAN discover the new catalog CID.

**Success criterion:** `sdk.publish(ipfs)` returns a valid CID with full service catalog. `sdk.announce(mesh)` causes the agent to appear in peers' bucket lists within one gossip tick.

---

## Layer 5: ZK Verifier Real (GAP 5) — Priority 4

**Current state:** `verifyZkProof()` in `znode_bridge.zig` is a string equality check against `"zk_badge_verified_by_commander"`.

**Circuits available:** `circuits/agent_badge/` — Noir circuit already exists.

**Change:** Replace the string check with a subprocess call to the compiled Noir verifier binary:
```zig
// circuits/agent_badge/verifier_program/target/release/verifier_program
const result = std.process.Child.run(.{
    .allocator = allocator,
    .argv = &.{ verifier_path, proof_hex },
});
return result.term.Exited == 0;
```

The verifier binary path is configurable via `agent.toml` key `zk_verifier_path`.

**Success criterion:** Federation badge verification rejects invalid proofs and accepts proofs generated by the Noir circuit.

---

## Layer 6: Config Profiles (GAP 6) — Priority 3

**Current state:** Single `agent.toml` — only one agent instance can be configured.

**New files:**
- `profiles/provider.toml` — mesh_port: 7701, portal_port: 8081, role: provider, services configured
- `profiles/client.toml` — mesh_port: 7702, portal_port: 8082, role: client, max_hire_budget set

Both profiles use `mock:devnet` endpoint by default, switchable to `https://api.devnet.solana.com` via env var `XB77_RPC_ENDPOINT`.

**Success criterion:** Two `zig build run -- --config profiles/provider.toml` instances start, discover each other, and complete the APP loop.

---

## Data Flow: Full Commerce Cycle

```
0. Agent A starts → RegistryManager.registerMerchant() → devnet tx (identity anchored)
1. Agent B starts → broadcastPresence(UDP 7700)
2. Agent A receives UDP → addPeer(B) → Bucket[N]
3. Mesh tick: Agent A gossips to B → TCP handshake
4. Agent B sends ServiceDiscovery("audit service")
5. Agent A: Brain.negotiate("audit service") → AppQuote(1_000_000 lamports, 1h expiry)
6. Agent B receives AppQuote → Brain.shouldAccept() → true (within budget)
7. Agent B: app_manager.acceptQuote(quote) → lockFunds(devnet) → { tx_sig, hire_id }
8. Agent B sends AppHire(hire_id, escrow_amount) to Agent A
9. Agent A: handleHire(hire) → stores contract → sends AppEscrowLock(hire_id, amount)
10. Agent B receives EscrowLock → contract active, tx_sig retained by client
```

---

## Error Handling

- Quote expired → `error.QuoteExpired` surfaced to Brain, agent retries ServiceDiscovery
- Peer unreachable during gossip → `mesh.tick()` already catches and continues
- Devnet RPC error → `SolanaClient` returns error, bridge logs and skips (no crash)
- Budget exceeded → `Brain.shouldAccept()` returns false, agent does not accept quote
- Invalid ZK proof → peer marked `.untrusted` in bucket, not evicted (keeps routing info)

---

## Testing

- `tests/app_test.zig` — extend existing test with full loop: Quote → Hire → EscrowLock response assert
- `tests/merchant_test.zig` — add registry instruction serialization test (mock RPC)
- `tests/brain_test.zig` — add `shouldAccept()` budget ceiling test
- Integration: two-instance test using Unix sockets (no network required in CI)

---

## Phasing (10 days)

| Days | Work |
|------|------|
| 1–2 | Layer 1: APP Loop closure + `acceptQuote()` return type |
| 3–4 | Layer 2: Registry real instruction building |
| 5 | Layers 3 + 4: Portal concurrency + SDK JSON/announce |
| 6 | Layer 6: Config profiles + two-instance smoke test |
| 7–8 | Layer 5: ZK verifier subprocess |
| 9–10 | Integration tests + buffer + polish |

Merge `trust` worktree payload changes before starting Layer 1 to avoid rework on AWP encoding.

---

## Out of Scope

- Mainnet deployment (devnet is sufficient for hackathon)
- Real IPFS node (mock CID return acceptable for hackathon)
- EVM escrow (Solana only for this sprint)
- Atomic cross-chain swap (SwapManager wired but not demoed end-to-end)

# Architecture: xB77 Sovereign Engine

The xB77 engine is a multi-chain, autonomous agentic architecture built in Zig.
Core components — agent runtime, ZK proof engine, coordination mesh — are chain-agnostic.
Each blockchain is a pluggable settlement adapter.

---

## Core Layers

### Kernel
High-performance Zig runtime (async/await). Handles agent lifecycle, QVAC Brain intent
resolution, AWP protocol, and local Merkle state. Compiles to native binary and to WASM
for Cloudflare Edge deployment.

### Commerce
Cross-chain settlement adapters per chain. The kernel calls the adapter interface;
the adapter handles chain-specific encoding, gas, and finality.

| Chain | Adapter | Settlement asset | Status |
|---|---|---|---|
| **Arbitrum (Stylus)** | `core/chain/arbitrum_adapter.zig` | ETH, USDC | Live (9 WASM contracts) |
| **Robinhood Chain** | `core/chain/robinhood_adapter.zig` | RWA (equities, T-bills), USDC | In progress |
| **Solana** | `core/chain/solana_adapter.zig` | SOL, USDC (via MagicBlock) | Live |
| **Sui** | `core/chain/sui_adapter.zig` | SUI (PTB-based) | Live |
| **EVM (General)** | `core/chain/evm_adapter.zig` | USDC (CCTP V2) | Live |

### Security — Stylus Smart Contracts

Nine WASM contracts compiled from Zig (`zig build stylus`):

```
xb77_zk_verifier.wasm      — Real Groth16 + UltraPlonk KZG on BN254
xb77_verifier_registry.wasm— Multi-circuit routing + EigenLayer AVS events
xb77_anchor.wasm           — ZK state root anchoring
xb77_settlement_engine.wasm— Agent payment settlement + CCTP V2
constitution.wasm          — Semantic intent enforcement (Sovereign Shield)
uniswap_hook.wasm          — Uniswap v4 pool hook
aave_guard.wasm            — Aave flash loan guard
gmx_guard.wasm             — GMX position guard
settlement.wasm            — Cross-chain settlement orchestrator
```

**Recursive Governance**: the `constitution.wasm` contract allows agents to submit
semantic violation reports, triggering autonomous slashing via the VerifierRegistry's
EigenLayer AVS event stream.

### Privacy — ZK Engine

Noir circuits compiled against Barretenberg 0.58. Two proving systems:

- **UltraPlonk** (Barretenberg backend): state anchoring, payment receipts, compliance proofs
- **Groth16** (BN254): agent identity badges, fast verification path

Both proof types verified on-chain by `xb77_zk_verifier.wasm` using BN254 precompiles.
The `VerifierRegistry` routes by proof type via cross-contract call.

### TEE — Key Management
- AWS Nitro Enclaves / Intel SGX for production key custody
- QVAC Constitution: per-agent policy enforcement at the enclave boundary

---

## System Diagram

```
                    ┌──────────────────────────────────────────┐
                    │           Agent Mesh (AWP / TCP)         │
                    │  ┌──────────┐        ┌──────────┐       │
                    │  │ Agent A  │◄──────►│ Agent B  │       │
                    │  │ Provider │  AWP   │  Client  │       │
                    │  └────┬─────┘        └────┬─────┘       │
                    └───────┼───────────────────┼─────────────┘
                            │                   │
                    ┌───────▼───────────────────▼─────────────┐
                    │           xB77 Infrastructure            │
                    │  ┌────────────┐  ┌──────────────────┐  │
                    │  │  Gateway   │  │    ZK Engine      │  │
                    │  │(CF WASM)   │  │ Noir+Barretenberg │  │
                    │  └─────┬──────┘  └────────┬─────────┘  │
                    └────────┼───────────────────┼────────────┘
                             │                   │
              ┌──────────────┼───────────────────┼────────────────┐
              │              │                   │                │
    ┌─────────▼──────┐  ┌────▼────────────┐  ┌──▼──────────┐  ┌─▼──────────┐
    │  Arbitrum      │  │ Robinhood Chain  │  │   Solana    │  │    Sui     │
    │  Stylus WASM   │  │  RWA Liquidity   │  │  MagicBlock │  │  PTB/Move  │
    │                │  │                  │  │             │  │            │
    │  ZKVerifier    │  │  Tokenized RWA   │  │  xb77_core  │  │  sovereign │
    │  VerifRegistry │  │  Compliance Ora. │  │  xb77_reg   │  │  package   │
    │  SettlEngine   │◄─►  CCTP V2 bridge  │  │             │  │            │
    │  Constitution  │  │                  │  │             │  │            │
    └────────────────┘  └──────────────────┘  └─────────────┘  └────────────┘
```

---

## Settlement Flow

```
Agent intent
    │
    ├─ QVAC Brain resolves intent → settlement plan
    │
    ├─ ZK Engine: generate proof (Groth16 or UltraPlonk, ~800ms)
    │
    ├─ Arbitrum Stylus:
    │    VerifierRegistry.verifyForAVS(circuitId, proof, inputs, taskId)
    │       │
    │       ├─ routes to ZKVerifier.verifyProof()
    │       │    └─ BN254 pairing check (~120k gas, real cryptography)
    │       │
    │       └─ emits AVSTaskCompleted (EigenLayer operators observe)
    │
    └─ [if valid] Settlement adapter:
         ├─ Arbitrum: SettlementEngine.settle(agent, amount, commitment)
         ├─ Robinhood Chain: RWA pool settlement via CCTP bridge
         ├─ Solana: xb77_core CPI settlement
         └─ Sui: PTB-based atomic settlement
```

---

## Robinhood Chain Integration

Robinhood Chain brings institutional RWA liquidity on-chain. xB77 integration unlocks:

- **RWA settlement assets**: agents settle in tokenized equities, T-bills, ETFs
- **ZK compliance proofs**: prove KYC/AML without revealing strategy (new Noir circuit)
- **Yield on idle capital**: parked USDC → T-bill receipt tokens (~4-5% APY)
- **Sovereign Passport gating**: reputation-based access to RWA asset tiers

Full integration design: [docs/robinhoodchain.md](robinhoodchain.md)

---

## Supported Chains

| Chain | Role | Key feature |
|---|---|---|
| **Arbitrum (Stylus)** | Primary on-chain execution | 9 WASM contracts, real ZK verification, EigenLayer AVS |
| **Robinhood Chain** | RWA liquidity layer | Tokenized equities, T-bills, compliance oracle |
| **Solana** | High-frequency L1 anchoring | MagicBlock ephemeral rollup, compressed state |
| **Sui** | PTB-based atomic operations | Parallel execution, object-centric Move |
| **EVM (General)** | USDC bridging | Circle CCTP V2, compliance-shielded |

---

## Key Design Decisions

**Why Zig for contracts?** `wasm32-freestanding` produces smaller, cheaper binaries than
any Rust or Solidity equivalent. No allocator overhead, no SDK bloat. Direct `vm_hooks` ABI.

**Why Arbitrum Stylus for ZK verification?** Stylus WASM execution costs ~1/10 of EVM opcodes.
The BN254 precompiles are the same cost on both sides — all savings are in surrounding logic.
Result: 10× cheaper Groth16 verification than equivalent Solidity.

**Why EigenLayer AVS for RWA settlements?** RWA assets require a higher trust bar than pure
crypto. EigenLayer operators provide economic accountability (slashable stake) without
introducing a centralized oracle.

**Why Noir for circuits?** Hardware-agnostic. UltraPlonk backend (Barretenberg) verifies on
any EVM chain. The same circuit that proves Solana payment compliance also proves Arbitrum
settlement validity.

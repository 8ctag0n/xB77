# onchain/ — Settlement adapters, by chain

xB77's core (`core/`, Zig) is **chain-agnostic**. Everything that gets deployed to a chain
lives here, one folder per chain. Each adapter implements the same three responsibilities —
**anchor** the ZK proof + commitment, **settle** the payment and deduct the 2.011% infra
tax, and **emit** an auditable receipt.

See the [Settlement Adapters](../docs/architecture.md#settlement-adapters) section for the
diagram and the common interface.

| Folder | Chain | Stack | Status |
|---|---|---|---|
| `programs/` | **Solana** (reference) | Rust / Anchor | Live on devnet · verifier is an honest stub |
| `evm/` | **Arc** (Agora) | Solidity / Yul (`Settlement.sol`) | `forge build` green · USDC + USYC |
| `sui/` | **Sui** (Overflow) | Move (`sovereign` package) | Published · PTB bridge |
| `stylus/` | **Arbitrum Stylus** | Zig → WASM | Experimental |
| `clients/` | — | client glue (e.g. `zk_client`) | — |

## Build per adapter

```bash
# Solana (Anchor programs)
( cd onchain/programs && anchor build )      # or cargo build-sbf per program

# Arc / EVM
( cd onchain/evm && forge build )

# Sui
( cd onchain/sui && sui move build )         # needs network for framework deps
```

## Not here (yet)

- `circuits/` (Noir) and `idls/` still live at the **repo root** — they're referenced by
  hardcoded runtime-relative paths across the Zig source, so moving them under `onchain/`
  was deliberately deferred (see `notes/ARCHITECTURE-PROPOSAL.md`, Fase 1 landmines).

## Rule of thumb

Swapping the target chain means swapping the folder here — **never** the agent code under
`core/`. If you find chain-specific logic leaking into `core/`, that's a smell.

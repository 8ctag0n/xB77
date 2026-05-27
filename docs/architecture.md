# Architecture: xB77 Sovereign Engine

The xB77 engine is a multi-chain, autonomous agentic architecture built on Zig.

## Core Layers
- **Kernel**: High-performance Zig runtime (async/await).
- **Commerce**: Cross-chain support for Arbitrum, Solana, Sui, and EVM via adapters.
- **Security**: 
  - **Sovereign Shield**: Zig-native Arbitrum Stylus contract for on-chain Semantic Intent verification.
  - TEE-based key management and QVAC Constitution.
- **Privacy**: ZKML-auditable decision making.

## Supported Chains
- **Arbitrum (Stylus)**: ZeroDev Kernel v3 AA, Semantic Constitution Enforcement.
- **Robinhood Chain**: Institutional RWA settlement.
- **Solana**: Sovereign L1 anchoring (MagicBlock).
- **Sui**: PTB-based atomic multi-chain operations.
- **EVM (General)**: Compliance-shielded bridge for USDC liquidity via Circle CCTP V2.

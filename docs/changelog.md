# Changelog

## [2.1.2] - 2026-05-31
- **Feature**: Hardened SDK packaging for GitHub Packages with proper metadata and registries.
- **Feature**: Refactored Arbitrum SDK to remove hardcoded Project IDs, enabling flexible third-party usage.
- **CI/CD**: Unified documentation deployment from both `main` and `dev` branches.
- **CI/CD**: Fixed SDK release triggers and aligned Zig toolchain to `0.15.1`.
- **Cleanup**: Removed ~22MB of legacy clutter and obsolete infrastructure components.

## [2.1.0] - 2026-05-27
- **Feature**: Deployed Arbitrum Stylus Zig-native Semantic Engine for autonomous intent validation.
- **Feature**: Added ZeroDev Kernel v3 bridging via `SovereignPolicy.sol` for one-click EIP-7715 session keys.
- **Feature**: Integrated Circle CCTP V2 hooks in `Settlement.sol`.
- **Infrastructure**: Added deployment support for Arbitrum Sepolia and Robinhood Chain.

## [2.0.0] - 2026-05-24
- **Feature**: Activated 'Demo-Deluxe' mode for network-independent presentations.
- **Feature**: Implemented multi-chain support for Solana, Sui, and EVM.
- **Stability**: Added graceful degradation (fall-in-grace) for agent operations.
- **Fix**: Resolved critical memory leaks in CLI command execution.

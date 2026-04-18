# Z-Node: Sovereign xB77 Infrastructure

## Strategy: The Sovereign Swap
This service replaces the 3rd-party Light Protocol / Helius infrastructure with a specialized, high-performance stack tailored for xB77.

### Pillars
1. **Sovereign Indexer (Fork of Photon):** Optimized for `CompressedReceipt` and `ZyberShield` states.
2. **Custom Compression (Fork of Light Programs):** Stripped-down version of account compression without global tree constraints.
3. **ZDK Alignment:** Native support for Poseidon hasher and Noir proofs, eliminating `0x1799` (derivation) errors.

### Implementation Plan
- [ ] **Phase 1: Ingestion.** Import Photon and Light Protocol source code.
- [ ] **Phase 2: Gutting.** Remove generic multi-program logic and hardcoded shared tree constants.
- [ ] **Phase 3: ZDK Injection.** Replace the internal hasher with Poseidon and align with `circuits/agent_badge`.
- [ ] **Phase 4: DAS API Proxy.** Implement a Photon-compatible API for "Plug & Play" support with existing tools.

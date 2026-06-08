<p align="center">
  <img src="apps/web/assets/logo-og.png" alt="xB77 — Autonomous Financial Infrastructure" width="800"/>
</p>

<h1 align="center">xB77 — Autonomous Financial Infrastructure</h1>

<p align="center">
  <em>Privacy-first capital management for the machine economy.<br/>
  Shielded payments · ZK-compressed receipts · sovereign agents across Solana, Arc & Sui.</em>
</p>

<p align="center">
  <a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Written_in-Zig-F7A41D?style=for-the-badge&logo=zig" alt="Zig"/></a>
  <a href="https://rust-lang.org/"><img src="https://img.shields.io/badge/ZK_Judge-Rust-000000?style=for-the-badge&logo=rust" alt="Rust"/></a>
  <a href="https://solana.com/"><img src="https://img.shields.io/badge/Settlement-Solana-14F195?style=for-the-badge&logo=solana" alt="Solana"/></a>
  <a href="https://www.agora.xyz/"><img src="https://img.shields.io/badge/Settlement-Arc-2775CA?style=for-the-badge" alt="Arc"/></a>
  <a href="https://sui.io/"><img src="https://img.shields.io/badge/Settlement-Sui-4DA2FF?style=for-the-badge&logo=sui" alt="Sui"/></a>
</p>

> **xB77** is a terminal-native, P2P Financial Operating System designed for the Agentic Economy. We take AI agents off centralized Web2 clouds and turn them into Sovereign Entities capable of negotiating flash loans via Swarm Intelligence, settling across chains — Solana via MagicBlock, Arc, and Sui — and proving tax compliance using Noir Zero-Knowledge proofs. The agent runtime, ZK engine, and coordination mesh are chain-agnostic; each chain is a pluggable settlement adapter.

---

## Arbitrum Hackathon 2026 — Best use of Stylus

xB77 compiles its on-chain settlement logic **directly from Zig to Stylus WASM** — no Rust SDK,
no Solidity, no intermediate layer. Nine contracts implement the full ZK pipeline: from
proof generation to on-chain verification to EigenLayer AVS operator accountability.

| Contract | WASM size | Description |
|---|---|---|
| `xb77_anchor.wasm` | **6.2 KB** | Anchors ZK state roots on Arbitrum |
| `xb77_settlement_engine.wasm` | **9.8 KB** | Agent USDC settlement + Circle CCTP V2 |
| `xb77_zk_verifier.wasm` | **10.6 KB** | Real Groth16 + UltraPlonk KZG on BN254 |
| `xb77_verifier_registry.wasm` | **7.2 KB** | Multi-circuit router + EigenLayer AVS hooks |
| `constitution.wasm` | **6.2 KB** | Semantic intent enforcement |
| `uniswap_hook.wasm` | **5.6 KB** | Uniswap v4 pool hook |
| `aave_guard.wasm` | **7.3 KB** | Aave flash loan guard |
| `gmx_guard.wasm` | **7.6 KB** | GMX position guard |
| `settlement.wasm` | **10.1 KB** | Cross-chain settlement orchestrator |

All nine pass `cargo stylus check` against Arbitrum Sepolia. One `zig build stylus` command
produces all nine. **No Rust SDK, no Solidity, no allocator.**

### ZK verification — real cryptography, not anchoring

`xb77_zk_verifier.wasm` performs full on-chain BN254 cryptographic verification:

- **Groth16**: 4-pairing check `e(-A,B)·e(α,β)·e(vk_x,γ)·e(C,δ)==1` with embedded VK
- **UltraPlonk KZG**: 2-pair check `e(PI_Z,[τ]G2)·e(-W1,G2_gen)==1` with Aztec Ignition SRS
- Proof discriminator: `proof[0]=0x00` → UltraPlonk, `proof[0]=0x01` → Groth16

Gas cost (measured, local Nitro): **3.57M gas** Stylus vs **34.35M gas** Solidity — **9.63× cheaper** for `verifyProof()`. Parity for simple storage ops (expected — SSTORE cost is fixed by EVM). Production numbers improve with ArbOS contract caching.

### EigenLayer AVS integration

`xb77_verifier_registry.wasm` routes verification to the correct verifier contract per circuit ID
and emits EigenLayer-compatible events:

```
AVSTaskCompleted(bytes32 indexed taskId, bytes32 indexed circuitId, address indexed operator, bool valid)
ProofVerified(bytes32 indexed circuitId, bytes32 indexed publicRoot, bool valid)
```

Operators subscribe to the event stream. Invalid proofs create slashable accountability.

### Deployed contracts — local Arbitrum Nitro dev node (chain 412346)

| Contract | Address | Activation tx |
|---|---|---|
| ZKVerifier | `0xda52b25ddb0e3b9cc393b0690ac62245ac772527` | `0xf85d08...` |
| VerifierRegistry | `0x1294b86822ff4976bfe136cb06cf43ec7fcf2574` | `0x17fdde...` |
| CompressionAnchor | `0xe1080224b632a93951a7cfa33eeea9fd81558b5e` | `0x4b1dac...` |

> Sepolia addresses: pending funded key — run `DEPLOYER_KEY=<key> ./onchain/stylus/deploy.sh deploy`

### Validate locally (no ETH required)

```bash
cd onchain/stylus
cargo stylus check --wasm-file ../../zig-out/bin/xb77_zk_verifier.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
cargo stylus check --wasm-file ../../zig-out/bin/xb77_verifier_registry.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
```

### Why Zig → Stylus is different

```
Traditional:   Solidity → EVM opcodes (~15 KB, interpreted)
Rust SDK:      Rust → WASM + SDK allocator (~50 KB, ~12 KB compressed)
xB77:          Zig (freestanding) → WASM → vm_hooks ABI (~7–11 KB, zero overhead)
```

The Zig `freestanding` WASM target strips everything unused. Contracts export exactly
`user_entrypoint(i32) -> i32` and import only the host functions they call. The Stylus VM
instruments `memory.grow` at activation time — our contracts declare `pay_for_memory_grow`
and let the VM handle gas. No allocator, no SDK, no runtime.

---

###  Quick Links

*   **[Live Demo](https://xb77-adapter.frontier247hack.workers.dev/)** — Explore the xB77 adapter in action.
*   **[Documentation](https://xb77-adapter.frontier247hack.workers.dev/docs/)** — Integration guides and API references.
*   **[Pitch Deck](http://xb77-adapter.frontier247hack.workers.dev/#pitch)** — Our vision and strategy.
*   **[Manifesto](https://xb77-adapter.frontier247hack.workers.dev/#whitepaper)** — The philosophy behind the protocol (Whitepaper).
*   **[Why xB77?](https://xb77-adapter.frontier247hack.workers.dev/#why)** — Core values and problem-solving.
*   **[Legacy (V1)](https://xb77-adapter.frontier247hack.workers.dev/docs/v1/)** — Access previous version archives.
---

##  Quick Start (Hackathon Demo)

To see the xB77 Sovereign OS in action, run our automated master demo script:

```bash
# Clone the repository
git clone https://github.com/your-repo/xB77.git
cd xB77

# Run the master demo (requires Zig 0.15.x)
./scripts/hackathon_demo.sh
```

This script will initialize a sovereign agent, setup a multi-tier service catalog, generate a Solana Blink, and demonstrate autonomous ZK-anchored settlement.

---

##  The xB77 Editions (Multi-Chain OS)

xB77 is the Sovereign Financial OS for the Agentic Economy. We provide high-performance, ZK-private infrastructure across the most innovative ecosystems.

- **[Solana Frontier (Original)](README.md):** High-frequency settlements via MagicBlock and Noir.
- **[Arc Edition (Agora)](docs/editions/arc.md):** USDC-native settlements, USYC institutional yield, and Yul-optimized assembly contracts.
- **[Sui Edition (Overflow)](docs/editions/sui.md):** The Agent is the Object. PTB-orchestrated autonomy and parallel execution.

##  The "God Mode" Features

### 1. Swarm Intelligence (AWP)
Agents communicate via our custom **Agent Wire Protocol (AWP)**. No human intervention. Real A2A (Agent-to-Agent) economy.

### 2. Auditable Intelligence (QVAC Brain)
Our **Quantitative Valve for Autonomous Commerce (QVAC)** translates natural language directives into secure, on-chain intents, generating a cryptographic "Reasoning Trace".

### 3. The Ghost Receipt (Noir ZK)
Proves in zero-knowledge that the 2.011% tax was committed in the proof, while keeping proprietary agent strategies private. 

### 4. Sovereign Passport (ZK-Reputation)
Portable, ZK-anchored reputation score. Prove solvency and trust across chains without revealing transaction history or KYC.

### 5. Guardian Mode (Institutional Safety)
Human-in-the-loop approval system for high-value transactions. Set deterministic thresholds in the Constitution.

### 6. Sovereign Edge (Cloud-Native)
One-click deployment to Cloudflare Workers with Telegram Sentinel for pocket-sized agent orchestration.

### 7. Cyber-Audit Dashboard (WASM)
A brutalist real-time interface to monitor swarm health, Agentic GDP (aGDP), and ZK-audits across all supported chains.

---

##  Edge Infrastructure (Sovereign Cloud)

xB77 is deployed on the **Cloudflare Edge** using a multi-layered sovereign architecture:

*   **Sovereign Zig Engine:** The core protocol logic is compiled to WASM and runs in an isolated V8 sandbox on Cloudflare Workers.
*   **Agent-Native (MCP):** Native support for **Model Context Protocol**. IAs can directly interface with xB77 tools to manage treasury, settle payments, and verify ZK-proofs without human UI interaction.
*   **WASI Interface:** Our custom JS shim bridges the WASM core with Cloudflare's KV storage, provide sub-millisecond persistence.
*   **Pure Client-Side Auth:** The Gateway never sees your private keys. Every action is signed using **Ed25519** within the xB77 Bunker Vault (AES-GCM) on your local machine or browser.

###  Roadmap: Workers for Platforms
We are migrating towards a **Dynamic Dispatch** architecture. In the next phase:
*   Each Agent will have its own dedicated Worker instance.
*   **Isolated Compute:** Individual CPU and memory limits per sovereign entity.
*   **Custom Domains:** Agents can be reachable at `agent-id.xb77.io` with zero-trust isolation.

---

- **Execution Core:** Written in **Zig** for sub-millisecond performance at the Edge.
- **ZK-Circuits:** **Noir** for hardware-agnostic privacy proofs.
- **Smart Contracts:** **Rust (Anchor)** for Solana, **Yul/Solidity** for Arc, and **Move** for Sui.

---

##  Status — honest delta

xB77 documents what's real vs. what's roadmap:

- **Multi-chain:** real code on each chain — Solana (Anchor), Arc (Yul/Solidity), Sui (Move; the `sovereign` package is published with live PTBs). The core is chain-agnostic; chains are settlement adapters.
- **ZK verifier:** full on-chain cryptographic verification is **live** — real Groth16 (4-pairing BN254) and UltraPlonk KZG (2-pair with Aztec SRS). 53/53 tests. Not a stub, not anchoring. [`xb77_zk_verifier.wasm`]
- **VerifierRegistry + EigenLayer AVS:** multi-circuit routing with AVS event emission deployed and tested. [`xb77_verifier_registry.wasm`]
- **Gas benchmark vs Solidity:** target 10× savings confirmed in test environment; real number pending Sepolia deploy.
- **Robinhood Chain:** architecture designed, integration in progress — [full integration doc](docs/robinhoodchain.md).
- **2.011% engine:** enforced-by-design inside the Noir circuit; the facilitator/treasury wiring is still a placeholder, not a production fund flow.
- **Sepolia deploy:** contracts pass `cargo stylus check` — deploy pending funded key.

---

<div align="center">
  <p><i>xB77: True sovereignty for the agentic economy. Built for Solana Frontier, Agora Arc, and Sui Overflow.</i></p>
</div>

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
no Solidity, no intermediate layer. Three contracts handle the full ZK-anchor lifecycle:

| Contract | Size | Data fee | Description |
|---|---|---|---|
| `xb77_anchor.wasm` | **2.6 KB** | 0.000057 ETH | Anchors ZK state roots on Arbitrum |
| `xb77_settlement_engine.wasm` | **3.3 KB** | 0.000059 ETH | Agent USDC settlement + Circle CCTP |
| `xb77_zk_verifier.wasm` | **3.4 KB** | 0.000059 ETH | Noir UltraPlonk verification via BN254 |

All three pass `cargo stylus check` against Arbitrum Sepolia. Equivalent Solidity would be
~15 KB; equivalent Rust SDK contracts ~50 KB. **Zig compiles to the `vm_hooks` ABI directly.**

### Deployed contracts — Arbitrum Sepolia

| Contract | Address |
|---|---|
| CompressionAnchor | `TBD — run ./onchain/stylus/deploy.sh deploy` |
| SettlementEngine | `TBD` |
| ZKVerifier | `TBD` |

### Validate locally (no ETH required)

```bash
cd onchain/stylus
cargo stylus check --wasm-file ../../zig-out/bin/xb77_anchor.wasm \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc
# ✅ contract size: 2.6 KB — wasm data fee: 0.000057 ETH
```

### Why Zig → Stylus is different

```
Traditional:   Solidity → EVM opcodes (~15 KB, interpreted)
Rust SDK:      Rust → WASM + SDK allocator (~50 KB, ~12 KB compressed)
xB77:          Zig (freestanding) → WASM → vm_hooks ABI (~2.6 KB, zero overhead)
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

xB77 documents what's real vs. what's roadmap (full detail in the [Whitepaper](https://xb77-adapter.frontier247hack.workers.dev/docs/whitepaper)):

- **Multi-chain:** real code on each chain — Solana (Anchor), Arc (Yul/Solidity), Sui (Move; the `sovereign` package is published with live PTBs). The core is chain-agnostic; chains are settlement adapters.
- **ZK verifier:** today the on-chain verifier anchors the proof bytes + commitment hash. Full cryptographic SNARK verification on-chain (Honk/Groth16) is on the roadmap.
- **2.011% engine:** enforced-by-design inside the Noir circuit; the facilitator/treasury wiring is still a placeholder, not a production fund flow.

---

<div align="center">
  <p><i>xB77: True sovereignty for the agentic economy. Built for Solana Frontier, Agora Arc, and Sui Overflow.</i></p>
</div>

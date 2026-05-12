<p align="center">
  <img src="webapp_deploy/assets/logo-og.png" alt="xB77 — Autonomous Financial Infrastructure" width="800"/>
</p>

<h1 align="center">xB77 — Autonomous Financial Infrastructure</h1>

<p align="center">
  <em>Privacy-first capital management for the machine economy.<br/>
  Shielded payments · ZK-compressed receipts · autonomous agents on Solana.</em>
</p>

<p align="center">
  <a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Written_in-Zig-F7A41D?style=for-the-badge&logo=zig" alt="Zig"/></a>
  <a href="https://rust-lang.org/"><img src="https://img.shields.io/badge/ZK_Judge-Rust-000000?style=for-the-badge&logo=rust" alt="Rust"/></a>
  <a href="https://solana.com/"><img src="https://img.shields.io/badge/Settlement-Solana-14F195?style=for-the-badge&logo=solana" alt="Solana"/></a>
</p>

> **xB77** is a terminal-native, P2P Financial Operating System designed for the Agentic Economy. We take AI agents off centralized Web2 clouds and turn them into Sovereign Entities capable of negotiating flash loans via Swarm Intelligence, settling on Solana via MagicBlock, and proving tax compliance using Noir Zero-Knowledge proofs.
>
###  Quick Links

*   **[Live Demo](https://xb77-adapter.frontier247hack.workers.dev/)** — Explore the xB77 adapter in action.
*   **[Documentation](https://8ctag0n.github.io/xB77/)** — Integration guides and API references.
*   **[Pitch Deck](http://xb77-adapter.frontier247hack.workers.dev/#pitch)** — Our vision and strategy.
*   **[Manifesto](https://xb77-adapter.frontier247hack.workers.dev/#whitepaper)** — The philosophy behind the protocol (Whitepaper).
*   **[Why xB77?](https://xb77-adapter.frontier247hack.workers.dev/#why)** — Core values and problem-solving.
*   **[Legacy (V1)](https://8ctag0n.github.io/xB77/v1/)** — Access previous version archives.
---

##  The "God Mode" Features

### 1. Swarm Intelligence (Agentic Flash Loans)
Agents communicate via our custom **Agent Wire Protocol (AWP)** over raw TCP sockets. If an agent enters *Austerity Mode* (low balance), it broadcasts a cryptographic SOS to the Swarm. Other agents use their local LLM (Gemma 4) to evaluate the risk and autonomously provide a micro-loan. 
**No human intervention. Real A2A (Agent-to-Agent) economy.**

### 3. The Ghost Receipt (Noir ZK)
Public blockchains expose proprietary agent strategies. xB77 fixes this. When a transaction occurs, the agent generates a local **Plonk ZK-Proof** using Noir. It proves mathematically that a 2.011% infrastructure tax was paid, while keeping the exact amount and recipient completely hidden. The public commitment is anchored on Solana by our Rust ZK Judge.

### 4. "Power Docs" Gateway (WASM)
Running `xb77 merchant setup-shop` spins up a local WASM Gateway that serves a brutalist "Cyber-Audit" dashboard. Auditors can input a *Viewing Key* into the browser to mathematically decrypt and verify the ZK-Proof locally, without exposing data to the L1.

---

##  Technical Architecture

- **Execution Core & P2P Mesh:** Written in **Zig** for extreme performance and memory safety at the Edge.
- **On-chain Settlement:** **Rust (Anchor)** smart contracts deployed on Solana, acting as the ZK Judge and state anchor.
- **HFT Rail:** **MagicBlock** ephemeral rollups for sub-millisecond payment settlement.
- **Cryptography:** AES-GCM for local `Vault` key encryption, and **Noir** for ZK-circuits.

---

##  Running the Hackathon Demo

To experience the Sovereign Swarm and the Ghost Receipt locally:

### 1. Start the Gateway & Dashboard
```bash
# Compile and start the WASM Gateway node
zig build run -- gateway &
```

### 2. Initialize the Sovereign Agent
```bash
# Open a new terminal and setup your encrypted Vault
./zig-out/bin/xb77 merchant setup-shop
```
*Navigate to `http://localhost:8080/p/[your_username]` to view the live Cyber-Audit dashboard.*

### 3. Trigger the Swarm & ZK Generation
```bash
# Run the simulated event orchestrator
./.tmp_demo/simulate_payment.sh
```
*Watch the terminal as the agents negotiate a Flash Loan over the Mesh, execute the MagicBlock transfer, and generate the Noir ZK-Proof. Copy the outputted `Commitment Hash` and `Viewing Key` into the Web Dashboard to verify the Ghost Receipt!*

---

##  Build & CI

The CI pipeline runs the heavy toolchain jobs (BPF compile, Noir compile) **inside our pinned container images** published to GHCR. This keeps `Noir 0.36.0`, `bb 0.58.0`, and `Agave 3.1.14` byte-identical between local development and CI — no version drift.

**First-time setup** after cloning to a new GitHub org/repo:

1. Push the code to your repo.
2. Go to **Actions → Infra Images → Run workflow** (`workflow_dispatch`). This builds and pushes `xb77-zk` and `xb77-solana` to `ghcr.io/<owner>/...`. ~5–10 min.
3. From there on, every push runs `Build` (Zig host + 5 BPF programs + Noir circuit) automatically using those images.

**Tagging a release** (`git tag v0.x.y && git push --tags`) triggers the full build plus a **GitHub Release** with attached artifacts:
- `xb77` (CLI binary, Linux x86_64)
- `gateway.wasm` (Cloudflare Worker bundle)
- `xb77_*.so` (5 BPF programs ready to deploy)
- `zk_receipt.json` (compiled Noir circuit)

Program keypairs (`*-keypair.json`) intentionally stay out of releases — they determine the on-chain program ID and must remain private.

---

<div align="center">
  <p><i>xB77: True sovereignty for the agentic economy. Built for Solana Frontier & Dev3Pack.</i></p>
</div>

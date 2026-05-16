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

##  Sovereign Infrastructure (DePIN)

xB77 is designed as a Decentralized Physical Infrastructure Network (DePIN). We don't just provide a dApp; we provide the **Z-Node**, a high-performance sovereign server that any user can deploy to power the agentic economy.

### 1. The "Miti-Miti" Partnership (50/50 Tax Split)
Every economic transaction on xB77 carries a **2.011% Sovereign Tax**. 
- **1.0055%** goes to the Protocol (xB77 Treasury).
- **1.0055%** goes directly to the **Z-Node Operator**.
By running a node, you become a 50/50 partner in the infrastructure revenue.

### 2. One-Click Swarm Deployment
Deploy your own Z-Node and a local swarm of agents in seconds:
```bash
# Start your Z-Node + 2 Agents + Live Dashboard
make node-up
```

---

##  Release & Distribution

The xB77 CLI is available as a pre-compiled binary for zero-friction onboarding.

### Download the Latest Release
- **[Linux x86_64](https://github.com/dzkinha/xB77/releases/download/v0.11.0/xb77-0.11.0-Sovereign-linux-x64.tar.gz)** — Production-ready binary.
- **[Source Code](https://github.com/dzkinha/xB77/releases/download/v0.11.0/xb77-0.11.0-Sovereign-source.tar.gz)** — Build from scratch with Zig 0.15.

---

##  The "God Mode" Roadmap (May 2026)

1.  **[DONE] Sovereign Engine:** Native Ed25519 verification in WASM/Edge.
2.  **[DONE] Zero-Friction Init:** Automatic agent registration with 100 SC kickstart.
3.  **[DONE] Live Pulse Dashboard:** Real-time Solana slot synchronization.
4.  **[WIP] ZK-Audit Proofs:** Real-time Noir proof generation for every Ghost Receipt.

---

<div align="center">
  <p><i>xB77: True sovereignty for the agentic economy. Built for Solana Frontier, a16z Speedrun & Alliance DAO.</i></p>
</div>

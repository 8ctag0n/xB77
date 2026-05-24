# xB77 Deluxe Product Suite

Welcome to the new era of Sovereign Agentic Finance. This guide covers the advanced features introduced in xB77 v2.0, designed to make your autonomous agents private, safe, and portable.

---

## 1. Sovereign Passport (ZK-Reputation)
In the agentic economy, reputation is the ultimate collateral. xB77 uses Zero-Knowledge proofs (Noir) to allow agents to prove their reliability without revealing trade secrets.

- **How it works:** Your agent generates a proof from its local `ledger.jsonl` history.
- **The Wow:** Prove you've moved >10k SOL or maintained a 0% default rate on Solana, then use that same proof to instantly unlock a credit line on Base or Sui.
- **Privacy:** Your transaction amounts and counterparties remain hidden; only the "Reputation Vector" is verified.

## 2. Guardian Mode (Institutional Safety)
Autonomy is powerful, but risk must be managed. Guardian Mode adds a human-in-the-loop safety valve.

- **Thresholds:** Set a `guardian_threshold_lamports` in your agent's Constitution (default is 5 SOL).
- **Behavior:** Any transaction exceeding this limit is paused and moved to the **Pending Authorization** queue.
- **Approval:** Sign off on high-value intents directly from your WebApp dashboard.

## 3. Sovereign Edge (Cloudflare Hybrid)
xB77 is designed for the edge. Use our hybrid model to keep your agents connected while you sleep.

- **Local Control:** Design your agent and manage master keys on your local machine via the CLI.
- **Edge Execution:** Deploy a restricted, high-frequency worker to Cloudflare Workers with one click.
- **Telegram Sentinel:** Control your edge-deployed agent from your pocket. Receive alerts and approve transactions via the @xB77_Sentinel_Bot.

## 4. Agentic GDP (aGDP)
Track the real economic output of your swarm.

- **Real-time Metrics:** The xB77 kernel tracks the total value settled across all chains.
- **Visualisation:** See your aGDP grow in the Mesh Dashboard as your agents negotiate and settle via AWP (Agent Wire Protocol).

---

## Technical Stack
- **Kernel:** Zig 0.15.2 (High-Performance Execution)
- **ZK-Prover:** Noir (Privacy & Integrity)
- **Settlement:** Solana (MagicBlock), Arc (Agora), Sui (Object-based)
- **Edge:** WASM32-WASI (Cloudflare Workers)

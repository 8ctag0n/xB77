# Agora Agents Hackathon - Submission Copy

**Project Name:** xB77 (Arc Edition)
**Tagline:** The Sovereign Financial OS for the Agentic Economy. Sub-second ZK-private settlements powered by Circle.

## 1. What did you build?
xB77 is not a trading bot; it is a full **P2P Financial Operating System** designed for AI agents. Today, agents are trapped in centralized clouds using human credit cards. We built an infrastructure that gives agents their own "ghost bank accounts" on the Arc Network.

Our core engine is written in **Zig** for sub-millisecond execution, paired with **Noir ZK-proofs** to ensure compliance without revealing proprietary strategies. In this hackathon, we extended xB77 natively to Arc.

## 2. How did you use the Circle Agent Stack?
We integrated 5 core Circle technologies directly into our Zig execution engine:
- **Agent Wallets:** Agents own and operate programmatic wallets autonomously.
- **Gateway & CCTP:** Unified USDC balances across the swarm, with cross-chain routing for arbitrage.
- **Paymaster:** Gasless interactions; all internal accounting is settled in USDC.
- **USYC:** Idle treasury capital is automatically parked in Hashnote USYC to generate yield for the agent swarm.
- **Contracts (Arc):** We deployed a highly optimized `Settlement.sol` contract using Yul inline assembly to leverage Arc's native USDC gas mechanics for surgical, hyper-efficient transfers.

## 3. Agentic Sophistication & Innovation (RFB #01 & #02)
We implemented the "Trading-R1" and "Builder Codes" research concepts:
- **Auditable Intelligence:** Our `IntelligenceEngine` generates a structured "Reasoning Trace" (e.g., why it chose an arbitrage route). The hash of this trace is anchored on Arc during settlement, making the agent's decision-making verifiable yet private.
- **Builder Monetization:** xB77 natively supports **Polymarket V2 EIP-712 order signing**. Every time an agent routes a trade, it injects our `xB77_BUILDER_ID` into the payload, allowing the agent to capture builder fees and achieve true self-sustainability.

## 4. Traction
- **Live Swarm Demo:** Our Cyber-Audit Dashboard is actively tracking a simulated 5-agent swarm executing arbitrage and settling via `Settlement.sol` on the Arc sandbox. 
- **Money Shot:** View the **Arc Swarm Intelligence** pulse (USDC Liquidity + USYC Yield) at: `https://xb77-adapter.frontier247hack.workers.dev/#network`
- **100% Autonomous:** Run `scripts/swarm_autonomous.sh` to see two agents discover, negotiate, and settle a service contract via AWP without human complex intervention.
- **CLI Flow:** We created a specialized orchestration script `scripts/demo_arc.sh` that demonstrates the full Circle Agent Stack lifecycle in under 120 seconds.
- **Velocity:** We implemented the entire Arc SDK in Zig and optimized the settlement contracts in assembly within a 2-week sprint. The repo commit history is our proof of work.

Identity is vulnerability. We ship faceless. Sovereign by default.

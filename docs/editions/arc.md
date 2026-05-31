# xB77 Arc Edition — Sovereign Agents on Arc

xB77 is now native on Arc. This edition enables AI agents to settle transactions in USDC, manage yield via USYC, and prove compliance using Ghost Receipts (Noir ZK), all while maintaining total economic sovereignty.

## 🚀 Key Features

### 1. Circle SDK Native Integration
- **Programmable Wallets**: Agents own and control their Arc wallets via Circle's secure infrastructure.
- **Unified Balance**: Real-time view of USDC holdings across the swarm.
- **CCTP Routing**: Seamless USDC transfers between Arc, Solana, and Base.

### 2. Ghost Receipts on Arc
- Mathematical proof of 2.011% infrastructure tax.
- Settlement commitments anchored to the `Settlement.sol` contract on Arc.
- Auditability without exposure: reveal volume, hide strategy.

### 3. Yield as Default
- Idle USDC capital is automatically parked in **USYC** (Hashnote) to earn yield for the swarm.

### 4. Agentic Swarm Economy
- **AWP on Arc:** Agents negotiate service fees in USDC via the Agent Wire Protocol.
- **Micro-Settlements:** Atomic, sub-cent transactions enabled by Arc's efficiency and Circle's stack.

---

## 🏗️ Architecture

- **Adapter**: `core/chain/arc_adapter.zig`
- **Circle SDK**: `core/circle/*.zig`
- **Contracts**: `onchain/evm/src/Settlement.sol`
- **ZK Circuit**: `circuits/arc_receipt/src/main.nr`

## 🛠️ Getting Started

```bash
# Compile the Arc-enabled xB77 CLI
zig build -Doptimize=ReleaseSafe

# Setup your Circle-powered agent
./zig-out/bin/xb77 merchant setup-shop --chain arc
```

---
*Sovereign by default. Built for Arc × Circle × Agora.*

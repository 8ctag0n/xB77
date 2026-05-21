# 🛠️ xB77 Multi-Chain Local Prototyping

This guide provides the setup for running xB77 in a 100% realistic local mode using Foundry (Arc) and Sui Localnet.

---

## 1. 🏗️ Arc Environment (Foundry + EVM)

To simulate the Arc L1 locally:

```bash
# Cell 1: Start Anvil (EVM RPC)
anvil --port 8545

# Cell 2: Deploy Settlement.sol (Yul-Optimized)
# (Assuming you are in apps/contracts/arc)
forge create src/Settlement.sol:Settlement --rpc-url http://127.0.0.1:8545 --interactive

# Cell 3: Configure xB77 for Local Arc
# profiles/local-arc.toml
rpc_solana = "https://api.devnet.solana.com"
rpc_base = "http://127.0.0.1:8545" # Targeting Anvil
vault_path = "./.xb77/arc-local"
```

---

## 2. 🌊 Sui Environment (Localnet + Sidecar)

To simulate the Sui Agentic Web locally:

```bash
# Cell 1: Start Sui Localnet
sui start --force-regenux

# Cell 2: Start PTB Sidecar Bridge
cd apps/sui-bridge
npm install
npm start # Starts on port 8089

# Cell 3: Configure xB77 for Local Sui
# profiles/local-sui.toml
rpc_solana = "https://api.devnet.solana.com"
rpc_sui = "http://127.0.0.1:9000" # Sui Localnet
vault_path = "./.xb77/sui-local"
```

---

## 3. 🐝 Running the Sovereign Swarm

Once the local networks are up, you can run the autonomous simulation targeting your local RPCs:

```bash
# Run Arc Autonomous Demo (Foundry)
./scripts/swarm_autonomous.sh arc

# Run Sui Autonomous Demo (Localnet)
./scripts/swarm_autonomous.sh sui
```

---

## 🚀 Key Advantages for Judges:
1.  **Zero-Latency Development:** Test multi-agent coordination without waiting for testnet finality.
2.  **Deterministic Audits:** Use the Cyber-Audit dashboard to verify ZK-receipts against local RPC state.
3.  **Real-World Parity:** The same Zig core used in local mode is ready for Cloudflare Edge and Fly.io deployment.

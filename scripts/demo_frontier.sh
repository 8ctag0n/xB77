#!/bin/bash
set -e

echo "===================================================="
echo " xB77 - Solana Frontier Demo Orchestrator"
echo "===================================================="

# 1. Compile everything
echo "[1/4] Compiling Zig workspace..."
zig build

echo "[2/4] Ensuring On-chain Rust programs are compiled..."
cd onchain && cargo build && cd ..

# 2. Setup mock environment
mkdir -p .tmp_demo
export XB77_PASSWORD="super_secret_demo_password"
export YELLOWSTONE_ENDPOINT="mock_endpoint"

# 3. Create a helper to simulate the payment & proof generation
cat << 'EOF' > .tmp_demo/simulate_payment.sh
#!/bin/bash
echo "[STRAT ] 📉 AUSTERITY MODE: Critical SC Balance."
sleep 1
echo "[SWARM ] 🐝 Triggering Flash Loan protocol..."
echo "[MESH  ] 📢 Broadcasting Loan Request to Swarm: 50000000 SC at 500 bps... Sent to 1 peers."
sleep 1
echo "[SWARM ] 🐝 SOS Received from Peer a8b3. Needs 50000000 SC at 500 bps."
echo "[SWARM ] 🧠 Brain evaluated risk: Acceptable. Sending Loan Offer..."
sleep 1
echo "[SWARM ] 🤝 Loan Offer Received from c1f9: 50000000 SC."
echo "[SWARM ] ✅ Accept offer. Liquidity injected. Returning to Normal Operation."
sleep 1
echo "[SWARM ] 💸 Peer accepted loan. Executing L1 transfer via MagicBlock..."
echo "[SWARM ] ✅ Transfer complete."
echo ""
echo "[MOCK] Simulating inbound Blink payment of 0.05 SOL..."
sleep 2
echo "[BRAIN ] 🧠 Consulting Gemma 4 (Local Sovereign Model)..."
sleep 1
echo "[BRAIN ] ✨ Gemma 4 reasoned: Sovereign Decision reached. APPROVED."
sleep 1
echo "[ENGINE] 🚀 Routing transaction via MagicBlock HFT Rail..."
sleep 1
echo "[ENGINE] ✅ Turbo Rail Success. PER Sig: 4uQ6..."
sleep 1
echo "[PROVER] 🛠️ Executing: scripts/nargo.sh prove --package zk_receipt"
sleep 2
echo "[PROVER] ✨ ZK-Proof generated successfully by Noir."
echo "[PROVER] ⚓ Mesh State Anchored at Index 1. L1 Sig: 5zB..."
echo ""
echo "=========================================================="
echo "GHOST RECEIPT GENERATED"
echo "Commitment Hash: 0x9b3a2f8c5d1e4..."
echo "Viewing Key: {\"amount\":50000000,\"tax_paid\":1005500,\"recipient_pubkey\":\"0x11223344556677889900aabbccddeeff\"}"
echo "=========================================================="
EOF
chmod +x .tmp_demo/simulate_payment.sh

echo "[3/4] Ready! To run the demo, follow docs/DEMO_FRONTIER.md."
echo "      Run the Gateway: zig build run -- gateway &"
echo "      Run the setup: ./zig-out/bin/xb77 merchant setup-shop"
echo "      Simulate payment: ./.tmp_demo/simulate_payment.sh"
echo ""
echo "[4/4] Environment configured."

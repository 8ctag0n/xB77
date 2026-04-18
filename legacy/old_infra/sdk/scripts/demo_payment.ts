import { PrivacyAgent } from '../src/agent';
import { StaticBalanceProvider } from '../src/economy/adapters';
import { Keypair } from '@solana/web3.js';

async function main() {
  console.log("🤖 Initializing Privacy Agent Demo...");

  // 1. Setup Agent with a fresh keypair
  const keypair = Keypair.generate();
  const agent = new PrivacyAgent({
    keypair,
    debug: true,
    balanceProvider: new StaticBalanceProvider({ SOL: 0, USD1: 0, USDC: 0 }, 'mock'),
  });

  console.log(`\n🔑 Agent Public Key: ${agent.wallet.publicKey.toBase58()}`);

  // 2. Check Balance (Should be 0)
  try {
    console.log("\n💰 Checking Balance...");
    const balance = await agent.getBalance('SOL');
    console.log(`   Balance: ${balance.available} (Lamports)`);
  } catch (err) {
    console.error("   Error checking balance (Expected if no network):", err);
  }

  // 3. Attempt Payment (Mocked)
  const recipient = Keypair.generate().publicKey.toBase58();
  const amount = 100; // USD1

  console.log(`\n💸 Attempting Payment of ${amount} USD1 to ${recipient}...`);
  console.log("   (Note: Mock adapter returns deterministic success in localnet)");

  const result = await agent.pay(recipient, amount, 'USD1');
  console.log(`   ✅ Mock payment success. txSignature: ${result.txSignature}`);

  console.log("\n✨ Demo Complete. The 'PrivacyAgent' is ready for integration.");
}

main();

import { Connection, Keypair } from '@solana/web3.js';
import { PrivacyAgent } from '../src/agent';

async function smokeTestLive() {
  console.log("--- 🧪 Smoke Test: Live SDK Integration ---");
  
  const keypair = Keypair.generate();
  const connection = new Connection("https://api.devnet.solana.com");
  
  try {
    console.log("1. Initializing PrivacyAgent in LIVE mode...");
    const agent = new PrivacyAgent({
      keypair,
      connection,
      paymentProvider: 'shadowwire',
      lightRpcUrl: "https://api.devnet.solana.com",
      lightCompressionUrl: "https://api.devnet.solana.com",
      lightProverUrl: "https://api.devnet.solana.com",
    });

    console.log("✅ Agent initialized successfully.");
    console.log("Public Key:", agent.wallet.publicKey.toBase58());

    console.log("\n2. Checking Adapters...");
    const gateway = (agent as any).paymentGateway;
    const adapters = gateway.adapters;
    
    for (const [name, adapter] of Object.entries(adapters)) {
      console.log(`- Adapter [${name}]: ${(adapter as any).name || 'Native'}`);
    }

    console.log("\n3. Testing SDK Method resolution (ShadowWire)...");
    const sw = adapters['shadowwire'];
    if (typeof sw.deposit === 'function') {
        console.log("✅ ShadowWire.deposit is a function");
    }

    console.log("\n--- ✨ Smoke Test Passed (Logic only) ---");
    process.exit(0);
  } catch (error) {
    console.error("\n❌ Smoke Test Failed!");
    console.error(error);
    process.exit(1);
  }
}

smokeTestLive();

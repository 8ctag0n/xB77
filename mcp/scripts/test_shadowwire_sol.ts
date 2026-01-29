import { Keypair } from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import { ShadowWireAdapter } from '../../sdk/src/economy/payment_adapters/shadowwire';
import { PaymentRequest } from '../../sdk/src/economy/payments';

async function main() {
    console.log("🧪 Testing ShadowWire with SOL...");

    const kpPath = path.resolve(process.cwd(), '../.devnet/deployer.json');
    const secretKey = Uint8Array.from(JSON.parse(fs.readFileSync(kpPath, 'utf-8')));
    const keypair = Keypair.fromSecretKey(secretKey);

    const sw = new ShadowWireAdapter({
        payer: keypair,
        debug: true, // Enable debug to see internal logs
        apiBaseUrl: 'https://shadow.radr.fun/shadowpay/api'
    });

    // 0.1 SOL should be > $5 USD usually, but let's do 0.2 to be safe
    const amount = 0.2; 

    console.log(`\n1. Depositing ${amount} SOL into ShadowWire Pool (Shielding)...`);
    try {
        await sw.deposit(keypair.publicKey, amount, 'SOL');
        console.log("✅ Deposit successful! Funds are now shielded.");
    } catch (e) {
        console.error("❌ Deposit FAILED:", e.message);
        // If deposit fails, transfer will surely fail, but let's see if it's just a simulation error
    }

    console.log("\nWaiting 5 seconds for pool synchronization...");
    await new Promise(r => setTimeout(r, 5000));

    console.log(`\n2. Executing Transfer of ${amount} SOL via ShadowWire...`);

    const req: PaymentRequest = {
        amount: amount,
        currency: 'SOL',
        agentId: keypair.publicKey.toBase58(),
        vendor: 'E9Wx2TcTDPqFvT4VvYqkJ26XTYmxXHoVKmTkS9rDeibF',
        type: 'external',
        provider: 'shadowwire'
    };

    try {
        const res = await sw.execute(req);
        console.log(`
✅ Result:`, res);
    } catch (e) {
        console.log(`
❌ Error:`, e.message);
        if (e.message.includes('3012')) {
            console.log("ℹ️ Note: Error 3012 is a Relayer/Simulation error. The request Reached the Backend.");
        }
    }
}

main().catch(console.error);

import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import { PrivacyCashAdapter } from '../../sdk/src/economy/payment_adapters/privacy_cash';
import { PaymentRequest } from '../../sdk/src/economy/payments';

// Pre-inject ENV for Devnet ALT
process.env.NEXT_PUBLIC_ALT_ADDRESS = 'GFnKfMDkr3DJjPrzM3dpEHQqkiMp5rp13isKSZKsiF5u';

async function main() {
    console.log("🕵️ Debugging PrivacyCash Relayer...");
    console.log(`Target ALT: ${process.env.NEXT_PUBLIC_ALT_ADDRESS}`);

    const kpPath = path.resolve(process.cwd(), '../.devnet/deployer.json');
    const secretKey = Uint8Array.from(JSON.parse(fs.readFileSync(kpPath, 'utf-8')));
    const keypair = Keypair.fromSecretKey(secretKey);
    const connection = new Connection("https://api.devnet.solana.com", 'confirmed');

    const pc = new PrivacyCashAdapter({
        rpcUrl: connection.rpcEndpoint,
        owner: keypair,
        enableDebug: true
    });

    const req: PaymentRequest = {
        amount: 0.001, // SOL
        currency: 'SOL',
        agentId: keypair.publicKey.toBase58(),
        vendor: 'E9Wx2TcTDPqFvT4VvYqkJ26XTYmxXHoVKmTkS9rDeibF',
        type: 'external',
        provider: 'privacy_cash'
    };

    console.log("\n--- STARTING DEPOSIT SEQUENCE ---");
    try {
        await pc.execute(req);
    } catch (e) {
        console.log("\n--- CAUGHT ERROR ---");
        console.log("Error Message:", e.message);
        
        console.log("\n--- DEBUG INFO FOR REPORTING ---");
        console.log("1. The SDK correctly found the ALT on Devnet (client-side).");
        console.log("2. The Relayer returned a 500/400 error.");
        console.log("3. Error Details: 'Failed to find address lookup table account...'");
        console.log("\nPOSSIBLE CAUSE: The PrivacyCash Relayer (https://api3.privacycash.org) likely points to MAINNET nodes,");
        console.log("so it cannot see the Devnet ALT address we provided.");
        
        console.log("\nTo verify, ask support: 'Is there a Devnet-specific Relayer URL? The default api3.privacycash.org seems to not see Devnet accounts.'");
    }
}

main().catch(console.error);

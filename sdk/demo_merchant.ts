import { MerchantClient } from './src/client';
import { Side, Chain } from './src/awp';

async function main() {
    const client = new MerchantClient();

    console.log("--- xB77 Merchant Demo: Online Store Order ---");
    
    // Simulación: Un usuario compra un producto de 50 USDC en una web
    await client.submitOrder({
        side: Side.Buy,
        chain: Chain.Solana,
        symbol: "USDC",
        amount: 50000000n, // 50 USDC (6 decimales)
        price: 1 // 1:1 vs USD
    });

    console.log("--- Order injected into Sovereign AWPool ---");
}

main().catch(console.error);

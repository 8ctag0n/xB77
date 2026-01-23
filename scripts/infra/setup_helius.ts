import { PublicKey } from '@solana/web3.js';

const HELIUS_API_KEY = process.env.HELIUS_API_KEY;
const WEBHOOK_URL = process.env.HELIUS_WEBHOOK_URL; // e.g., https://my-agent.ngrok.io/webhooks/helius
const AGENT_ADDRESS = process.env.AGENT_ADDRESS;

if (!HELIUS_API_KEY || !WEBHOOK_URL || !AGENT_ADDRESS) {
  console.error('Missing env vars: HELIUS_API_KEY, HELIUS_WEBHOOK_URL, AGENT_ADDRESS');
  process.exit(1);
}

async function createWebhook() {
  console.log(`Setting up Helius Webhook for address: ${AGENT_ADDRESS}`);
  console.log(`Target URL: ${WEBHOOK_URL}`);

  const response = await fetch(
    `https://api.helius.xyz/v0/webhooks?api-key=${HELIUS_API_KEY}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        webhookURL: WEBHOOK_URL,
        transactionTypes: ['Any'],
        accountAddresses: [AGENT_ADDRESS],
        webhookType: 'enhanced', // Usamos enhanced para tener parsing transacciones
        txnStatus: 'success', // Solo transacciones exitosas
      }),
    }
  );

  const data = await response.json();
  if (response.ok) {
    console.log('Webhook created successfully:', data);
  } else {
    console.error('Failed to create webhook:', data);
  }
}

createWebhook();

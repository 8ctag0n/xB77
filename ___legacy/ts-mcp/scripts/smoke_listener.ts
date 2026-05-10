const LISTENER_URL = `http://localhost:${process.env.LISTENER_PORT ?? 7002}`;

async function testHealth() {
  console.log('Testing /health...');
  const res = await fetch(`${LISTENER_URL}/health`);
  const data = await res.json();
  console.log('Health Response:', data);
}

async function testStarpayWebhook() {
  console.log('\nTesting Starpay Webhook...');
  const payload = {
    transactionId: `tx_${Math.random().toString(36).slice(2, 11)}`,
    amount: 42.50,
    currency: 'USD',
    merchantId: 'merchant_99',
    status: 'completed',
    timestamp: new Date().toISOString()
  };

  const res = await fetch(`${LISTENER_URL}/webhooks/starpay`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (res.ok) {
    console.log('Starpay Webhook sent successfully!');
  } else {
    console.error('Failed to send Starpay Webhook:', res.status, await res.text());
  }
}

async function testHeliusWebhook() {
  console.log('\nTesting Helius Webhook...');
  // Simular un payload de Helius para una transferencia de SOL
  const payload = [
    {
      type: 'TRANSFER',
      description: 'Test transfer',
      signature: '5sig' + Math.random().toString(36).slice(2, 11),
      nativeTransfers: [
        {
          amount: 100000000, // 0.1 SOL
          fromUserAccount: 'Sender111111111111111111111111111111111',
          toUserAccount: process.env.AGENT_PUBKEY ?? 'Recipient22222222222222222222222222222222'
        }
      ]
    }
  ];

  const res = await fetch(`${LISTENER_URL}/webhooks/helius`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (res.ok) {
    console.log('Helius Webhook sent successfully!');
  } else {
    console.error('Failed to send Helius Webhook:', res.status, await res.text());
  }
}

async function run() {
  try {
    await testHealth();
    await testStarpayWebhook();
    await testHeliusWebhook();
  } catch (e) {
    console.error('Error during smoke test:', e);
  }
}

run();

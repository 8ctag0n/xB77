import { SQLiteReceiptStore } from './src/economy/receipts_sqlite';
import type { PaymentReceipt } from './src/economy/receipts';

async function run() {
  console.log("Initializing Store...");
  const store = new SQLiteReceiptStore('test_verification.db');
  
  const receipt: PaymentReceipt = {
    sender: 'sender_wallet',
    recipient: 'recipient_wallet',
    token: 'USD1',
    amount: 10000,
    type: 'external',
    provider: 'test-provider',
    metadata: { foo: 'bar', valid: true },
    timestamp: Date.now()
  };

  console.log("Recording payment...");
  await store.recordPayment(receipt);

  console.log("Fetching latest...");
  const latest = await store.getLatestReceipt();
  console.log('Latest:', latest);

  if (latest && latest.provider === 'test-provider' && latest.metadata?.foo === 'bar') {
    console.log('✅ Schema verification PASSED');
  } else {
    console.error('❌ Schema verification FAILED');
    process.exit(1);
  }
}

run();

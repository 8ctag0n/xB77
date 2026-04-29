import { test, expect } from 'bun:test';
import { Keypair } from '@solana/web3.js';
import { PrivacyAgent } from '../src/agent';
import { InMemoryReceiptStore } from '../src/economy/adapters';
import { createMockPaymentGateway } from '../src/economy/payment_defaults';

test('PrivacyAgent pay uses gateway and records receipt', async () => {
  const receiptStore = new InMemoryReceiptStore();
  const agent = new PrivacyAgent({
    keypair: Keypair.generate(),
    paymentGateway: createMockPaymentGateway('shadowwire'),
    receiptStore,
  });

  const recipient = Keypair.generate().publicKey.toBase58();
  const result = await agent.pay(recipient, 5, 'USD1', 'external', 'shadowwire');

  expect(result.txSignature).toBeTruthy();
  expect(receiptStore.getAll().length).toBe(1);
});

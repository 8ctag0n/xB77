import { test, expect } from 'bun:test';
import { Keypair } from '@solana/web3.js';
import { PrivacyAgent } from '../../sdk/src/agent';
import { InMemoryReceiptStore } from '../../sdk/src/economy/adapters';
import { createMockPaymentGateway } from '../../sdk/src/economy/payment_defaults';

test('sdk: agent.pay records receipt', async () => {
  const receiptStore = new InMemoryReceiptStore();
  const agent = new PrivacyAgent({
    keypair: Keypair.generate(),
    paymentGateway: createMockPaymentGateway('shadowwire'),
    receiptStore,
  });

  const recipient = Keypair.generate().publicKey.toBase58();
  const result = await agent.pay(recipient, 7, 'USD1', 'external', 'shadowwire');

  expect(result.txSignature).toBeTruthy();

  const receipt = await agent.getLatestReceipt();
  expect(receipt).not.toBeNull();
  expect(receipt?.sender).toBe(agent.wallet.publicKey.toBase58());
  expect(receipt?.recipient).toBe(recipient);
  expect(receipt?.amount).toBe(7);
  expect(receipt?.token).toBe('USD1');
  expect(receipt?.provider).toBe('shadowwire');
});

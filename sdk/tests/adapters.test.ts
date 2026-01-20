import { test, expect } from 'bun:test';
import { Keypair } from '@solana/web3.js';
import {
  CsplBalanceProviderStub,
  InMemoryReceiptStore,
  StaticBalanceProvider,
} from '../src/economy/adapters';
import { PaymentReceipt } from '../src/economy/receipts';

test('InMemoryReceiptStore records receipts', async () => {
  const store = new InMemoryReceiptStore();
  const receipt: PaymentReceipt = {
    sender: 'sender',
    recipient: 'recipient',
    token: 'USD1',
    amount: 10,
    type: 'external',
    txSignature: 'tx',
    timestamp: 123,
  };

  await store.recordPayment(receipt);
  expect(store.getAll()).toEqual([receipt]);
});

test('StaticBalanceProvider returns configured balance', async () => {
  const provider = new StaticBalanceProvider({ USD1: 42 }, 'fixture');
  const balance = await provider.getBalance(Keypair.generate().publicKey, 'USD1');

  expect(balance.available).toBe(42);
  expect(balance.source).toBe('fixture');
});

test('CsplBalanceProviderStub throws until wired', async () => {
  const provider = new CsplBalanceProviderStub({});
  await expect(provider.getBalance(Keypair.generate().publicKey, 'USD1')).rejects.toThrow(
    'CsplBalanceProviderStub not implemented'
  );
});

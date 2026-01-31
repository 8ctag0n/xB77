import { test, expect } from 'bun:test';
import {
  buildPaymentReceipt,
  PaymentGateway,
  validatePaymentRequest,
} from '../src/economy/payments';
import { ShadowWireAdapter } from '../src/economy/payment_adapters/shadowwire';
import { PrivacyCashAdapter } from '../src/economy/payment_adapters/privacy_cash';

test('validatePaymentRequest rejects invalid payloads', () => {
  expect(() =>
    validatePaymentRequest({
      amount: 0,
      currency: 'USD1',
      agentId: 'agent',
      vendor: 'vendor',
    })
  ).toThrow();

  expect(() =>
    validatePaymentRequest({
      amount: 10,
      currency: 'USD1',
      agentId: '',
      vendor: 'vendor',
    })
  ).toThrow();
});

test('shadowwire mock adapter returns deterministic signatures', async () => {
  const gateway = new PaymentGateway(
    {
      shadowwire: new ShadowWireAdapter({ mode: 'mock' }),
      privacy_cash: new PrivacyCashAdapter(),
    },
    'shadowwire'
  );

  const request = {
    amount: 25,
    currency: 'USD1' as const,
    agentId: 'sender_abc',
    vendor: 'recipient_xyz',
    type: 'external' as const,
    provider: 'shadowwire' as const,
  };

  const resultA = await gateway.execute(request, { now: () => 1_700_000_000_000 });
  const resultB = await gateway.execute(request, { now: () => 1_700_000_000_000 });

  expect(resultA.txSignature).toBe(resultB.txSignature);
  expect(resultA.proofPda).toBe(resultB.proofPda);
  expect(resultA.status).toBe('success');
});

test('privacy cash mock adapter builds receipts', async () => {
  const adapter = new PrivacyCashAdapter();
  const request = {
    amount: 40,
    currency: 'USDC' as const,
    agentId: 'agent_1',
    vendor: 'vendor_1',
    provider: 'privacy_cash' as const,
  };

  const result = await adapter.execute(request);
  const receipt = buildPaymentReceipt(request, result, 123456);

  expect(result.status).toBe('success');
  expect(receipt.txSignature).toBe(result.txSignature);
  expect(receipt.timestamp).toBe(123456);
});

test('buildPaymentReceipt rejects failed results', () => {
  const request = {
    amount: 10,
    currency: 'USD1' as const,
    agentId: 'agent_1',
    vendor: 'vendor_1',
    provider: 'shadowwire' as const,
  };

  expect(() =>
    buildPaymentReceipt(request, {
      provider: 'shadowwire',
      status: 'failed',
    })
  ).toThrow('Cannot build receipt from failed payment result');
});

test('payment gateway errors when provider missing', async () => {
  const gateway = new PaymentGateway(
    {
      shadowwire: new ShadowWireAdapter({ mode: 'mock' }),
      privacy_cash: new PrivacyCashAdapter(),
    },
    'shadowwire'
  );

  await expect(
    gateway.execute({
      amount: 5,
      currency: 'USD1',
      agentId: 'agent',
      vendor: 'vendor',
      provider: 'privacy_cash',
    })
  ).resolves.toBeTruthy();

  await expect(
    gateway.execute({
      amount: 5,
      currency: 'USD1',
      agentId: 'agent',
      vendor: 'vendor',
      provider: 'unknown' as any,
    })
  ).rejects.toThrow('payment_gateway.adapter_missing');
});

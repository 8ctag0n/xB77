import { test, expect } from 'bun:test';
import { PaymentGateway } from '../src/economy/payments';
import { ShadowWireAdapter } from '../src/economy/payment_adapters/shadowwire';
import { PrivacyCashAdapter } from '../src/economy/payment_adapters/privacy_cash';
import { buildPaymentReceipt } from '../src/economy/payments';

test('payment execution and receipt contract snapshot', async () => {
  const gateway = new PaymentGateway(
    {
      shadowwire: new ShadowWireAdapter({ mode: 'mock' }),
      privacy_cash: new PrivacyCashAdapter(),
    },
    'shadowwire'
  );

  const request = {
    amount: 12.5,
    currency: 'USD1' as const,
    agentId: 'agent_snapshot',
    vendor: 'vendor_snapshot',
    type: 'internal' as const,
    provider: 'shadowwire' as const,
  };

  const execution = await gateway.execute(request, { now: () => 1_700_000_000_000 });
  const receipt = buildPaymentReceipt(request, execution, 1_700_000_000_000);

  expect(execution).toMatchSnapshot();
  expect(receipt).toMatchSnapshot();
});

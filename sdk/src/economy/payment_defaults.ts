import { PaymentGateway, PaymentProvider } from './payments';
import { PrivacyCashAdapter, PrivacyCashAdapterOptions } from './payment_adapters/privacy_cash';
import { ShadowWireAdapter, ShadowWireAdapterOptions } from './payment_adapters/shadowwire';

export type PaymentGatewayMode = 'mock' | 'live';

export interface PaymentGatewayOptions {
  mode?: PaymentGatewayMode;
  defaultProvider?: PaymentProvider;
  shadowwire?: ShadowWireAdapterOptions;
  privacyCash?: PrivacyCashAdapterOptions;
}

export function createMockPaymentAdapters() {
  return {
    shadowwire: new ShadowWireAdapter({ mode: 'mock' }),
    privacy_cash: new PrivacyCashAdapter({ mode: 'mock' }),
  } as const;
}

export function createMockPaymentGateway(defaultProvider: PaymentProvider = 'shadowwire') {
  const adapters = createMockPaymentAdapters();
  return new PaymentGateway(adapters, defaultProvider);
}

export function createPaymentGateway(options: PaymentGatewayOptions = {}) {
  const mode = options.mode ?? 'mock';
  const defaultProvider = options.defaultProvider ?? 'shadowwire';
  const shadowwire =
    mode === 'live'
      ? new ShadowWireAdapter({ ...options.shadowwire, mode: 'live' })
      : new ShadowWireAdapter({ ...options.shadowwire, mode: 'mock' });
  const privacy_cash = new PrivacyCashAdapter({ ...options.privacyCash, mode: 'mock' });

  return new PaymentGateway({ shadowwire, privacy_cash }, defaultProvider);
}

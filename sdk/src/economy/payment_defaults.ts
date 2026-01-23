import { PaymentGateway, PaymentProvider } from './payments';
import { PrivacyCashAdapter, PrivacyCashAdapterOptions } from './payment_adapters/privacy_cash';
import { ShadowWireAdapter, ShadowWireAdapterOptions } from './payment_adapters/shadowwire';
import { StarpayAdapter } from './payment_adapters/starpay';

export type PaymentGatewayMode = 'mock' | 'live';

export interface PaymentGatewayOptions {
  mode?: PaymentGatewayMode;
  defaultProvider?: PaymentProvider;
  shadowwire?: ShadowWireAdapterOptions;
  privacyCash?: PrivacyCashAdapterOptions;
  starpayBalance?: number;
}

export function createMockPaymentAdapters(starpayBalance?: number) {
  return {
    shadowwire: new ShadowWireAdapter({ mode: 'mock' }),
    privacy_cash: new PrivacyCashAdapter({ mode: 'mock' }),
    starpay: new StarpayAdapter(starpayBalance),
  } as const;
}

export function createMockPaymentGateway(defaultProvider: PaymentProvider = 'shadowwire', starpayBalance?: number) {
  const adapters = createMockPaymentAdapters(starpayBalance);
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
  const starpay = new StarpayAdapter(options.starpayBalance);

  return new PaymentGateway({ shadowwire, privacy_cash, starpay }, defaultProvider);
}

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
    shadowwire: new ShadowWireAdapter({ payer: Keypair.generate() }),
    privacy_cash: new PrivacyCashAdapter({ rpcUrl: 'http://localhost:8899', owner: Keypair.generate() }),
    xb77: new XB77Adapter({ connection: new Connection('http://localhost:8899'), payer: Keypair.generate() }),
    starpay: new StarpayAdapter(starpayBalance),
  } as any;
}

export function createMockPaymentGateway(defaultProvider: PaymentProvider = 'xb77', starpayBalance?: number) {
  const adapters = createMockPaymentAdapters(starpayBalance);
  return new PaymentGateway(adapters, defaultProvider);
}

export function createPaymentGateway(options: PaymentGatewayOptions = {}) {
  const mode = options.mode ?? 'mock';
  const defaultProvider = options.defaultProvider ?? 'xb77';
  
  // Note: These defaults are just skeletons, real initialization happens in PrivacyAgent constructor
  // or via explicit options.
  const shadowwire = new ShadowWireAdapter({ payer: Keypair.generate(), ...options.shadowwire });
  const privacy_cash = new PrivacyCashAdapter({ 
    rpcUrl: 'https://api.devnet.solana.com', 
    owner: Keypair.generate(), 
    ...options.privacyCash 
  });
  const xb77 = new XB77Adapter({ 
    connection: new Connection('https://api.devnet.solana.com'), 
    payer: Keypair.generate() 
  });
  const starpay = new StarpayAdapter(options.starpayBalance);

  return new PaymentGateway({ shadowwire, privacy_cash, xb77, starpay }, defaultProvider);
}

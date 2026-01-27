import { Connection, Keypair } from '@solana/web3.js';
import { StarpayAdapter } from './payment_adapters/starpay';
import { ShadowWireAdapter } from './payment_adapters/shadowwire';
import { PrivacyCashAdapter } from './payment_adapters/privacy_cash';
import { XB77Adapter } from './payment_adapters/xb77';
import { PaymentGateway, PaymentProvider } from './payments';

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
    starpay: new StarpayAdapter({ 
      apiKey: 'mock-key',
      resellerMarkupPercent: 5.0 
    }),
  } as any;
}

export function createMockPaymentGateway(defaultProvider: PaymentProvider = 'xb77', starpayBalance?: number) {
  const adapters = createMockPaymentAdapters(starpayBalance);
  return new PaymentGateway(adapters, defaultProvider);
}

export function createPaymentGateway(options: PaymentGatewayOptions = {}) {
  const mode = options.mode ?? 'mock';
  const defaultProvider = options.defaultProvider ?? 'xb77';
  
  // Initialize adapters based on mode
  const shadowwire = new ShadowWireAdapter({ 
    payer: options.shadowwire?.payer || Keypair.generate(),
    apiBaseUrl: options.shadowwire?.apiBaseUrl,
    debug: options.shadowwire?.debug
  });

  const privacy_cash = new PrivacyCashAdapter({ 
    rpcUrl: options.privacyCash?.rpcUrl || 'https://api.devnet.solana.com', 
    owner: options.privacyCash?.owner || Keypair.generate(), 
    enableDebug: options.privacyCash?.enableDebug
  });

  const xb77 = new XB77Adapter({ 
    connection: options.xb77?.connection || new Connection('https://api.devnet.solana.com'), 
    payer: options.xb77?.payer || Keypair.generate(),
    coreProgramId: options.xb77?.coreProgramId,
    gatewayProgramId: options.xb77?.gatewayProgramId,
    receiptsProgramId: options.xb77?.receiptsProgramId
  });

  const starpay = new StarpayAdapter({
    apiKey: process.env.STARPAY_API_KEY || 'REPLACE_ME',
    resellerMarkupPercent: 5.0
  });

  return new PaymentGateway({ shadowwire, privacy_cash, xb77, starpay }, defaultProvider);
}

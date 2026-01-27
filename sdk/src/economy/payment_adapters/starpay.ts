import type { PublicKey } from '@solana/web3.js';
import type {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
} from '../payments';
import type { LiquiditySource } from '../liquidity_manager';
import type { BalanceInfo } from '../balance';
import type { SupportedToken } from '../wallet';

export interface StarpayConfig {
  apiKey: string;
  baseUrl?: string;
  resellerMarkupPercent?: number;
}

export interface StarpayOrderResponse {
  orderId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'expired';
  payment: {
    address: string;
    amountSol: number;
    solPrice: number;
  };
  pricing: {
    cardValue: number;
    total: number;
    resellerMarkup: number;
  };
}

export class StarpayAdapter implements PaymentAdapter, LiquiditySource {
  readonly provider = 'starpay' as const;
  readonly name = 'Starpay Virtual Cards';
  private apiKey: string;
  private baseUrl: string;
  private markup: number;

  constructor(config: StarpayConfig) {
    this.apiKey = config.apiKey;
    this.baseUrl = config.baseUrl || 'https://www.starpay.cards/api/v1';
    this.markup = config.resellerMarkupPercent || 5.0; // Default 5% markup
  }

  // --- Starpay Specific Methods (For the Grant) ---

  async getPriceQuote(amountUsd: number) {
    const res = await fetch(`${this.baseUrl}/cards/price?amount=${amountUsd}`, {
      headers: { 'Authorization': `Bearer ${this.apiKey}` }
    });
    return await res.json();
  }

  async createCardOrder(amount: number, email: string, cardType: 'visa' | 'mastercard' = 'visa'): Promise<StarpayOrderResponse> {
    console.log(`[Starpay] Creating virtual card order: $${amount} for ${email}...`);
    const res = await fetch(`${this.baseUrl}/cards/order`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ amount, cardType, email })
    });
    
    if (!res.ok) throw new Error(`Starpay Order Failed: ${await res.text()}`);
    return await res.json();
  }

  async checkOrderStatus(orderId: string) {
    const res = await fetch(`${this.baseUrl}/cards/order/status?orderId=${orderId}`, {
      headers: { 'Authorization': `Bearer ${this.apiKey}` }
    });
    return await res.json();
  }

  // --- LiquiditySource Implementation ---

  async getBalance(_publicKey: PublicKey, _token: SupportedToken): Promise<BalanceInfo> {
    // In Starpay, the balance is effectively the agent's ability to issue cards
    // Or we could fetch the reseller markup balance if the API supported it
    return {
      available: 5000, // Mocked total credit/limit
      source: 'Starpay Reseller'
    };
  }

  async fund(amount: number, _token: SupportedToken): Promise<{ txId: string; amount: number }> {
     // Scenario: Agent uses its fiat balance to "pre-fund" a private rail
     // This would involve issuing a card and then using a gateway to convert to SOL
     console.log(`[Starpay] Funding private rail via Virtual Card issuance ($${amount})...`);
     return {
       txId: `sp-fund-${Date.now()}`,
       amount
     };
  }

  // --- PaymentAdapter Implementation ---

  async execute(request: PaymentRequest, _context?: PaymentContext): Promise<PaymentExecutionResult> {
    console.log(`[Starpay] Executing Web2 payment via Virtual Card for ${request.vendor}...`);
    
    // 1. Create a card for the exact amount
    // In a real flow, the Agent would pay SOL to Starpay here.
    const order = await this.createCardOrder(request.amount, 'agent-treasury@xb77.io');

    return {
      provider: this.provider,
      status: 'success',
      txSignature: order.orderId,
      paidAmount: order.pricing.total,
      raw: {
        order,
        markupEarned: order.pricing.resellerMarkup,
        paymentAddress: order.payment.address
      }
    };
  }
}

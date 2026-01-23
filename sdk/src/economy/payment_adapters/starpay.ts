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

export class StarpayAdapter implements PaymentAdapter, LiquiditySource {
  readonly provider = 'starpay' as const;
  readonly name = 'Starpay Corporate';

  private mockBalance: number;

  constructor(initialBalance: number = 10000) {
    this.mockBalance = initialBalance;
  }

  // --- LiquiditySource Implementation ---

  async getBalance(_publicKey: PublicKey, _token: SupportedToken): Promise<BalanceInfo> {
    return {
      available: this.mockBalance,
      source: 'Starpay Card Limit'
    };
  }

  async fund(amount: number, _token: SupportedToken): Promise<{ txId: string; amount: number }> {
    if (this.mockBalance < amount) {
      throw new Error('Starpay: Insufficient corporate limit for funding');
    }
    this.mockBalance -= amount;
    return {
      txId: `starpay-fund-${Math.random().toString(36).substring(7)}`,
      amount
    };
  }

  // --- PaymentAdapter Implementation ---

  async execute(request: PaymentRequest, _context?: PaymentContext): Promise<PaymentExecutionResult> {
    if (this.mockBalance < request.amount) {
      return {
        provider: this.provider,
        status: 'failed',
        raw: { error: 'Insufficient limit' }
      };
    }

    this.mockBalance -= request.amount;

    // Simulate virtual card issuance and payment
    const cardId = `vcard-${Math.random().toString(36).substring(7)}`;
    const txId = `starpay-tx-${Math.random().toString(36).substring(7)}`;

    return {
      provider: this.provider,
      status: 'success',
      txSignature: txId,
      paidAmount: request.amount,
      raw: {
        cardId,
        merchant: request.vendor,
        method: 'Virtual Card'
      }
    };
  }
}

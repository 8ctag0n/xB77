import { PublicKey } from '@solana/web3.js';
import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
} from '../payments';
import { MockPrivacyCashClient, PrivacyCashMockClient } from '../payment_mocks/privacy_cash';
import { PrivacyRail } from '../liquidity_manager';
import { BalanceInfo } from '../balance';
import { SupportedToken } from '../wallet';

export type PrivacyCashAdapterMode = 'mock';

export interface PrivacyCashAdapterOptions {
  mode?: PrivacyCashAdapterMode;
  client?: PrivacyCashMockClient;
}

export class PrivacyCashAdapter implements PaymentAdapter, PrivacyRail {
  readonly provider = 'privacy_cash' as const;
  readonly name = 'Privacy Cash';
  private client: PrivacyCashMockClient;

  constructor(options: PrivacyCashAdapterOptions = {}) {
    this.client = options.client ?? new MockPrivacyCashClient();
  }

  async getBalance(publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    const balance = await this.client.getBalance(publicKey.toBase58(), token);
    return {
      available: balance.available,
      source: 'Privacy Cash Mock'
    };
  }

  async getLimit(_publicKey: PublicKey, _token: SupportedToken): Promise<number> {
    return 10_000; // Mock limit
  }

  async deposit(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    const isSol = token === 'SOL';
    const depositRequest = {
      owner: publicKey.toBase58(),
      token,
      amount,
    };

    if (isSol) {
      await this.client.deposit(depositRequest);
    } else {
      await this.client.depositSPL(depositRequest);
    }
  }

  async withdraw(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    const isSol = token === 'SOL';
    const withdrawRequest = {
      recipientAddress: publicKey.toBase58(),
      token,
      amount,
    };

    if (isSol) {
      await this.client.withdraw(withdrawRequest);
    } else {
      await this.client.withdrawSPL(withdrawRequest);
    }
  }

  async execute(request: PaymentRequest, _context?: PaymentContext): Promise<PaymentExecutionResult> {
    const isSol = request.currency === 'SOL';
    const token = request.currency;

    const depositRequest = {
      owner: request.agentId,
      token,
      amount: request.amount,
    };

    if (isSol) {
      await this.client.deposit(depositRequest);
    } else {
      await this.client.depositSPL(depositRequest);
    }

    const withdrawRequest = {
      recipientAddress: request.vendor,
      token,
      amount: request.amount,
    };

    const withdrawResult = isSol
      ? await this.client.withdraw(withdrawRequest)
      : await this.client.withdrawSPL(withdrawRequest);

    return {
      provider: this.provider,
      status: withdrawResult?.tx ? 'success' : 'failed',
      txSignature: withdrawResult?.tx,
      paidAmount: request.amount,
      fee: withdrawResult?.fee_lamports,
      raw: {
        withdraw: withdrawResult,
      },
    };
  }
}

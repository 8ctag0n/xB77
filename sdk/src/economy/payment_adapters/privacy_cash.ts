import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
} from '../payments';
import { MockPrivacyCashClient, PrivacyCashMockClient } from '../payment_mocks/privacy_cash';

export type PrivacyCashAdapterMode = 'mock';

export interface PrivacyCashAdapterOptions {
  mode?: PrivacyCashAdapterMode;
  client?: PrivacyCashMockClient;
}

export class PrivacyCashAdapter implements PaymentAdapter {
  readonly provider = 'privacy_cash' as const;
  private client: PrivacyCashMockClient;

  constructor(options: PrivacyCashAdapterOptions = {}) {
    this.client = options.client ?? new MockPrivacyCashClient();
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

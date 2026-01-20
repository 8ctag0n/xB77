import { Keypair } from '@solana/web3.js';
import { AgentWallet, PaymentResult, SupportedToken } from './economy/wallet';
import { BalanceProvider } from './economy/balance';
import { IdentityManager } from './identity/manager';
import { PaymentReceipt, PaymentType, ReceiptStore } from './economy/receipts';
import {
  buildPaymentReceipt,
  PaymentGateway,
  PaymentProvider,
  PaymentRequest,
} from './economy/payments';
import { createMockPaymentGateway, createPaymentGateway, PaymentGatewayOptions } from './economy/payment_defaults';

export interface AgentConfig {
  keypair: Keypair;
  debug?: boolean;
  balanceProvider?: BalanceProvider;
  receiptStore?: ReceiptStore;
  paymentGateway?: PaymentGateway;
  paymentProvider?: PaymentProvider;
  paymentGatewayOptions?: PaymentGatewayOptions;
}

export interface AgentStateSnapshot<TBalance = unknown> {
  publicKey: string;
  token: SupportedToken;
  balance: TBalance;
  latestReceipt: PaymentReceipt | null;
  updatedAt: number;
}

export class PrivacyAgent {
  public wallet: AgentWallet;
  public identity: IdentityManager;
  private balanceProvider?: BalanceProvider;
  private receiptStore?: ReceiptStore;
  private paymentGateway: PaymentGateway;
  private paymentProvider: PaymentProvider;

  constructor(config: AgentConfig) {
    this.wallet = new AgentWallet(config.keypair, config.debug);
    this.identity = new IdentityManager();
    this.balanceProvider = config.balanceProvider;
    this.receiptStore = config.receiptStore;
    this.paymentGateway =
      config.paymentGateway ??
      (config.paymentGatewayOptions
        ? createPaymentGateway(config.paymentGatewayOptions)
        : createMockPaymentGateway(config.paymentProvider));
    this.paymentProvider = config.paymentProvider ?? 'shadowwire';
    console.log(`[PrivacyAgent] Initialized agent with public key: ${config.keypair.publicKey.toBase58()}`);
  }

  /**
   * High-level command to execute a private payment
   * Checks identity first (conceptually) then pays.
   */
  async pay(
    recipient: string,
    amount: number,
    token: SupportedToken = 'USD1',
    type: PaymentType = 'external',
    provider?: PaymentProvider
  ): Promise<PaymentResult> {
    const request: PaymentRequest = {
      amount,
      currency: token,
      agentId: this.wallet.publicKey.toBase58(),
      vendor: recipient,
      type,
      provider: provider ?? this.paymentProvider,
    };

    const execution = await this.paymentGateway.execute(request);

    if (this.receiptStore) {
      const receipt: PaymentReceipt = buildPaymentReceipt(request, execution);
      await this.receiptStore.recordPayment(receipt);
    }

    if (execution.status !== 'success') {
      throw new Error('Payment failed');
    }

    return {
      txSignature: execution.txSignature,
      proofPda: execution.proofPda,
      nonce: execution.nonce,
      raw: execution.raw,
    };
  }

  /**
   * Optional balance adapter (useful for C-SPL pool or receipts-based balance).
   */
  async getBalance(token: SupportedToken = 'USD1') {
    if (this.balanceProvider) {
      return await this.balanceProvider.getBalance(this.wallet.publicKey, token);
    }
    return await this.wallet.getBalance(token);
  }

  async listReceipts(limit: number = 25): Promise<PaymentReceipt[]> {
    if (!this.receiptStore) {
      return [];
    }
    return await this.receiptStore.listReceipts(limit);
  }

  async getLatestReceipt(): Promise<PaymentReceipt | null> {
    if (!this.receiptStore) {
      return null;
    }
    return await this.receiptStore.getLatestReceipt();
  }

  async getState(token: SupportedToken = 'USD1'): Promise<AgentStateSnapshot> {
    const balance = await this.getBalance(token);
    const latestReceipt = await this.getLatestReceipt();

    return {
      publicKey: this.wallet.publicKey.toBase58(),
      token,
      balance,
      latestReceipt,
      updatedAt: Date.now(),
    };
  }

  /**
   * Deposit funds into the privacy pool (Shielding)
   */
  async shield(amount: number, token: SupportedToken = 'SOL') {
     // TODO: Implement deposit/shield logic via ShadowWire
     console.log("Shielding functionality coming soon via ShadowWire deposit()");
  }
}

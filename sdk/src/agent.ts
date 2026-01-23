import { Keypair } from '@solana/web3.js';
import { AgentWallet } from './economy/wallet';
import type { PaymentResult, SupportedToken } from './economy/wallet';
import type { BalanceInfo, BalanceProvider } from './economy/balance';
import { IdentityManager } from './identity/manager';
import type { PaymentReceipt, PaymentType, ReceiptStore } from './economy/receipts';
import {
  buildPaymentReceipt,
  PaymentGateway,
  PaymentProvider,
  PaymentRequest,
} from './economy/payments';
import { createMockPaymentGateway, createPaymentGateway, PaymentGatewayOptions } from './economy/payment_defaults';
import { PaymentRouter } from './economy/payment_router';
import { RangeAdapter } from './economy/payment_adapters/range';
import { LiquidityManager, LiquiditySource, PrivacyRail } from './economy/liquidity_manager';
import { StarpayAdapter } from './economy/payment_adapters/starpay';

export interface AgentConfig {
  keypair: Keypair;
  debug?: boolean;
  balanceProvider?: BalanceProvider;
  receiptStore?: ReceiptStore;
  paymentGateway?: PaymentGateway;
  paymentProvider?: PaymentProvider;
  paymentGatewayOptions?: PaymentGatewayOptions;
  // CFO options
  minLiquidityThreshold?: number;
  targetLiquidity?: number;
}

export interface AgentStateSnapshot<TBalance = unknown> {
  publicKey: string;
  token: SupportedToken;
  balance: TBalance;
  treasury?: {
    fiat: BalanceInfo;
    crypto: BalanceInfo;
    totalUsd: number;
  };
  latestReceipt: PaymentReceipt | null;
  updatedAt: number;
}

export class PrivacyAgent {
  public wallet: AgentWallet;
  public identity: IdentityManager;
  public liquidityManager: LiquidityManager;
  public router: PaymentRouter;
  
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
        : createMockPaymentGateway(config.paymentProvider, config.paymentGatewayOptions?.starpayBalance));
    
    this.paymentProvider = config.paymentProvider ?? 'shadowwire';

    // Initialize CFO Components
    const range = new RangeAdapter();
    this.router = new PaymentRouter({
      gateway: this.paymentGateway,
      range,
      preferredInternalProvider: 'shadowwire',
      preferredExternalProvider: 'shadowwire'
    });

    // Find Starpay adapter in gateway for liquidity management
    const starpay = (this.paymentGateway as any).adapters?.['starpay'] as StarpayAdapter;
    const sources: LiquiditySource[] = starpay ? [starpay] : [];
    
    // ShadowWire as Privacy Rail (mocked or live)
    const shadowwire = (this.paymentGateway as any).adapters?.['shadowwire'] as any;
    const rails: PrivacyRail[] = shadowwire ? [shadowwire] : [];

    this.liquidityManager = new LiquidityManager({
      agentId: this.wallet.publicKey,
      sources,
      rails,
      minLiquidityThreshold: config.minLiquidityThreshold ?? 100,
      targetLiquidity: config.targetLiquidity ?? 500
    });

    console.log(`[PrivacyAgent] Initialized agent with public key: ${config.keypair.publicKey.toBase58()}`);
  }

  /**
   * High-level command to execute a private payment via the Router (Autonomous Decision)
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
      provider: provider, // Router will decide if not provided
    };

    // Use Router instead of raw Gateway for autonomous decision and compliance
    const execution = await this.router.route(request);

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
   * CFO Action: Rebalance treasury if needed.
   */
  async rebalance(token: SupportedToken = 'USD1') {
    return await this.liquidityManager.checkAndRebalance(token);
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
    const treasury = await this.liquidityManager.getFullSnapshot(token);

    return {
      publicKey: this.wallet.publicKey.toBase58(),
      token,
      balance,
      treasury,
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
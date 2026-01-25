import { Keypair } from '@solana/web3.js';
import nacl from 'tweetnacl';
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
  WalletSigner
} from './economy/payments';
import { createMockPaymentGateway, createPaymentGateway, PaymentGatewayOptions } from './economy/payment_defaults';
import { PaymentRouter } from './economy/payment_router';
import { RangeAdapter } from './economy/payment_adapters/range';
import { LiquidityManager, LiquiditySource, PrivacyRail } from './economy/liquidity_manager';
import { StarpayAdapter } from './economy/payment_adapters/starpay';
import { PaymentStrategyEngine } from './economy/strategy';

import { XB77Adapter, XB77AdapterOptions } from './economy/payment_adapters/xb77';

export interface AgentConfig {
  keypair: Keypair;
  debug?: boolean;
  balanceProvider?: BalanceProvider;
  receiptStore?: ReceiptStore;
  paymentGateway?: PaymentGateway;
  paymentProvider?: PaymentProvider;
  paymentGatewayOptions?: PaymentGatewayOptions;
  // On-chain options
  connection?: Connection;
  coreProgramId?: PublicKey;
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
  public strategyEngine: PaymentStrategyEngine;
  
  private balanceProvider?: BalanceProvider;
  private receiptStore?: ReceiptStore;
  private paymentGateway: PaymentGateway;
  private paymentProvider: PaymentProvider;

  constructor(config: AgentConfig) {
    this.wallet = new AgentWallet(config.keypair, config.debug);
    this.identity = new IdentityManager();
    this.strategyEngine = new PaymentStrategyEngine();
    this.balanceProvider = config.balanceProvider;
    this.receiptStore = config.receiptStore;
    
    this.paymentGateway =
      config.paymentGateway ??
      (config.paymentGatewayOptions
        ? createPaymentGateway(config.paymentGatewayOptions)
        : createMockPaymentGateway(config.paymentProvider, config.paymentGatewayOptions?.starpayBalance));
    
    this.paymentProvider = config.paymentProvider ?? 'shadowwire';

    // Initialize On-Chain Adapter if connection is provided
    let xb77Adapter: XB77Adapter | undefined;
    if (config.connection) {
      xb77Adapter = new XB77Adapter({
        connection: config.connection,
        coreProgramId: config.coreProgramId,
        payer: config.keypair
      });
      // Inject into gateway if not already custom
      if (!config.paymentGateway && (this.paymentGateway as any).adapters) {
        (this.paymentGateway as any).adapters['shadowwire'] = xb77Adapter;
      }
    }

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
    provider?: PaymentProvider,
    context: any = {}
  ): Promise<PaymentResult> {
    
    // 1. Strategy Evaluation (if provider not forced)
    let selectedProvider = provider;
    let isGhostMode = false;
    let isObfuscated = false;

    if (!selectedProvider) {
      // Find intelligence provider in adapters
      const intel = (this.paymentGateway as any).adapters?.['shadowwire'] instanceof XB77Adapter
        ? new HeliusIntelligenceAdapter({ apiKey: process.env.HELIUS_API_KEY || 'mock' })
        : undefined;

      const plan = await this.strategyEngine.evaluate(recipient, amount, {
        ...context,
        intelligenceProvider: intel
      });
      
      selectedProvider = plan.provider;
      if (plan.strategy === 'ephemeral_relay') {
        isGhostMode = true;
      } else if (plan.strategy === 'privacy_cash_obfuscation') {
        isObfuscated = true;
      }
    }

    // 2. Specialized Execution Flows
    if (isObfuscated) {
      return this.executeObfuscatedPayment(recipient, amount, token);
    }
    
    if (isGhostMode) {
      return this.executeGhostPayment(recipient, amount, token);
    }

    // 3. Standard Execution
    const request: PaymentRequest = {
      amount,
      currency: token,
      agentId: this.wallet.publicKey.toBase58(),
      vendor: recipient,
      type,
      provider: selectedProvider,
    };

    // Use Router instead of raw Gateway for autonomous decision and compliance
    const execution = await this.router.route(request);

    if (this.receiptStore) {
      const receipt: PaymentReceipt = buildPaymentReceipt(request, execution);
      await this.receiptStore.recordPayment(receipt);
    }

    return {
      txSignature: execution.txSignature,
      proofPda: execution.proofPda,
      nonce: execution.nonce,
      provider: execution.provider,
      raw: execution.raw,
    };
  }

  private async executeObfuscatedPayment(recipient: string, amount: number, token: SupportedToken): Promise<PaymentResult> {
    console.log(`[Obfuscation] Initiating double-hop via Privacy Cash...`);
    
    // Step 1: Obfuscation Hop (Privacy Cash)
    // We simulate a deposit/withdraw from Privacy Cash pool to break the first link
    console.log(`[Obfuscation] Hop 1: Privacy Cash Pool Shielding...`);
    const hop1 = await this.pay(recipient, amount, token, 'external', 'privacy_cash');
    
    // Step 2: Final Payment (Already handled by Hop 1 in this simplified mock version, 
    // but in live it would be a withdrawal from Privacy Cash to a Ghost Wallet then to Vendor)
    
    console.log(`[Obfuscation] Link broken. Transaction finalized.`);
    return hop1;
  }

  private async executeGhostPayment(recipient: string, amount: number, token: SupportedToken): Promise<PaymentResult> {
    console.log(`[Ghost] Spawning ephemeral burner wallet...`);
    const burner = Keypair.generate();
    const burnerPub = burner.publicKey.toBase58();
    
    // Step 1: Fund Burner (Internal Shielded Transfer)
    // We add a small fee buffer (e.g. 5%)
    const fundAmount = Math.ceil(amount * 1.05); 
    console.log(`[Ghost] Funding burner ${burnerPub} with ${fundAmount} ${token}...`);
    
    // Recursive call to pay() but forcing 'internal' type and 'shadowwire' provider
    // This uses the main treasury to fund the burner
    const fundingResult = await this.pay(burnerPub, fundAmount, token, 'internal', 'shadowwire');
    console.log(`[Ghost] Burner funded. TX: ${fundingResult.txSignature}`);

    // Step 2: Pay Vendor from Burner
    console.log(`[Ghost] Executing final hop to ${recipient}...`);
    
    const burnerSigner: WalletSigner = {
      signMessage: async (msg) => nacl.sign.detached(msg, burner.secretKey)
    };

    // Construct request manually to bypass router checks (we are the burner now)
    const request: PaymentRequest = {
      amount,
      currency: token,
      agentId: burnerPub, // Sender is the burner!
      vendor: recipient,
      type: 'external',
      provider: 'shadowwire',
    };

    // Execute directly via Gateway using Burner Context
    // We bypass 'router' because router checks compliance on SENDER. 
    // The burner is fresh, so it has no history, but we might want to check recipient compliance again.
    // For simplicity, we assume main treasury already checked compliance implicitly (or we check explicitly).
    // Let's check compliance just in case.
    const compliance = await new RangeAdapter().preScreenPayment(recipient, amount);
    if (!compliance.isSafe) throw new Error('Ghost Mode halted: Compliance risk on destination.');

    const execution = await (this.paymentGateway as any).execute(request, { walletSigner: burnerSigner });

    // Step 3: Cleanup
    // We don't store the burner key. It is lost forever here.
    console.log(`[Ghost] Burner keys discarded.`);

    if (this.receiptStore) {
      // We record the receipt as if it came from us (conceptually), or we mark it as ghost
      const receipt: PaymentReceipt = buildPaymentReceipt(request, execution);
      receipt.sender = this.wallet.publicKey.toBase58(); // Remap ownership to main agent for accounting
      receipt.metadata = { ...receipt.metadata, mode: 'ghost_relay', burner: burnerPub };
      await this.receiptStore.recordPayment(receipt);
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
    let baseBalance: BalanceInfo;
    if (this.balanceProvider) {
      baseBalance = await this.balanceProvider.getBalance(this.wallet.publicKey, token);
    } else {
      baseBalance = await this.wallet.getBalance(token);
    }

    // Add On-Chain Credit Line if available
    const shadowwire = (this.paymentGateway as any).adapters?.['shadowwire'];
    if (shadowwire instanceof XB77Adapter) {
      const credit = await shadowwire.getCreditBalance(this.wallet.keypair.publicKey);
      return {
        ...baseBalance,
        credit: Number(credit),
        totalAvailable: baseBalance.available + Number(credit)
      };
    }

    return baseBalance;
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
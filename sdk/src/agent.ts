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
import { ShadowWireAdapter } from './economy/payment_adapters/shadowwire';
import { PrivacyCashAdapter } from './economy/payment_adapters/privacy_cash';
import { KaminoMockProvider } from './economy/yield';
import { HeliusIntelligenceAdapter } from './economy/intelligence/helius';
import { ReceiptAuditor, AuditProof } from './economy/auditor';
import { FeeTracker, EfficiencyMetrics } from './economy/fee_tracker';

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
  gatewayProgramId?: PublicKey;
  receiptsProgramId?: PublicKey;
  lightRpcUrl?: string;
  lightCompressionUrl?: string;
  lightProverUrl?: string;
  // CFO options
  minLiquidityThreshold?: number;
  targetLiquidity?: number;
  maxLiquidityThreshold?: number;
}

export interface AgentStateSnapshot<TBalance = unknown> {
  publicKey: string;
  token: SupportedToken;
  balance: TBalance;
  treasury?: {
    fiat: BalanceInfo;
    crypto: BalanceInfo;
    yield: BalanceInfo;
    totalUsd: number;
  };
  efficiency?: EfficiencyMetrics;
  latestReceipt: PaymentReceipt | null;
  identity?: {
    merkleRootHex: string;
    merkleIndex: number;
    nullifierHex: string;
  };
  updatedAt: number;
}

export class PrivacyAgent {
  public wallet: AgentWallet;
  public identity: IdentityManager;
  public liquidityManager: LiquidityManager;
  public router: PaymentRouter;
  public strategyEngine: PaymentStrategyEngine;
  public auditor: ReceiptAuditor;
  public feeTracker: FeeTracker;
  
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
    this.auditor = new ReceiptAuditor(config.keypair.secretKey);
    this.feeTracker = new FeeTracker();

    // Initialize On-Chain Adapters if connection is provided
    if (config.connection) {
      const xb77 = new XB77Adapter({
        connection: config.connection,
        coreProgramId: config.coreProgramId,
        gatewayProgramId: config.gatewayProgramId,
        receiptsProgramId: config.receiptsProgramId,
        lightRpcUrl: config.lightRpcUrl,
        lightCompressionUrl: config.lightCompressionUrl,
        lightProverUrl: config.lightProverUrl,
        payer: config.keypair
      });

      const shadowwire = new ShadowWireAdapter({
        payer: config.keypair,
        debug: config.debug
      });

      const privacy_cash = new PrivacyCashAdapter({
        rpcUrl: config.connection.rpcEndpoint,
        owner: config.keypair,
        enableDebug: config.debug
      });

      // Inject into gateway
      if (!config.paymentGateway && (this.paymentGateway as any).adapters) {
        const adapters = (this.paymentGateway as any).adapters;
        adapters['xb77'] = xb77;
        adapters['shadowwire'] = shadowwire;
        adapters['privacy_cash'] = privacy_cash;
      }
    }

    // Initialize CFO Components
    const range = new RangeAdapter();
    this.router = new PaymentRouter({
      gateway: this.paymentGateway,
      range,
      preferredInternalProvider: 'xb77',
      preferredExternalProvider: 'shadowwire'
    });

    // Find Starpay adapter in gateway for liquidity management
    const starpay = (this.paymentGateway as any).adapters?.['starpay'] as StarpayAdapter;
    const sources: LiquiditySource[] = starpay ? [starpay] : [];
    
    // Privacy Rails (available for the LiquidityManager)
    const adapters = (this.paymentGateway as any).adapters || {};
    const rails: PrivacyRail[] = [
        adapters['xb77'],
        adapters['shadowwire'],
        adapters['privacy_cash']
    ].filter(Boolean);

    this.liquidityManager = new LiquidityManager({
      agentId: this.wallet.publicKey,
      sources,
      rails,
      yieldProvider: new KaminoMockProvider(),
      minLiquidityThreshold: config.minLiquidityThreshold ?? 100,
      targetLiquidity: config.targetLiquidity ?? 500,
      maxLiquidityThreshold: config.maxLiquidityThreshold ?? 1000
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
      const intel = (this.paymentGateway as any).adapters?.['xb77'] instanceof XB77Adapter
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

    // Record operational fee
    if (execution.fee) {
      this.feeTracker.recordFee(execution.fee, 'relayer', token, execution.txSignature);
    } else {
      // Small mock fee for the demo if not provided by adapter
      this.feeTracker.recordFee(0.001, 'gas', token, execution.txSignature);
    }

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
    // We add a small fee buffer (e.g. 10 units)
    const fundAmount = amount + 10; 
    console.log(`[Ghost] Funding burner ${burnerPub} with ${fundAmount} ${token}...`);
    
    // This uses the main treasury to fund the burner via a private internal transfer
    const fundingResult = await this.pay(burnerPub, fundAmount, token, 'internal', 'xb77');
    console.log(`[Ghost] Burner funded. TX: ${fundingResult.txSignature}`);

    // Wait for the privacy pool to settle (mock/simulated delay for ZK proof availability)
    await new Promise(r => setTimeout(r, 1000));

    // Step 2: Pay Vendor from Burner
    console.log(`[Ghost] Executing final hop from burner ${burnerPub} to ${recipient}...`);
    
    const burnerSigner: WalletSigner = {
      signMessage: async (msg) => nacl.sign.detached(msg, burner.secretKey)
    };

    const request: PaymentRequest = {
      amount,
      currency: token,
      agentId: burnerPub, 
      vendor: recipient,
      type: 'external',
      provider: 'xb77',
    };

    // Pre-screen recipient for compliance before using the burner
    const compliance = await new RangeAdapter().preScreenPayment(recipient, amount);
    if (!compliance.isSafe) {
        logThought(`ABORT: Burner ${burnerPub} refused to pay high-risk destination ${recipient}.`);
        throw new Error('Ghost Mode halted: Compliance risk on destination.');
    }

    // Execute directly via Gateway using Burner as the signer
    // This ensures that on-chain, the sender is the Burner, not the Agent Treasury.
    const execution = await (this.paymentGateway as any).execute(request, { walletSigner: burnerSigner });

    console.log(`[Ghost] Burner keys discarded. Privacy link broken.`);

    if (this.receiptStore) {
      const receipt: PaymentReceipt = buildPaymentReceipt(request, execution);
      receipt.sender = this.wallet.publicKey.toBase58(); // Accountant sees it as ours
      receipt.metadata = { 
        ...receipt.metadata, 
        mode: 'ghost_relay', 
        burner: burnerPub,
        reasoning: 'Chain-link broken via ephemeral relay'
      };
      await this.receiptStore.recordPayment(receipt);
    }

    return {
      txSignature: execution.txSignature,
      proofPda: execution.proofPda,
      nonce: execution.nonce,
      provider: 'xb77 (ghost)',
      raw: { ...execution.raw, burner: burnerPub }
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
    const xb77 = (this.paymentGateway as any).adapters?.['xb77'];
    if (xb77 instanceof XB77Adapter) {
      const credit = await xb77.getCreditBalance(this.wallet.keypair.publicKey);
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
    const efficiency = this.feeTracker.calculateEfficiency(treasury.yield.available);

    let identityInfo;
    try {
      const proof = await this.identity.proveAccess();
      identityInfo = {
        merkleRootHex: proof.merkleRootHex,
        merkleIndex: proof.merkleIndex,
        nullifierHex: proof.nullifierHex
      };
    } catch (e) {
      // Identity artifacts might not be generated yet
    }

    return {
      publicKey: this.wallet.publicKey.toBase58(),
      token,
      balance,
      treasury,
      efficiency,
      latestReceipt,
      identity: identityInfo,
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

import { PublicKey, Keypair } from '@solana/web3.js';
import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
} from '../payments';
import { PrivacyCash } from 'privacycash';
import { PrivacyRail } from '../liquidity_manager';
import { BalanceInfo } from '../balance';
import { SupportedToken } from '../wallet';

export interface PrivacyCashAdapterOptions {
  rpcUrl: string;
  owner: Keypair | string | number[] | Uint8Array;
  enableDebug?: boolean;
}

export class PrivacyCashAdapter implements PaymentAdapter, PrivacyRail {
  readonly provider = 'privacy_cash' as const;
  readonly name = 'Privacy Cash';
  private client: PrivacyCash;

  constructor(options: PrivacyCashAdapterOptions) {
    // If owner is a Keypair object, extract the secretKey as Uint8Array
    // because the privacycash library expects a raw key or byte array.
    const owner = (options.owner && typeof options.owner === 'object' && 'secretKey' in options.owner)
      ? (options.owner as Keypair).secretKey
      : options.owner;

    this.client = new PrivacyCash({
      RPC_url: options.rpcUrl,
      owner: owner as any,
      enableDebug: options.enableDebug ?? false
    });
  }

  async getBalance(_publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    // Note: PrivacyCash client already knows the owner from constructor
    let balance: number = 0;
    try {
      if (token === 'SOL') {
        balance = await this.client.getPrivateBalance();
      } else if (token === 'USDC' || token === 'USD1') {
        // For the demo, we treat USD1 as USDC in the privacy pool if needed, 
        // or return 0 if the pool doesn't support the specific mint.
        balance = await this.client.getPrivateBalanceUSDC().catch(() => 0);
      }
    } catch (e) {
      console.warn(`[PrivacyCash] Balance check failed for ${token}:`, e.message);
      balance = 0;
    }

    return {
      available: balance,
      source: 'Privacy Cash'
    };
  }

  async getLimit(_publicKey: PublicKey, _token: SupportedToken): Promise<number> {
    return 50_000; // Realistic limit for privacy pools
  }

  async deposit(_publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    if (token !== 'SOL') {
        throw new Error('PrivacyCash Adapter currently only supports SOL deposits in this version');
    }
    // Convert to lamports (assuming amount is in SOL)
    const lamports = Math.floor(amount * 1e9);
    await this.client.deposit({ lamports });
  }

  async withdraw(_publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    if (token !== 'SOL') {
        throw new Error('PrivacyCash Adapter currently only supports SOL withdrawals in this version');
    }
    const lamports = Math.floor(amount * 1e9);
    await this.client.withdraw({ lamports });
  }

  async execute(request: PaymentRequest, _context?: PaymentContext): Promise<PaymentExecutionResult> {
    const token = request.currency;
    if (token !== 'SOL') {
        throw new Error('PrivacyCash Adapter currently only supports SOL payments');
    }

    const lamports = Math.floor(request.amount * 1e9);

    // Flow: Deposit -> Withdraw to recipient (Privacy Cash way of doing a private transfer)
    console.log(`[PrivacyCash] Executing private payment of ${request.amount} SOL to ${request.vendor}`);
    
    // 1. Shield funds
    await this.client.deposit({ lamports });
    
    // 2. Withdraw to vendor
    const withdrawResult = await this.client.withdraw({ 
        lamports, 
        recipientAddress: request.vendor 
    });

    return {
      provider: this.provider,
      status: withdrawResult ? 'success' : 'failed',
      txSignature: (withdrawResult as any)?.signature || (withdrawResult as any)?.tx,
      paidAmount: request.amount,
      raw: {
        withdraw: withdrawResult,
      },
    };
  }
}
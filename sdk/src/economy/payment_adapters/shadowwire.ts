import { PublicKey, Keypair } from '@solana/web3.js';
import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
} from '../payments';
import { ShadowWireClient, TokenUtils } from '@radr/shadowwire';
import { PrivacyRail } from '../liquidity_manager';
import { BalanceInfo } from '../balance';
import { SupportedToken } from '../wallet';
import nacl from 'tweetnacl';

export interface ShadowWireAdapterOptions {
  apiBaseUrl?: string;
  debug?: boolean;
  payer: Keypair;
}

export class ShadowWireAdapter implements PaymentAdapter, PrivacyRail {
  readonly provider = 'shadowwire' as const;
  readonly name = 'ShadowWire';
  private client: ShadowWireClient;
  private payer: Keypair;

  constructor(options: ShadowWireAdapterOptions) {
    this.client = new ShadowWireClient({
      apiBaseUrl: options.apiBaseUrl,
      debug: options.debug ?? false
    });
    this.payer = options.payer;
  }

  async getBalance(publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    const balance = await this.client.getBalance(publicKey.toBase58(), token as any);
    return {
      available: balance,
      source: 'ShadowWire'
    };
  }

  async getLimit(_publicKey: PublicKey, _token: SupportedToken): Promise<number> {
    return 100_000;
  }

  async deposit(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    const amountSmallest = TokenUtils.toSmallestUnit(amount, token as any);
    await this.client.deposit({
      wallet: publicKey.toBase58(),
      amount: Number(amountSmallest)
    });
  }

  async withdraw(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    const amountSmallest = TokenUtils.toSmallestUnit(amount, token as any);
    await this.client.withdraw({
      wallet: publicKey.toBase58(),
      amount: Number(amountSmallest)
    });
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    console.log(`[ShadowWire] Executing ${request.type} payment of ${request.amount} ${request.currency} to ${request.vendor}`);

    const signMessage = async (msg: Uint8Array) => nacl.sign.detached(msg, this.payer.secretKey);

    const result = await this.client.transfer({
      sender: this.payer.publicKey.toBase58(),
      recipient: request.vendor,
      amount: request.amount,
      token: request.currency as any,
      type: request.type === 'internal' ? 'internal' : 'external',
      wallet: { signMessage }
    });

    return {
      provider: this.provider,
      status: 'success', // ShadowWire throws on failure usually
      txSignature: (result as any).signature || (result as any).txHash,
      paidAmount: request.amount,
      raw: result,
    };
  }
}
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
    console.log(`[ShadowWire] Depositing ${amount} ${token} for ${publicKey.toBase58()}...`);
    const amountSmallest = TokenUtils.toSmallestUnit(amount, token as any);
    
    // In ShadowWire, deposit usually requires a signature from the source wallet
    const signMessage = async (msg: Uint8Array) => nacl.sign.detached(msg, this.payer.secretKey);

    await this.client.deposit({
      wallet: publicKey.toBase58(),
      amount: Number(amountSmallest),
      token: token as any,
      signer: { signMessage, publicKey: this.payer.publicKey.toBase58() }
    });
  }

  async withdraw(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void> {
    console.log(`[ShadowWire] Withdrawing ${amount} ${token} from ${publicKey.toBase58()}...`);
    const amountSmallest = TokenUtils.toSmallestUnit(amount, token as any);

    const signMessage = async (msg: Uint8Array) => nacl.sign.detached(msg, this.payer.secretKey);

    await this.client.withdraw({
      wallet: publicKey.toBase58(),
      amount: Number(amountSmallest),
      token: token as any,
      signer: { signMessage, publicKey: this.payer.publicKey.toBase58() }
    });
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    console.log(`[ShadowWire] Executing ${request.type} payment of ${request.amount} ${request.currency} to ${request.vendor}`);

    const signMessage = async (msg: Uint8Array) => nacl.sign.detached(msg, this.payer.secretKey);

    // Ensure amount is passed as a plain number and is correctly named in the payload
    const result = await this.client.transfer({
      sender: this.payer.publicKey.toBase58(),
      recipient: request.vendor,
      amount: Number(request.amount), // Explicit number conversion
      token: request.currency as any,
      type: (request.type === 'internal' ? 'internal' : 'external') as any,
      wallet: { 
        signMessage,
        publicKey: this.payer.publicKey.toBase58() // Some versions require the pubkey in the wallet object
      }
    });

    return {
      provider: this.provider,
      status: 'success', 
      txSignature: (result as any).signature || (result as any).txHash || (result as any).id,
      paidAmount: request.amount,
      raw: result,
    };
  }
}
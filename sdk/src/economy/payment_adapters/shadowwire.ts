import { keccak_256 } from '@noble/hashes/sha3';
import { PublicKey } from '@solana/web3.js';
import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
  WalletSigner,
} from '../payments';
import { MockShadowWireClient, ShadowWireMockClient } from '../payment_mocks/shadowwire';
import { SupportedToken } from '../wallet';
import { BalanceInfo } from '../balance';

export type ShadowWireAdapterMode = 'mock' | 'live';

export interface ShadowWireAdapterOptions {
  mode?: ShadowWireAdapterMode;
  client?: ShadowWireMockClient;
  walletSigner?: WalletSigner;
  tokenMints?: Partial<Record<SupportedToken, string>>;
  relayerFee?: number;
  debug?: boolean;
}

const DEFAULT_TOKEN_MINTS: Record<SupportedToken, string> = {
  SOL: 'So11111111111111111111111111111111111111112',
  USD1: 'USD1ttGY1N17NEEHLmELoaybftRBUSErhqYiQzvEmuB',
  USDC: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
};

export class ShadowWireAdapter implements PaymentAdapter {
  readonly provider = 'shadowwire' as const;
  readonly name = 'ShadowWire';
  private mode: ShadowWireAdapterMode;
  private mockClient?: ShadowWireMockClient;
  private liveClient?: import('@radr/shadowwire').ShadowWireClient;
  private walletSigner?: WalletSigner;
  private tokenMints: Record<SupportedToken, string>;
  private relayerFee: number;
  private debug?: boolean;

  constructor(options: ShadowWireAdapterOptions = {}) {
    this.mode = options.mode ?? 'mock';
    this.relayerFee = options.relayerFee ?? 1_000_000;
    this.tokenMints = { ...DEFAULT_TOKEN_MINTS, ...options.tokenMints };
    this.walletSigner = options.walletSigner;
    this.debug = options.debug;

    if (this.mode === 'mock') {
      this.mockClient = options.client ?? new MockShadowWireClient();
    }
  }

  async getBalance(publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    if (this.mode === 'mock') {
      const balance = await this.mockClient!.getBalance(publicKey.toBase58(), token);
      return {
        available: balance.available,
        source: 'ShadowWire Mock'
      };
    }

    await this.ensureLiveClient();
    const balance = await this.liveClient!.getBalance(publicKey.toBase58(), token);
    return {
      available: balance.available,
      source: 'ShadowWire'
    };
  }

  async getLimit(_publicKey: PublicKey, _token: SupportedToken): Promise<number> {
    // For now, no hard limit enforced by the adapter itself
    return Infinity;
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    const now = context?.now ? context.now() : Date.now();
    let nonce: number | bigint = Math.floor(now / 1000);

    if (request.nullifier) {
      nonce = this.deriveNonce(request.nullifier);
    }

    const tokenMint = this.tokenMints[request.currency] ?? request.currency;
    const transferType = request.type ?? 'external';

    const proof = await this.uploadProof(request.agentId, tokenMint, request.amount, nonce, context);

    const transferRequest = {
      sender_wallet: request.agentId,
      recipient_wallet: request.vendor,
      token: tokenMint,
      nonce: proof.nonce,
      relayer_fee: this.relayerFee,
    };

    const transferResult =
      transferType === 'internal'
        ? await this.internalTransfer(transferRequest, context)
        : await this.externalTransfer(transferRequest, context);

    const txSignature = transferResult?.tx_signature;

    return {
      provider: this.provider,
      status: txSignature ? 'success' : 'failed',
      txSignature,
      paidAmount: request.amount,
      proofPda: proof?.proof_pda,
      nonce: proof?.nonce,
      raw: {
        proof,
        transfer: transferResult,
      },
    };
  }

  private resolveSigner(context?: PaymentContext): WalletSigner {
    const resolved = context?.walletSigner ?? this.walletSigner;
    if (!resolved) {
      throw new Error('ShadowWireAdapter requires walletSigner for live mode');
    }
    return resolved;
  }

  private async uploadProof(
    sender: string,
    token: string,
    amount: number,
    nonce: number | bigint,
    context?: PaymentContext
  ) {
    if (this.mode === 'mock') {
      return this.mockClient!.uploadProof({
        sender_wallet: sender,
        token,
        amount,
        nonce,
      });
    }

    await this.ensureLiveClient();
    return (this.liveClient! as any).uploadProof(
      {
        sender_wallet: sender,
        token,
        amount,
        nonce: typeof nonce === 'bigint' ? Number(nonce) : nonce,
      },
      this.resolveSigner(context)
    );
  }

  private async internalTransfer(
    request: { sender_wallet: string; recipient_wallet: string; token: string; nonce: number | bigint; relayer_fee?: number },
    context?: PaymentContext
  ) {
    if (this.mode === 'mock') {
      return this.mockClient!.internalTransfer(request);
    }
    await this.ensureLiveClient();
    return (this.liveClient! as any).internalTransfer(
      { ...request, nonce: typeof request.nonce === 'bigint' ? Number(request.nonce) : request.nonce },
      this.resolveSigner(context)
    );
  }

  private async externalTransfer(
    request: { sender_wallet: string; recipient_wallet: string; token: string; nonce: number | bigint; relayer_fee?: number },
    context?: PaymentContext
  ) {
    if (this.mode === 'mock') {
      return this.mockClient!.externalTransfer(request);
    }
    await this.ensureLiveClient();
    return (this.liveClient! as any).externalTransfer(
      { ...request, nonce: typeof request.nonce === 'bigint' ? Number(request.nonce) : request.nonce },
      this.resolveSigner(context)
    );
  }

  private async ensureLiveClient(): Promise<void> {
    if (this.liveClient) {
      return;
    }
    const module = await import('@radr/shadowwire');
    this.liveClient = new module.ShadowWireClient({ debug: this.debug });
  }

  private deriveNonce(nullifier: string): bigint {
    const cleanNullifier = nullifier.startsWith('0x') ? nullifier.slice(2) : nullifier;
    const nullifierBytes = Buffer.from(cleanNullifier, 'hex');
    const hash = keccak_256(nullifierBytes);
    const view = new DataView(hash.buffer, hash.byteOffset, 8);
    return view.getBigUint64(0, true);
  }
}

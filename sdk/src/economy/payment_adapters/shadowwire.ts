import {
  PaymentAdapter,
  PaymentContext,
  PaymentExecutionResult,
  PaymentRequest,
  WalletSigner,
} from '../payments';
import { MockShadowWireClient, ShadowWireMockClient } from '../payment_mocks/shadowwire';
import { SupportedToken } from '../wallet';

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

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    const now = context?.now ? context.now() : Date.now();
    const nonce = Math.floor(now / 1000);
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
    nonce: number,
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
    return this.liveClient!.uploadProof(
      {
        sender_wallet: sender,
        token,
        amount,
        nonce,
      },
      this.resolveSigner(context)
    );
  }

  private async internalTransfer(
    request: { sender_wallet: string; recipient_wallet: string; token: string; nonce: number; relayer_fee?: number },
    context?: PaymentContext
  ) {
    if (this.mode === 'mock') {
      return this.mockClient!.internalTransfer(request);
    }
    await this.ensureLiveClient();
    return this.liveClient!.internalTransfer(request, this.resolveSigner(context));
  }

  private async externalTransfer(
    request: { sender_wallet: string; recipient_wallet: string; token: string; nonce: number; relayer_fee?: number },
    context?: PaymentContext
  ) {
    if (this.mode === 'mock') {
      return this.mockClient!.externalTransfer(request);
    }
    await this.ensureLiveClient();
    return this.liveClient!.externalTransfer(request, this.resolveSigner(context));
  }

  private async ensureLiveClient(): Promise<void> {
    if (this.liveClient) {
      return;
    }
    const module = await import('@radr/shadowwire');
    this.liveClient = new module.ShadowWireClient({ debug: this.debug });
  }
}

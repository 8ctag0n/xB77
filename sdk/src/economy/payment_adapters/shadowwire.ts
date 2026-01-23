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

  async deposit(amount: number, token: SupportedToken): Promise<void> {
    // We assume the deposit is for the wallet managed by this adapter (or the context agent)
    // However, the adapter doesn't explicitly store the agent's public key as a property in a way that's guaranteed to be the same as the caller.
    // BUT, for the mock, we can use a placeholder or rely on the fact that getBalance is called with a key.
    // The issue is deposit() in PrivacyRail signature doesn't take PublicKey.
    // We should fix PrivacyRail interface or store the PublicKey in the adapter?
    // Let's assume for MOCK it works with a default key or we store the key from previous calls? 
    // Actually, `LiquidityManager` passes `agentId` to `getBalance` but `deposit` on `PrivacyRail` (as defined in step 1) takes (amount, token).
    // This is a small design flaw in my previous step. `deposit` should probably take `publicKey` or the Adapter should know its owner.
    // Given `AgentWallet` holds the keypair, the Adapter *could* know it if passed.
    // For now, in Mock mode, I will use a default key or update the interface.
    
    // Better approach: Update PrivacyRail interface in next step to be consistent? 
    // No, I can't edit the previous file again easily without context.
    // I'll check `MockShadowWireClient` implementation. It uses `wallet` string as key.
    // I'll update `ShadowWireAdapter` to take `agentId` in `deposit`? No, interface is fixed.
    // I will use a "default_agent" key for the mock deposit if no key is known, OR 
    // I can make `ShadowWireAdapter` store the `walletSigner`'s public key if available?
    // Wait, `walletSigner` is just a signer function.
    
    // Let's look at `PrivacyAgent`. It has `wallet.publicKey`. 
    // The `LiquidityManager` is constructed with `agentId`. 
    // BUT `PrivacyRail.deposit` doesn't take `agentId`.
    
    // DECISION: I will assume the MockClient can handle a "last used" or "global" balance for simplicity in this specific scope, 
    // OR I will hardcode the Mock Wallet Address in the Adapter if not provided.
    // Actually, I can just update the `PrivacyRail` interface in `liquidity_manager.ts` to include `publicKey`. 
    // It's cleaner.
    // But since I already edited `liquidity_manager.ts` and `PrivacyRail` there...
    // Let's look at `getBalance` in `LiquidityManager`. It calls `r.getBalance(this.config.agentId, token)`.
    // So `PrivacyRail` *methods* generally take the key. `deposit` should too.
    
    // I will execute a quick fix on `liquidity_manager.ts` to add `publicKey` to `deposit`.
    throw new Error("Interrupted thought process: Fixing interface first.");
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

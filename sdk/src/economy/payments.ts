import { PaymentReceipt, PaymentType } from './receipts';
import { SupportedToken } from './wallet';

export type PaymentProvider = 'shadowwire' | 'privacy_cash';
export type PaymentStatus = 'success' | 'failed';

export interface PaymentRequest {
  amount: number;
  currency: SupportedToken;
  agentId: string;
  vendor: string;
  memoHash?: string;
  type?: PaymentType;
  provider?: PaymentProvider;
}

export interface PaymentExecutionResult {
  provider: PaymentProvider;
  status: PaymentStatus;
  txSignature?: string;
  paidAmount?: number;
  proofPda?: string;
  nonce?: number;
  fee?: number;
  raw?: unknown;
}

export interface WalletSigner {
  signMessage: (message: Uint8Array) => Promise<Uint8Array>;
}

export interface PaymentContext {
  now?: () => number;
  walletSigner?: WalletSigner;
}

export interface PaymentAdapter {
  provider: PaymentProvider;
  execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult>;
}

const SUPPORTED_TOKENS: SupportedToken[] = ['SOL', 'USD1', 'USDC'];

export function validatePaymentRequest(request: PaymentRequest): void {
  if (!Number.isFinite(request.amount) || request.amount <= 0) {
    throw new Error('payment_request.amount must be a positive number');
  }
  if (!request.agentId?.trim()) {
    throw new Error('payment_request.agent_id is required');
  }
  if (!request.vendor?.trim()) {
    throw new Error('payment_request.vendor is required');
  }
  if (!SUPPORTED_TOKENS.includes(request.currency)) {
    throw new Error(`payment_request.currency must be one of ${SUPPORTED_TOKENS.join(', ')}`);
  }
  if (request.type && request.type !== 'internal' && request.type !== 'external') {
    throw new Error('payment_request.type must be internal or external');
  }
}

export function buildPaymentReceipt(
  request: PaymentRequest,
  result: PaymentExecutionResult,
  timestamp: number = Date.now()
): PaymentReceipt {
  if (result.status !== 'success' || !result.txSignature) {
    throw new Error('Cannot build receipt from failed payment result');
  }

  return {
    sender: request.agentId,
    recipient: request.vendor,
    token: request.currency,
    amount: result.paidAmount ?? request.amount,
    type: request.type ?? 'external',
    proofPda: result.proofPda,
    nonce: result.nonce,
    txSignature: result.txSignature,
    timestamp,
  };
}

export class PaymentGateway {
  private adapters: Record<PaymentProvider, PaymentAdapter>;
  private defaultProvider: PaymentProvider;

  constructor(adapters: Record<PaymentProvider, PaymentAdapter>, defaultProvider: PaymentProvider) {
    this.adapters = adapters;
    this.defaultProvider = defaultProvider;
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    validatePaymentRequest(request);
    const provider = request.provider ?? this.defaultProvider;
    const adapter = this.adapters[provider];
    if (!adapter) {
      throw new Error(`payment_gateway.adapter_missing for provider ${provider}`);
    }
    return await adapter.execute({ ...request, provider }, context);
  }
}

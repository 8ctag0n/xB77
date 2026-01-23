import type { SupportedToken } from './wallet';

export type PaymentType = 'internal' | 'external';

export interface PaymentReceipt {
  sender: string;
  recipient: string;
  token: SupportedToken;
  amount: number;
  type: PaymentType;
  proofPda?: string;
  nonce?: number | bigint;
  txSignature?: string;
  timestamp: number;
}

export interface ReceiptStore {
  recordPayment(receipt: PaymentReceipt): Promise<void>;
  listReceipts(limit?: number): Promise<PaymentReceipt[]>;
  getLatestReceipt(): Promise<PaymentReceipt | null>;
}

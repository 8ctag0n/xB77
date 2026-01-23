import type { SupportedToken } from './wallet';

export type PaymentType = 'internal' | 'external';

export interface PaymentMetadata {
  method?: string; // 'Virtual Card', 'Zk-Transfer', etc
  providerName?: string; // 'Starpay', 'ShadowWire'
  cardLast4?: string;
  externalRef?: string;
  complianceScore?: number;
}

export interface PaymentReceipt {
  sender: string;
  recipient: string;
  token: SupportedToken;
  amount: number;
  type: PaymentType;
  provider: string;
  proofPda?: string;
  nonce?: number | bigint;
  txSignature?: string;
  timestamp: number;
  metadata?: PaymentMetadata;
}

export interface ReceiptStore {
  recordPayment(receipt: PaymentReceipt): Promise<void>;
  listReceipts(limit?: number): Promise<PaymentReceipt[]>;
  getLatestReceipt(): Promise<PaymentReceipt | null>;
}

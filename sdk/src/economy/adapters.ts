import { PublicKey } from '@solana/web3.js';
import { BalanceInfo, BalanceProvider } from './balance';
import { PaymentReceipt, ReceiptStore } from './receipts';
import { SupportedToken } from './wallet';

export class InMemoryReceiptStore implements ReceiptStore {
  private receipts: PaymentReceipt[] = [];

  async recordPayment(receipt: PaymentReceipt): Promise<void> {
    this.receipts.push(receipt);
  }

  getAll(): PaymentReceipt[] {
    return [...this.receipts];
  }
}

export class StaticBalanceProvider implements BalanceProvider {
  private balances: Partial<Record<SupportedToken, number>>;
  private source: string;

  constructor(balances: Partial<Record<SupportedToken, number>> = {}, source: string = 'static') {
    this.balances = balances;
    this.source = source;
  }

  async getBalance(_: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    return {
      available: this.balances[token] ?? 0,
      source: this.source
    };
  }
}

export class CsplBalanceProviderStub implements BalanceProvider {
  constructor(private client: unknown) {}

  async getBalance(_: PublicKey, __: SupportedToken): Promise<BalanceInfo> {
    throw new Error('CsplBalanceProviderStub not implemented. Wire C-SPL client here.');
  }
}

export class CompressedReceiptStoreStub implements ReceiptStore {
  constructor(private client: unknown) {}

  async recordPayment(_: PaymentReceipt): Promise<void> {
    throw new Error('CompressedReceiptStoreStub not implemented. Wire receipts client here.');
  }
}

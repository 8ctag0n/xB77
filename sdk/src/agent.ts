import { Keypair } from '@solana/web3.js';
import { AgentWallet } from './economy/wallet';
import type { PaymentResult, SupportedToken } from './economy/wallet';
import type { BalanceProvider } from './economy/balance';
import { IdentityManager } from './identity/manager';
import type { PaymentReceipt, PaymentType, ReceiptStore } from './economy/receipts';

export interface AgentConfig {
  keypair: Keypair;
  debug?: boolean;
  balanceProvider?: BalanceProvider;
  receiptStore?: ReceiptStore;
}

export class PrivacyAgent {
  public wallet: AgentWallet;
  public identity: IdentityManager;
  private balanceProvider?: BalanceProvider;
  private receiptStore?: ReceiptStore;

  constructor(config: AgentConfig) {
    this.wallet = new AgentWallet(config.keypair, config.debug);
    this.identity = new IdentityManager();
    this.balanceProvider = config.balanceProvider;
    this.receiptStore = config.receiptStore;
    console.log(`[PrivacyAgent] Initialized agent with public key: ${config.keypair.publicKey.toBase58()}`);
  }

  /**
   * High-level command to execute a private payment
   * Checks identity first (conceptually) then pays.
   */
  async pay(
    recipient: string,
    amount: number,
    token: SupportedToken = 'USD1',
    type: PaymentType = 'external'
  ): Promise<PaymentResult> {
    // 1. In a real scenario, we might want to generate a proof of authority first
    // await this.identity.proveAccess();
    
    // 2. Execute payment
    const result = await this.wallet.pay(recipient, amount, token, type);

    if (this.receiptStore) {
      const receipt: PaymentReceipt = {
        sender: this.wallet.publicKey.toBase58(),
        recipient,
        token,
        amount,
        type,
        proofPda: result.proofPda,
        nonce: result.nonce,
        txSignature: result.txSignature,
        timestamp: Date.now()
      };
      await this.receiptStore.recordPayment(receipt);
    }

    return result;
  }

  /**
   * Optional balance adapter (useful for C-SPL pool or receipts-based balance).
   */
  async getBalance(token: SupportedToken = 'USD1') {
    if (this.balanceProvider) {
      return await this.balanceProvider.getBalance(this.wallet.publicKey, token);
    }
    return await this.wallet.getBalance(token);
  }

  /**
   * Deposit funds into the privacy pool (Shielding)
   */
  async shield(amount: number, token: SupportedToken = 'SOL') {
     // TODO: Implement deposit/shield logic via ShadowWire
     console.log("Shielding functionality coming soon via ShadowWire deposit()");
  }
}

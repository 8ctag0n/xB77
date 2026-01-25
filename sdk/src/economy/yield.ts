import { PublicKey } from '@solana/web3.js';
import { SupportedToken } from './wallet';
import { BalanceInfo, BalanceProvider } from './balance';

/**
 * Interface for protocols that generate yield (Lending, Staking, etc.)
 */
export interface YieldProvider extends BalanceProvider {
  name: string;
  /**
   * Deposits funds into the yield-bearing instrument.
   */
  deposit(amount: number, token: SupportedToken): Promise<void>;
  /**
   * Withdraws funds from the yield-bearing instrument.
   */
  withdraw(amount: number, token: SupportedToken): Promise<void>;
  /**
   * Returns the current Annual Percentage Yield (APY) as a decimal (e.g., 0.085 for 8.5%).
   */
  getAPY(): number;
}

/**
 * A mock implementation of Kamino Lending to demonstrate yield-based funding.
 * It simulates interest accrual over time.
 */
export class KaminoMockProvider implements YieldProvider {
  name = 'Kamino Lending (Mock)';
  private balances: Map<string, number> = new Map();
  private lastUpdate: number = Date.now();
  private apy = 0.085; // 8.5% APY

  async getBalance(publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo> {
    this.applyInterest();
    const amount = this.balances.get(token) || 0;
    return { available: amount, source: this.name };
  }

  async deposit(amount: number, token: SupportedToken): Promise<void> {
    this.applyInterest();
    const current = this.balances.get(token) || 0;
    this.balances.set(token, current + amount);
    console.log(`[Yield] Deposited ${amount} ${token} into ${this.name}. New Balance: ${current + amount}`);
  }

  async withdraw(amount: number, token: SupportedToken): Promise<void> {
    this.applyInterest();
    const current = this.balances.get(token) || 0;
    if (current < amount) throw new Error(`Insufficient yield balance in ${this.name}`);
    this.balances.set(token, current - amount);
    console.log(`[Yield] Withdrew ${amount} ${token} from ${this.name}. Remaining: ${current - amount}`);
  }

  getAPY(): number {
    return this.apy;
  }

  /**
   * Simulates interest accrual based on elapsed time since last update.
   */
  private applyInterest() {
    const now = Date.now();
    const elapsedHours = (now - this.lastUpdate) / (1000 * 60 * 60);
    
    if (elapsedHours > 0) {
      for (const [token, amount] of this.balances.entries()) {
        // Compound interest (approximate)
        const interest = amount * (this.apy / (365 * 24)) * elapsedHours;
        if (interest > 0) {
          this.balances.set(token, amount + interest);
          // Only log significant interest to avoid noise
          if (interest > 0.0001) {
             console.log(`[Yield] ${this.name} accrued ${interest.toFixed(6)} ${token} in interest.`);
          }
        }
      }
    }
    this.lastUpdate = now;
  }
}

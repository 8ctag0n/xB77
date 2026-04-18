import type { PublicKey } from '@solana/web3.js';
import type { SupportedToken } from './wallet';
import type { BalanceInfo, BalanceProvider } from './balance';
import { LiquidityError } from './errors';
import { YieldProvider } from './yield';

export interface TreasurySnapshot {
  fiat: BalanceInfo;
  crypto: BalanceInfo;
  yield: BalanceInfo;
  totalUsd: number;
}

/**
 * Represents a source of liquidity (e.g., Starpay Corporate Card)
 */
export interface LiquiditySource extends BalanceProvider {
  name: string;
  /**
   * Transfers funds from this source to the private crypto rail.
   * In a real scenario, this would involve a swap or bridge.
   */
  fund(amount: number, token: SupportedToken): Promise<{ txId: string; amount: number }>;
}

/**
 * Represents a private payment rail (e.g., ShadowWire, Privacy Cash)
 */
export interface PrivacyRail extends BalanceProvider {
  name: string;
  /**
   * Returns the current operational limit for the agent on this rail.
   */
  getLimit(publicKey: PublicKey, token: SupportedToken): Promise<number>;
  /**
   * Deposits funds into the rail (e.g., minting tokens or crediting balance).
   */
  deposit(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void>;
  /**
   * Withdraws funds from the rail (e.g. to move to yield).
   */
  withdraw(publicKey: PublicKey, amount: number, token: SupportedToken): Promise<void>;
}

export interface LiquidityManagerConfig {
  agentId: PublicKey;
  sources: LiquiditySource[];
  rails: PrivacyRail[];
  yieldProvider?: YieldProvider;
  /**
   * The threshold below which a rebalance is triggered automatically.
   */
  minLiquidityThreshold: number;
  /**
   * The target amount to reach when rebalancing.
   */
  targetLiquidity: number;
  /**
   * If crypto balance exceeds this, move excess to yield.
   */
  maxLiquidityThreshold?: number;
}

export class LiquidityManager {
  constructor(private config: LiquidityManagerConfig) {}

  /**
   * Gets a combined view of all treasury sources.
   */
  async getFullSnapshot(token: SupportedToken = 'USD1'): Promise<TreasurySnapshot> {
    const fiatBalances = await Promise.all(
      this.config.sources.map(s => s.getBalance(this.config.agentId, token))
    );
    
    const cryptoBalances = await Promise.all(
      this.config.rails.map(r => r.getBalance(this.config.agentId, token))
    );

    const yieldBalance = this.config.yieldProvider 
      ? await this.config.yieldProvider.getBalance(this.config.agentId, token)
      : { available: 0, source: 'None' };

    const fiatTotal = fiatBalances.reduce((acc, b) => acc + b.available, 0);
    const cryptoTotal = cryptoBalances.reduce((acc, b) => acc + b.available, 0);

    return {
      fiat: { available: fiatTotal, source: 'Starpay Aggregate' },
      crypto: { available: cryptoTotal, source: 'XB77 Private Aggregate' },
      yield: yieldBalance,
      totalUsd: fiatTotal + cryptoTotal + yieldBalance.available
    };
  }

  /**
   * Checks if liquidity is low and triggers a rebalance if necessary.
   * Also optimizes yield if there is excess liquidity.
   */
  async checkAndRebalance(token: SupportedToken = 'USD1'): Promise<{ rebalanced: boolean; amount?: number; optimized: boolean }> {
    const snapshot = await this.getFullSnapshot(token);
    let optimized = false;

    // 1. Check for under-liquidity (Funding)
    if (snapshot.crypto.available < this.config.minLiquidityThreshold) {
      // Check if we can pull from yield first
      if (snapshot.yield.available > 0 && this.config.yieldProvider) {
        const pullAmount = Math.min(snapshot.yield.available, this.config.targetLiquidity - snapshot.crypto.available);
        console.log(`[LiquidityManager] Pulling ${pullAmount} from Yield to cover shortage.`);
        await this.config.yieldProvider.withdraw(pullAmount, token);
        const rail = this.config.rails[0];
        if (rail) await rail.deposit(this.config.agentId, pullAmount, token);
        return { rebalanced: true, amount: pullAmount, optimized: true };
      }

      const amountToFund = this.config.targetLiquidity - snapshot.crypto.available;
      const result = await this.executeRebalance(amountToFund, token);
      return { ...result, optimized };
    }

    // 2. Check for over-liquidity (Yield Optimization)
    if (this.config.yieldProvider && this.config.maxLiquidityThreshold && snapshot.crypto.available > this.config.maxLiquidityThreshold) {
      const excess = snapshot.crypto.available - this.config.targetLiquidity;
      console.log(`[LiquidityManager] Excess liquidity detected: ${excess}. Moving to ${this.config.yieldProvider.name}`);
      const rail = this.config.rails[0];
      if (rail) {
        await rail.withdraw(this.config.agentId, excess, token);
        await this.config.yieldProvider.deposit(excess, token);
        optimized = true;
      }
    }

    return { rebalanced: false, optimized };
  }

  /**
   * Ensures the privacy rail has at least 'amount' available.
   * If not, it triggers a just-in-time top-up.
   */
  async ensureFunds(requiredAmount: number, token: SupportedToken = 'USD1'): Promise<void> {
    const rail = this.config.rails[0];
    if (!rail) throw new LiquidityError('No privacy rail configured');

    const balance = await rail.getBalance(this.config.agentId, token);
    
    if (balance.available < requiredAmount) {
      const shortage = requiredAmount - balance.available;
      console.log(`[LiquidityManager] Shortage detected: ${shortage}. Initiating Auto-Topup...`);
      await this.executeRebalance(shortage + 10, token); // Add buffer
    }
  }

  private async executeRebalance(amount: number, token: SupportedToken): Promise<{ rebalanced: boolean; amount?: number }> {
    const source = this.config.sources[0];
    const rail = this.config.rails[0];

    if (source && rail) {
      try {
        // 1. Debit Source
        const result = await source.fund(amount, token);
        // 2. Credit Rail
        await rail.deposit(this.config.agentId, result.amount, token);
        return { rebalanced: true, amount: result.amount };
      } catch (e: any) {
        throw new LiquidityError(`Rebalance failed: ${e.message}`);
      }
    }
    return { rebalanced: false };
  }
}
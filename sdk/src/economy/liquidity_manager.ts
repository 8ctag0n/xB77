import type { PublicKey } from '@solana/web3.js';
import type { SupportedToken } from './wallet';
import type { BalanceInfo, BalanceProvider } from './balance';
import { LiquidityError } from './errors';

export interface TreasurySnapshot {
  fiat: BalanceInfo;
  crypto: BalanceInfo;
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
}

export interface LiquidityManagerConfig {
  agentId: PublicKey;
  sources: LiquiditySource[];
  rails: PrivacyRail[];
  /**
   * The threshold below which a rebalance is triggered automatically.
   */
  minLiquidityThreshold: number;
  /**
   * The target amount to reach when rebalancing.
   */
  targetLiquidity: number;
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

    const fiatTotal = fiatBalances.reduce((acc, b) => acc + b.available, 0);
    const cryptoTotal = cryptoBalances.reduce((acc, b) => acc + b.available, 0);

    return {
      fiat: { available: fiatTotal, source: 'Starpay Aggregate' },
      crypto: { available: cryptoTotal, source: 'XB77 Private Aggregate' },
      totalUsd: fiatTotal + cryptoTotal // Assuming 1:1 for simplicity in this version
    };
  }

  /**
   * Checks if liquidity is low and triggers a rebalance if necessary.
   */
  async checkAndRebalance(token: SupportedToken = 'USD1'): Promise<{ rebalanced: boolean; amount?: number }> {
    const snapshot = await this.getFullSnapshot(token);
    
    if (snapshot.crypto.available < this.config.minLiquidityThreshold) {
      const amountToFund = this.config.targetLiquidity - snapshot.crypto.available;
      
      if (amountToFund > 0 && snapshot.fiat.available >= amountToFund) {
        // Use the first source for now
        const source = this.config.sources[0];
        // Use the first rail for now
        const rail = this.config.rails[0];

        if (source && rail) {
          const result = await source.fund(amountToFund, token);
          // Inject liquidity into the rail
          await rail.deposit(this.config.agentId, result.amount, token);
          return { rebalanced: true, amount: result.amount };
        }
      }
    }

    return { rebalanced: false };
  }
}

export interface FeeRecord {
  timestamp: number;
  amount: number;
  token: string;
  category: 'gas' | 'relayer' | 'compute' | 'governance';
  txSignature?: string;
}

export interface EfficiencyMetrics {
  totalFees: number;
  totalYield: number;
  netProfit: number;
  isSelfSustaining: boolean;
  burnRate: number; // Fees per hour (approx)
}

/**
 * Tracks operational expenses to measure the agent's capital efficiency.
 */
export class FeeTracker {
  private records: FeeRecord[] = [];
  private startTime: number = Date.now();

  /**
   * Records a new operational fee.
   */
  recordFee(amount: number, category: FeeRecord['category'], token: string = 'USD1', txSignature?: string) {
    this.records.push({
      timestamp: Date.now(),
      amount,
      category,
      token,
      txSignature
    });
    console.log(`[FeeTracker] Recorded ${amount} ${token} for ${category}.`);
  }

  /**
   * Calculates total fees in a specific token (assumes USD1 for this version).
   */
  getTotalFees(): number {
    return this.records.reduce((acc, r) => acc + r.amount, 0);
  }

  /**
   * Calculates metrics by comparing fees against generated yield.
   */
  calculateEfficiency(totalYield: number): EfficiencyMetrics {
    const totalFees = this.getTotalFees();
    const netProfit = totalYield - totalFees;
    const hoursElapsed = (Date.now() - this.startTime) / (1000 * 60 * 60);
    const burnRate = hoursElapsed > 0 ? totalFees / hoursElapsed : 0;

    return {
      totalFees,
      totalYield,
      netProfit,
      isSelfSustaining: netProfit > 0,
      burnRate
    };
  }

  getRecentRecords(limit: number = 10): FeeRecord[] {
    return [...this.records].reverse().slice(0, limit);
  }
}

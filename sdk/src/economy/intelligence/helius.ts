import { IntelligenceProvider, RiskAssessment, PrivacyLevel } from './provider';

export interface HeliusConfig {
  apiKey: string;
  rpcUrl?: string;
  debug?: boolean;
}

export class HeliusIntelligenceAdapter implements IntelligenceProvider {
  readonly name = 'Helius Forensic Engine';
  private apiKey: string;
  private rpcUrl: string;
  private debug: boolean;

  constructor(config: HeliusConfig) {
    this.apiKey = config.apiKey;
    this.rpcUrl = config.rpcUrl || `https://mainnet.helius-rpc.com/?api-key=${this.apiKey}`;
    this.debug = config.debug || false;
  }

  async assessRisk(address: string, amount: number): Promise<RiskAssessment> {
    if (this.debug) console.log(`[HeliusIntelligence] Analyzing address: ${address}`);

    try {
      // 1. Fetch transactions via Helius enhanced RPC
      // Note: In localnet we might need to mock this if the API key isn't provided or valid for local addresses
      const transactions = await this.fetchTransactions(address);

      // 2. Run heuristics
      const signals = this.analyzeTransactions(transactions);
      
      // 3. Calculate Score
      const score = this.calculateScore(signals, transactions.length);

      // 4. Recommend Privacy Level
      let recommendedPrivacy: PrivacyLevel = 'none';
      if (score > 60) recommendedPrivacy = 'ghost';
      else if (score > 20) recommendedPrivacy = 'shielded';

      return {
        score,
        signals,
        recommendedPrivacy,
        reasoning: this.generateReasoning(score, signals, transactions.length),
        provider: this.name
      };

    } catch (error: any) {
      if (this.debug) console.error(`[HeliusIntelligence] Error:`, error.message);
      // Fail-safe: assume high risk if analysis fails
      return {
        score: 50,
        signals: { originContamination: false, isDormantMerchant: true, recentMixerInteraction: false, highVelocitySpike: false },
        recommendedPrivacy: 'shielded',
        reasoning: 'Analysis failed or limited data. Defaulting to shielded privacy for safety.',
        provider: this.name
      };
    }
  }

  private async fetchTransactions(address: string): Promise<any[]> {
    // If we are on localnet and address is short/mock, return mock data
    if (address.length < 32) return [];

    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 'helius-test',
        method: 'getTransactionsForAddress',
        params: [
          address,
          {
            limit: 20,
            // type: "TRANSFER" // We could filter, but comprehensive scan is better for forense
          }
        ]
      })
    });

    if (!response.ok) throw new Error(`Helius RPC error: ${response.statusText}`);
    const data = await response.json();
    return data.result || [];
  }

  private analyzeTransactions(txs: any[]): any {
    const signals = {
      originContamination: false,
      isDormantMerchant: txs.length < 5,
      recentMixerInteraction: false,
      highVelocitySpike: false
    };

    // Simple pattern matching on transactions
    for (const tx of txs) {
      const txStr = JSON.stringify(tx).toLowerCase();
      
      // Look for mixer programs or suspicious tags (placeholder logic)
      if (txStr.includes('mixer') || txStr.includes('tornado') || txStr.includes('privacy')) {
        signals.recentMixerInteraction = true;
      }

      // Check for recent activity (last tx older than 30 days)
      if (txs[0]?.blockTime) {
        const lastActive = txs[0].blockTime * 1000;
        const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
        if (lastActive < thirtyDaysAgo) signals.isDormantMerchant = true;
      }
    }

    return signals;
  }

  private calculateScore(signals: any, txCount: number): number {
    let score = 0;
    if (signals.recentMixerInteraction) score += 50;
    if (signals.originContamination) score += 40;
    if (signals.isDormantMerchant) score += 20;
    if (txCount === 0) score += 30; // Brand new address is suspicious
    
    return Math.min(100, score);
  }

  private generateReasoning(score: number, signals: any, txCount: number): string {
    if (score === 0) return 'Merchant has a healthy transaction history with consistent activity.';
    if (signals.recentMixerInteraction) return 'Detected interactions with privacy mixers in recent history. High anonymity risk.';
    if (txCount === 0) return 'Address has no transaction history on-chain. Possible ephemeral or throwaway merchant.';
    if (signals.isDormantMerchant) return 'Merchant has been dormant for a long period. Sudden activity suggests account takeover or reuse.';
    return `Risk score of ${score} based on low transaction volume and origin signals.`;
  }
}

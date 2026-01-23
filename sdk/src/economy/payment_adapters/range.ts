import type { PublicKey } from '@solana/web3.js';

export interface ComplianceScore {
  isSafe: boolean;
  score: number; // 0-100
  reason?: string;
}

export class RangeAdapter {
  readonly name = 'Range Compliance';

  /**
   * Validates a destination address against sanctions and risk lists.
   */
  async validateAddress(address: string | PublicKey): Promise<ComplianceScore> {
    const addrStr = typeof address === 'string' ? address : address.toBase58();
    
    // Mock: Some addresses are "known bad" for testing
    if (addrStr.startsWith('BAD_')) {
      return {
        isSafe: false,
        score: 10,
        reason: 'Address linked to suspicious activity'
      };
    }

    return {
      isSafe: true,
      score: 95
    };
  }

  /**
   * Pre-screens a transaction.
   */
  async preScreenPayment(recipient: string, amount: number): Promise<ComplianceScore> {
    if (amount > 5000) {
      return {
        isSafe: false,
        score: 30,
        reason: 'Amount exceeds daily risk threshold for unauthorized agents'
      };
    }

    return this.validateAddress(recipient);
  }
}

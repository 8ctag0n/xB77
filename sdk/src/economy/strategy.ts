import { PublicKey } from '@solana/web3.js';
import { PaymentProvider } from './payments';

export type PrivacyLevel = 'public' | 'standard' | 'ghost';
export type RiskLevel = 'low' | 'medium' | 'high' | 'critical';

export interface MixingPolicy {
  enabled: boolean;
  paranoiaLevel: 'low' | 'medium' | 'snowden';
  preferredRoute: 'light_self_transfer' | 'privacy_cash_hop';
  frequencyHours: number;
}

export interface PaymentContext {
  vendorCategory?: string; // e.g., 'cloud_compute', 'marketing', 'dark_web'
  isNewVendor?: boolean;
  history?: number; // Total volume with this vendor
  mixingPolicy?: MixingPolicy;
}

export interface ExecutionPlan {
  strategy: 'direct_fiat' | 'shielded_transfer' | 'ephemeral_relay' | 'privacy_cash_obfuscation';
  provider: PaymentProvider;
  privacyLevel: PrivacyLevel;
  riskAssessment: RiskLevel;
  steps: string[];
  estimatedFee: number;
  reasoning: string;
}

export class PaymentStrategyEngine {
  
  /**
   * Analyzes the transaction and determines the optimal execution strategy.
   * Using arrow function to preserve 'this' context.
   */
  evaluate = (
    recipient: string,
    amount: number,
    context: PaymentContext = {}
  ): ExecutionPlan => {
    const risk = this.assessRisk(recipient, amount, context);
    const privacy = this.determinePrivacyLevel(risk, context);
    
    return this.createPlan(privacy, risk, context.mixingPolicy);
  }

  private assessRisk = (recipient: string, amount: number, context: PaymentContext): RiskLevel => {
    // 1. Critical Flags
    if (context.vendorCategory === 'dark_web' || context.vendorCategory === 'gambling') {
      return 'critical';
    }

    // 2. Amount Thresholds
    if (amount > 10000) return 'high';
    if (amount > 1000) return 'medium';

    // 3. New Vendor Heuristic
    if (context.isNewVendor && amount > 500) return 'medium';

    return 'low';
  }

  private determinePrivacyLevel = (risk: RiskLevel, context: PaymentContext): PrivacyLevel => {
    if (risk === 'critical') return 'ghost'; // Maximum paranoia
    if (risk === 'high') return 'ghost';
    if (risk === 'medium') return 'standard';
    
    // For low risk, prefer efficiency unless explicitly private
    if (context.vendorCategory === 'payroll') return 'standard'; // Payroll always private
    
    return 'public';
  }

  private createPlan = (privacy: PrivacyLevel, risk: RiskLevel, policy?: MixingPolicy): ExecutionPlan => {
    // Check if Privacy Cash Hop is enforced by policy for high risk
    if (risk === 'critical' || (risk === 'high' && policy?.preferredRoute === 'privacy_cash_hop')) {
        return {
          strategy: 'privacy_cash_obfuscation',
          provider: 'privacy_cash',
          privacyLevel: 'ghost',
          riskAssessment: risk,
          steps: [
            'Obfuscation: Deposit to Privacy Cash Pool',
            'Withdraw to Ephemeral Wallet (Break Link)',
            'Final Payment via ShadowWire (USD1)'
          ],
          estimatedFee: 0.008,
          reasoning: 'Critical risk. Enforcing double-hop obfuscation via Privacy Cash pool before payment.'
        };
    }

    switch (privacy) {
      case 'ghost':
        return {
          strategy: 'ephemeral_relay',
          provider: 'shadowwire',
          privacyLevel: 'ghost',
          riskAssessment: risk,
          steps: [
            'Generate Ephemeral Keypair (Burner Wallet)',
            'Shielded Transfer (USD1): Treasury -> Burner (Break Link)',
            'Standard Transfer (USD1): Burner -> Vendor',
            'Burn Keys'
          ],
          estimatedFee: 0.005, // Higher fee for multi-hop
          reasoning: 'High-risk transaction requires breaking on-chain link via ephemeral relay using USD1 privacy stablecoin.'
        };
      
      case 'standard':
        return {
          strategy: 'shielded_transfer',
          provider: 'shadowwire',
          privacyLevel: 'standard',
          riskAssessment: risk,
          steps: [
            'Shielded Transfer (USD1): Treasury -> Vendor'
          ],
          estimatedFee: 0.001,
          reasoning: 'Standard privacy requested. Direct shielded transfer using USD1.'
        };

      case 'public':
      default:
        return {
          strategy: 'direct_fiat',
          provider: 'starpay',
          privacyLevel: 'public',
          riskAssessment: risk,
          steps: [
            'Fiat Settlement via Starpay API'
          ],
          estimatedFee: 0,
          reasoning: 'Low risk / Trusted vendor. Off-chain fiat settlement is cheapest.'
        };
    }
  }
}
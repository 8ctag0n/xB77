export type PrivacyLevel = 'none' | 'shielded' | 'ghost';

export interface RiskSignals {
  originContamination: boolean;   // Near known bad addresses
  isDormantMerchant: boolean;     // Merchant has very low/old activity
  recentMixerInteraction: boolean; // Mixer usage detected
  highVelocitySpike: boolean;     // Unusual surge in volume
}

export interface RiskAssessment {
  score: number; // 0-100
  signals: RiskSignals;
  recommendedPrivacy: PrivacyLevel;
  reasoning: string;
  provider: string;
}

export interface IntelligenceProvider {
  name: string;
  assessRisk(address: string, amount: number): Promise<RiskAssessment>;
}

import { PublicKey } from '@solana/web3.js';
import { SupportedToken } from './wallet';

export interface BalanceInfo {
  available: number;
  source?: string;
}

export interface BalanceProvider {
  getBalance(publicKey: PublicKey, token: SupportedToken): Promise<BalanceInfo>;
}

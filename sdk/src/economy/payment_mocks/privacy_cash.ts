import { createHash } from 'crypto';

function hashSeed(seed: string): string {
  return createHash('sha256').update(seed).digest('hex');
}

function mockId(prefix: string, seed: string): string {
  return `${prefix}_${hashSeed(seed).slice(0, 32)}`;
}

export interface PrivacyCashMockDepositRequest {
  owner: string;
  token: string;
  amount: number;
}

export interface PrivacyCashMockWithdrawRequest {
  recipientAddress: string;
  token: string;
  amount: number;
}

export interface PrivacyCashMockDepositResponse {
  tx: string;
}

export interface PrivacyCashMockWithdrawResponse {
  tx: string;
  fee_lamports?: number;
}

export interface PrivacyCashMockClient {
  deposit(request: PrivacyCashMockDepositRequest): Promise<PrivacyCashMockDepositResponse>;
  withdraw(request: PrivacyCashMockWithdrawRequest): Promise<PrivacyCashMockWithdrawResponse>;
  depositSPL(request: PrivacyCashMockDepositRequest): Promise<PrivacyCashMockDepositResponse>;
  withdrawSPL(request: PrivacyCashMockWithdrawRequest): Promise<PrivacyCashMockWithdrawResponse>;
  getBalance(owner: string, token: string): Promise<{ available: number }>;
}

export class MockPrivacyCashClient implements PrivacyCashMockClient {
  private balances: Map<string, number> = new Map();

  private getBalanceKey(owner: string, token: string): string {
    return `${owner}:${token}`;
  }

  async getBalance(owner: string, token: string): Promise<{ available: number }> {
    const balance = this.balances.get(this.getBalanceKey(owner, token)) || 0;
    return { available: balance };
  }

  async deposit(request: PrivacyCashMockDepositRequest): Promise<PrivacyCashMockDepositResponse> {
    const key = this.getBalanceKey(request.owner, request.token);
    const current = this.balances.get(key) || 0;
    this.balances.set(key, current + request.amount);
    
    const seed = `deposit:${request.owner}:${request.token}:${request.amount}`;
    return { tx: mockId('mock_deposit', seed) };
  }

  async withdraw(request: PrivacyCashMockWithdrawRequest): Promise<PrivacyCashMockWithdrawResponse> {
    // In a real mock, we'd need to know WHO is withdrawing to check balance.
    // But the withdraw request only has recipientAddress.
    // For this mock, we'll assume the withdrawal is from a global pool or 
    // we just simulate the TX. 
    // To be more realistic for the Yield demo, we'll just return a TX.
    
    const seed = `withdraw:${request.recipientAddress}:${request.token}:${request.amount}`;
    return {
      tx: mockId('mock_withdraw', seed),
      fee_lamports: 1000,
    };
  }

  async depositSPL(request: PrivacyCashMockDepositRequest): Promise<PrivacyCashMockDepositResponse> {
    return this.deposit(request);
  }

  async withdrawSPL(request: PrivacyCashMockWithdrawRequest): Promise<PrivacyCashMockWithdrawResponse> {
    return this.withdraw(request);
  }
}
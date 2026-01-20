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
}

export class MockPrivacyCashClient implements PrivacyCashMockClient {
  async deposit(request: PrivacyCashMockDepositRequest): Promise<PrivacyCashMockDepositResponse> {
    const seed = `deposit:${request.owner}:${request.token}:${request.amount}`;
    return { tx: mockId('mock_deposit', seed) };
  }

  async withdraw(request: PrivacyCashMockWithdrawRequest): Promise<PrivacyCashMockWithdrawResponse> {
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

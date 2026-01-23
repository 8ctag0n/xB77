import { createHash } from 'crypto';

function hashSeed(seed: string): string {
  return createHash('sha256').update(seed).digest('hex');
}

function mockId(prefix: string, seed: string): string {
  return `${prefix}_${hashSeed(seed).slice(0, 32)}`;
}

export interface ShadowWireMockUploadRequest {
  sender_wallet: string;
  token: string;
  amount: number;
  nonce: number | bigint;
}

export interface ShadowWireMockTransferRequest {
  sender_wallet: string;
  recipient_wallet: string;
  token: string;
  nonce: number | bigint;
  relayer_fee?: number;
}

export interface ShadowWireMockUploadResponse {
  proof_pda: string;
  nonce: number | bigint;
}

export interface ShadowWireMockTransferResponse {
  tx_signature: string;
}

export interface ShadowWireMockClient {
  uploadProof(request: ShadowWireMockUploadRequest): Promise<ShadowWireMockUploadResponse>;
  internalTransfer(request: ShadowWireMockTransferRequest): Promise<ShadowWireMockTransferResponse>;
  externalTransfer(request: ShadowWireMockTransferRequest): Promise<ShadowWireMockTransferResponse>;
  getBalance(wallet: string, token: string): Promise<{ available: number; pool_address: string }>;
}

export class MockShadowWireClient implements ShadowWireMockClient {
  async getBalance(_wallet: string, _token: string): Promise<{ available: number; pool_address: string }> {
    return {
      available: 1000, // Mock balance
      pool_address: 'mock_pool_address'
    };
  }

  async uploadProof(request: ShadowWireMockUploadRequest): Promise<ShadowWireMockUploadResponse> {
    const seed = `${request.sender_wallet}:${request.token}:${request.amount}:${request.nonce}`;
    return {
      proof_pda: mockId('mock_proof', seed),
      nonce: request.nonce,
    };
  }

  async internalTransfer(request: ShadowWireMockTransferRequest): Promise<ShadowWireMockTransferResponse> {
    const seed = `internal:${request.sender_wallet}:${request.recipient_wallet}:${request.token}:${request.nonce}`;
    return {
      tx_signature: mockId('mock_tx', seed),
    };
  }

  async externalTransfer(request: ShadowWireMockTransferRequest): Promise<ShadowWireMockTransferResponse> {
    const seed = `external:${request.sender_wallet}:${request.recipient_wallet}:${request.token}:${request.nonce}`;
    return {
      tx_signature: mockId('mock_tx', seed),
    };
  }
}

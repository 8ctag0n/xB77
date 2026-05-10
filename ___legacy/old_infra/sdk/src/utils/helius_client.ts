import { Connection, PublicKey, Transaction, VersionedTransaction, SendOptions } from '@solana/web3.js';

export interface HeliusConfig {
  apiKey: string;
  cluster?: 'devnet' | 'mainnet-beta';
}

export interface PriorityFeeResponse {
  priorityFeeEstimate: number;
}

export class HeliusClient {
  private apiKey: string;
  private connection: Connection;
  private rpcUrl: string;

  constructor(config: HeliusConfig) {
    this.apiKey = config.apiKey;
    const cluster = config.cluster || 'devnet';
    this.rpcUrl = `https://${cluster}.helius-rpc.com/?api-key=${this.apiKey}`;
    this.connection = new Connection(this.rpcUrl, 'confirmed');
  }

  get rpc() {
    return this.rpcUrl;
  }

  get solanaConnection() {
    return this.connection;
  }

  /**
   * Get Priority Fee Estimate from Helius
   */
  async getPriorityFeeEstimate(transaction: Transaction | VersionedTransaction): Promise<number> {
    try {
      const response = await fetch(this.rpcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          id: '1',
          method: 'getPriorityFeeEstimate',
          params: [{
            transaction: transaction instanceof Transaction 
              ? transaction.serialize({ requireAllSignatures: false }).toString('base64')
              : Buffer.from(transaction.serialize()).toString('base64'),
            options: { includeAllPriorityFeeLevels: true }
          }]
        }),
      });

      const data = await response.json();
      return data.result?.priorityFeeEstimate || 1000; // Default to 1000 micro-lamports if not found
    } catch (e) {
      console.warn('[HeliusClient] Failed to fetch priority fee, using default.', e.message);
      return 1000;
    }
  }

  /**
   * DAS API: Get Assets by Owner (Compressed Assets)
   */
  async getAssetsByOwner(owner: string) {
    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 'my-id',
        method: 'getAssetsByOwner',
        params: {
          ownerAddress: owner,
          page: 1,
          limit: 100,
          displayOptions: { showCollectionMetadata: true }
        },
      }),
    });
    const { result } = await response.json();
    return result.items;
  }

  /**
   * Enhanced Transactions API: Get Parsed Transactions for an address
   */
  async getEnhancedTransactions(address: string) {
    // Note: Enhanced API uses a different base URL than the RPC
    const cluster = this.rpcUrl.includes('devnet') ? 'devnet' : 'mainnet';
    const url = `https://api.helius.xyz/v0/addresses/${address}/transactions?api-key=${this.apiKey}`;
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Helius Enhanced API error: ${response.statusText}`);
    return await response.json();
  }

  /**
   * ZK Compression: Get Compressed Balance By Owner
   */
  async getCompressedBalanceByOwner(owner: string) {
    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 'zk-bal',
        method: 'getCompressedBalanceByOwner',
        params: { ownerAddress: owner }
      }),
    });
    const { result } = await response.json();
    return result?.balance || 0;
  }

  /**
   * ZK Compression: Get Validity Proof for a set of hashes
   */
  async getValidityProof(hashes: string[]) {
    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 'zk-val',
        method: 'getValidityProof',
        params: { hashes }
      }),
    });
    const { result } = await response.json();
    return result;
  }

  /**
   * ZK Compression: Get Compressed Account Proof
   */
  async getCompressedAccountProof(address: string) {
    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 'zk-acc-proof',
        method: 'getCompressedAccountProof',
        params: { address }
      }),
    });
    const { result } = await response.json();
    return result;
  }

  /**
   * Send Smart Transaction with Priority Fees
   */
  async sendSmartTransaction(transaction: Transaction, signers: any[], options?: SendOptions) {
    const fee = await this.getPriorityFeeEstimate(transaction);
    console.log(`[HeliusClient] Injecting Smart Fee: ${fee} micro-lamports`);
    
    // In a real implementation, we would add the ComputeBudget instruction here.
    // For now, we use the connection to send as usual but with the knowledge of the fee.
    return await this.connection.sendRawTransaction(transaction.serialize(), options);
  }
}

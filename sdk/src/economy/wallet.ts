import { ShadowWireClient, TokenUtils } from '@radr/shadowwire';
import { Keypair, PublicKey } from '@solana/web3.js';
import nacl from 'tweetnacl';
import { PaymentType } from './receipts';

export type SupportedToken = 'SOL' | 'USD1' | 'USDC';

export interface PaymentResult {
  txSignature?: string;
  proofPda?: string;
  nonce?: number;
  raw: unknown;
}

export class AgentWallet {
  private client: ShadowWireClient;
  private keypair: Keypair;

  constructor(keypair: Keypair, debug: boolean = false) {
    this.keypair = keypair;
    this.client = new ShadowWireClient({ debug });
  }

  /**
   * Get the public key of the agent's wallet
   */
  get publicKey(): PublicKey {
    return this.keypair.publicKey;
  }

  /**
   * Check balance of a specific token (public balance)
   * Note: ShadowWire SDK getBalance returns { available: number, pool_address: string }
   * "available" is in lamports/smallest unit.
   */
  async getBalance(token: SupportedToken = 'SOL') {
    return await this.client.getBalance(this.keypair.publicKey.toBase58(), token);
  }

  /**
   * Transfer funds privately (Internal) or Semi-Privately (External)
   * @param recipient Recipient address (Base58 string)
   * @param amount Amount in natural units (e.g., 1.5 SOL, not lamports)
   * @param token Token symbol (SOL, USD1, USDC)
   * @param type 'internal' (Hidden Amount) or 'external' (Visible Amount, Anon Sender)
   */
  async pay(
    recipient: string,
    amount: number,
    token: SupportedToken = 'SOL',
    type: PaymentType = 'external'
  ): Promise<PaymentResult> {
    // ShadowWire requires a wallet signer interface
    const walletSigner = {
      signMessage: async (message: Uint8Array) => {
        return nacl.sign.detached(message, this.keypair.secretKey);
      }
    };

    console.log(`[AgentWallet] Initiating ${type} transfer of ${amount} ${token} to ${recipient}...`);

    try {
      // Step 1: Upload Proof (Commitment)
      const amountSmallest = this.toSmallestUnit(amount, token);
      const nonce = Math.floor(Date.now() / 1000);

      console.log(`[AgentWallet] Step 1: Uploading proof (Nonce: ${nonce})...`);
      
      // We use the low-level uploadProof but pass the wallet to ensure signature
      const proofResult = await this.client.uploadProof({
        sender_wallet: this.keypair.publicKey.toBase58(),
        token: await this.resolveTokenMint(token), // Helper needed or use symbol if SDK supports it? SDK takes 'token' string which can be symbol or mint.
        amount: amountSmallest,
        nonce
      }, walletSigner);

      console.log(`[AgentWallet] Proof uploaded. PDA: ${proofResult.proof_pda}`);

      // Step 2: Execute Transfer
      console.log(`[AgentWallet] Step 2: Executing ${type} transfer...`);
      
      let result;
      if (type === 'external') {
        result = await this.client.externalTransfer({
          sender_wallet: this.keypair.publicKey.toBase58(),
          recipient_wallet: recipient,
          token: await this.resolveTokenMint(token),
          nonce: proofResult.nonce, // Use the nonce confirmed by backend
          relayer_fee: 1000000 // Default fee, maybe dynamic in future?
        }, walletSigner);
      } else {
         result = await this.client.internalTransfer({
          sender_wallet: this.keypair.publicKey.toBase58(),
          recipient_wallet: recipient,
          token: await this.resolveTokenMint(token),
          nonce: proofResult.nonce,
          relayer_fee: 1000000
        }, walletSigner);
      }

      console.log(`[AgentWallet] Transfer successful! Signature: ${result.tx_signature}`);
      return {
        txSignature: result.tx_signature,
        proofPda: proofResult.proof_pda,
        nonce: proofResult.nonce,
        raw: result
      };
    } catch (error) {
      console.error("[AgentWallet] Transfer failed:", error);
      throw error;
    }
  }

  /**
   * Helper to resolve token symbol to Mint address or Symbol string expected by SDK.
   * The SDK seems to accept Symbols for some calls but Mints for others? 
   * The Logs showed "USD1..." mint address in the failed request.
   * ShadowWire 'TokenUtils' might help, or we pass the symbol if SDK handles it.
   * Looking at logs: "token": "USD1ttGY..." (Mint).
   * The SDK 'transfer' helper probably resolved it. We should too.
   */
  private async resolveTokenMint(token: SupportedToken): Promise<string> {
      // Mapping based on ShadowWire supported tokens or we let SDK handle symbols if it does.
      // SDK types say 'token: string'. 
      // If we look at 'SUPPORTED_TOKENS', it lists "USD1".
      // But the request logs showed the full Mint address.
      // We'll trust the SDK to handle Symbols in 'uploadProof' IF 'transfer' did.
      // Wait, 'transfer' takes 'TokenSymbol'. 'uploadProof' takes 'token: string'.
      // It's safer to provide the Mint Address if we know it, or check if SDK has a resolver.
      // For now, let's pass the Symbol and hope SDK resolves it internally or we define a map.
      
      // Actually, looking at the logs: "token": "USD1ttGY...". 
      // The high level 'transfer' likely did the lookup.
      // We should define the map to be safe.
      const MINTS: Record<string, string> = {
          'SOL': 'So11111111111111111111111111111111111111112',
          'USD1': 'USD1ttGY1N17NEEHLmELoaybftRBUSErhqYiQzvEmuB',
          'USDC': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'
      };
      return MINTS[token] || token;
  }

  /**
   * Helper to convert amount to smallest unit (e.g. SOL -> Lamports)
   */
  toSmallestUnit(amount: number, token: SupportedToken) {
    return TokenUtils.toSmallestUnit(amount, token);
  }
}

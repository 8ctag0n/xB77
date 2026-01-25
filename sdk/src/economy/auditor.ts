import nacl from 'tweetnacl';
import { PaymentReceipt } from './receipts';

/**
 * Result of a selective disclosure audit request.
 * Contains revealed fields and a cryptographic attestation from the agent.
 */
export interface AuditProof {
  receiptId: string;
  revealedData: Partial<PaymentReceipt>;
  timestamp: number;
  attestation: string; // Base64 signature
}

/**
 * Component responsible for generating verifiable proofs of past expenses
 * without disclosing full transaction history or sensitive metadata.
 */
export class ReceiptAuditor {
  constructor(private agentSecretKey: Uint8Array) {}

  /**
   * Generates a selective disclosure proof for a specific receipt.
   * @param receipt The full receipt from the agent's private store.
   * @param fieldsToReveal List of fields to include in the public proof.
   */
  async generateCertifiedProof(receipt: PaymentReceipt, fieldsToReveal: string[]): Promise<AuditProof> {
    const revealedData: Partial<PaymentReceipt> = {};
    
    // Core fields often required for basic accounting are included if selected
    // but amount/token/timestamp are usually the bare minimum.
    const defaultFields = ['amount', 'token', 'timestamp'];
    const allToReveal = new Set([...defaultFields, ...fieldsToReveal]);

    if (allToReveal.has('amount')) revealedData.amount = receipt.amount;
    if (allToReveal.has('token')) revealedData.token = receipt.token;
    if (allToReveal.has('timestamp')) revealedData.timestamp = receipt.timestamp;
    if (allToReveal.has('recipient')) revealedData.recipient = receipt.recipient;
    if (allToReveal.has('type')) revealedData.type = receipt.type;
    if (allToReveal.has('provider')) revealedData.provider = receipt.provider;
    if (allToReveal.has('metadata')) revealedData.metadata = receipt.metadata;

    const proofBody = JSON.stringify({
      receiptId: receipt.txSignature,
      revealedData,
      attestationTimestamp: Date.now()
    });

    // Sign the proof body using the agent's secret key
    const signature = nacl.sign.detached(
      Buffer.from(proofBody),
      this.agentSecretKey
    );

    return {
      receiptId: receipt.txSignature || 'unknown',
      revealedData,
      timestamp: Date.now(),
      attestation: Buffer.from(signature).toString('base64')
    };
  }
}

import { Connection, PublicKey, Transaction, Keypair, sendAndConfirmTransaction } from '@solana/web3.js';
import { 
  PaymentAdapter, 
  PaymentRequest, 
  PaymentExecutionResult, 
  PaymentContext 
} from '../payments';
import { 
  createRequestPaymentInstruction,
  PROGRAM_ID as CORE_PROGRAM_ID
} from '../../generated/instructions/xb77_core';
import { SupportedToken } from '../wallet';

export interface XB77AdapterOptions {
  connection: Connection;
  coreProgramId?: PublicKey;
  gatewayProgramId?: PublicKey;
  receiptsProgramId?: PublicKey;
  payer: Keypair;
}

export class XB77Adapter implements PaymentAdapter {
  readonly provider = 'shadowwire'; // Mapping to shadowwire provider identity for compatibility
  private connection: Connection;
  private coreProgramId: PublicKey;
  private gatewayProgramId: PublicKey;
  private receiptsProgramId: PublicKey;
  private payer: Keypair;

  constructor(options: XB77AdapterOptions) {
    this.connection = options.connection;
    this.coreProgramId = options.coreProgramId || CORE_PROGRAM_ID;
    this.gatewayProgramId = options.gatewayProgramId || new PublicKey("FTN81z9qc5eiBrSzeD9pnEcJQmwJA4hj5xGqFQAJA6Hm");
    this.receiptsProgramId = options.receiptsProgramId || new PublicKey("6LM5tQioTsog9AmiHbXBN69YrFBzzhspVWyxBvxKZss3");
    this.payer = options.payer;
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    console.log(`[XB77Adapter] Executing on-chain payment for ${request.amount} ${request.currency} to ${request.vendor}`);

    try {
      const agentPubKey = new PublicKey(request.agentId);
      const vendorPubKey = new PublicKey(request.vendor);
      
      // 1. Derive necessary PDAs
      const [configPda] = PublicKey.findProgramAddressSync([Buffer.from("config_v3")], this.coreProgramId);
      const [creditLinePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("credit_line"), agentPubKey.toBuffer()],
        this.coreProgramId
      );

      // 2. Prepare Instruction Data
      // Note: In a real integration, memoHash and proof would come from ZK prover
      const memoHash = Buffer.alloc(32).fill(0); 
      const proof = Buffer.alloc(0); 
      const addressTreeInfo = Buffer.alloc(0);

      const ix = createRequestPaymentInstruction(
        {
          requestId: BigInt(Date.now()),
          amount: BigInt(request.amount),
          vendor: Array.from(vendorPubKey.toBuffer()),
          memoHash: Array.from(memoHash),
          proof: proof,
          addressTreeInfo: addressTreeInfo,
          outputStateTreeIndex: 0
        },
        {
          configAccount: configPda,
          creditLineAccount: creditLinePda,
          agentSigner: agentPubKey,
          receiptsProgram: this.receiptsProgramId
        },
        this.coreProgramId
      );

      // 3. Add necessary dummy accounts for Receipts CPI (for now)
      const [lightCpiSigner] = PublicKey.findProgramAddressSync([Buffer.from("light_cpi")], this.receiptsProgramId);
      ix.keys.push({ pubkey: lightCpiSigner, isSigner: false, isWritable: false });
      ix.keys.push({ pubkey: PublicKey.default, isSigner: false, isWritable: false }); // System Program placeholder

      // 4. Send Transaction
      const tx = new Transaction().add(ix);
      const signature = await sendAndConfirmTransaction(
        this.connection, 
        tx, 
        [this.payer], // Assume payer signs if agent is just an ID for now, or agentKp if available
        { commitment: 'confirmed' }
      );

      console.log(`[XB77Adapter] Transaction Successful: ${signature}`);

      return {
        provider: this.provider,
        status: 'success',
        txSignature: signature,
        paidAmount: request.amount,
        raw: { signature }
      };

    } catch (error: any) {
      console.error(`[XB77Adapter] Payment Failed:`, error.message);
      return {
        provider: this.provider,
        status: 'failed',
        raw: error
      };
    }
  }

  async getCreditBalance(agentPubKey: PublicKey): Promise<bigint> {
    const [creditLinePda] = PublicKey.findProgramAddressSync(
      [Buffer.from("credit_line"), agentPubKey.toBuffer()],
      this.coreProgramId
    );
    
    const info = await this.connection.getAccountInfo(creditLinePda);
    if (!info) return BigInt(0);
    
    // Simple deserialization of CreditLine (skipping owner at 0-32)
    // CreditLine { owner: 32, balance: u64, ... }
    const balance = info.data.readBigUInt64LE(32);
    return balance;
  }
}

import { Connection, PublicKey, Transaction, Keypair, sendAndConfirmTransaction } from '@solana/web3.js';
import { createHash } from 'crypto';
import { Buffer } from 'buffer';
import { createRpc, getDefaultAddressTreeInfo, selectStateTreeInfo, TreeType, type TreeInfo } from '@lightprotocol/stateless.js';
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
import { buildLightRecordReceiptContext, serializePackedAddressTreeInfo, serializeValidityProof } from '../receipts_light';

export interface XB77AdapterOptions {
  connection: Connection;
  coreProgramId?: PublicKey;
  gatewayProgramId?: PublicKey;
  receiptsProgramId?: PublicKey;
  lightRpcUrl?: string;
  lightCompressionUrl?: string;
  lightProverUrl?: string;
  addressTreeInfo?: TreeInfo;
  stateTreeInfo?: TreeInfo;
  payer: Keypair;
}

export class XB77Adapter implements PaymentAdapter {
  readonly provider = 'xb77' as const; // Distinct identity for xB77 Native Privacy
  private connection: Connection;
  private coreProgramId: PublicKey;
  private gatewayProgramId: PublicKey;
  private receiptsProgramId: PublicKey;
  private lightRpcUrl?: string;
  private lightCompressionUrl?: string;
  private lightProverUrl?: string;
  private addressTreeInfo?: TreeInfo;
  private stateTreeInfo?: TreeInfo;
  private payer: Keypair;

  constructor(options: XB77AdapterOptions) {
    this.connection = options.connection;
    this.coreProgramId = options.coreProgramId || CORE_PROGRAM_ID;
    this.gatewayProgramId = options.gatewayProgramId || new PublicKey("4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC");
    this.receiptsProgramId = options.receiptsProgramId || new PublicKey("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
    this.lightRpcUrl = options.lightRpcUrl ?? process.env.SOLANA_RPC_URL;
    this.lightCompressionUrl = options.lightCompressionUrl ?? process.env.LIGHT_COMPRESSION_RPC_URL;
    this.lightProverUrl = options.lightProverUrl ?? process.env.LIGHT_PROVER_RPC_URL;
    this.addressTreeInfo = options.addressTreeInfo;
    this.stateTreeInfo = options.stateTreeInfo;
    this.payer = options.payer;
  }

  private parseHex32(value: string, name: string): Uint8Array {
    const trimmed = value.startsWith('0x') ? value.slice(2) : value;
    if (trimmed.length > 64) {
      throw new Error(`${name} must be at most 32 bytes hex`);
    }
    const padded = trimmed.padStart(64, '0');
    const buffer = Buffer.from(padded, 'hex');
    if (buffer.length !== 32) {
      throw new Error(`${name} must be 32 bytes`);
    }
    return new Uint8Array(buffer);
  }

  private hashMemo(input: string): Uint8Array {
    return new Uint8Array(createHash('sha256').update(input).digest());
  }

  async execute(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    console.log(`[XB77Adapter] Executing on-chain payment for ${request.amount} ${request.currency} to ${request.vendor}`);

    try {
      const agentPubKey = new PublicKey(request.agentId);
      const vendorPubKey = new PublicKey(request.vendor);

      if (!agentPubKey.equals(this.payer.publicKey)) {
        throw new Error('XB77Adapter requires agent signer to match payer keypair.');
      }
      
      // 1. Derive necessary PDAs
      const [configPda] = PublicKey.findProgramAddressSync([Buffer.from("config_v3")], this.coreProgramId);
      const [creditLinePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("credit_line"), agentPubKey.toBuffer()],
        this.coreProgramId
      );

      // 2. Prepare Instruction Data
      if (!Number.isInteger(request.amount) || request.amount < 0) {
        throw new Error('XB77Adapter requires integer amount for on-chain payment.');
      }

      const memoHash = request.memoHash
        ? this.parseHex32(request.memoHash, 'memoHash')
        : this.hashMemo(`${request.vendor}:${request.amount}:${Date.now()}`);

      let proofBytes = new Uint8Array();
      let addressTreeInfoBytes = new Uint8Array();
      let outputStateTreeIndex = 0;
      let receiptAccounts: Array<{ pubkey: PublicKey; isSigner: boolean; isWritable: boolean }> = [];

      try {
        if (!this.lightRpcUrl || !this.lightCompressionUrl || !this.lightProverUrl) {
          throw new Error('Missing Light RPC endpoints.');
        }
        const rpc = createRpc(this.lightRpcUrl, this.lightCompressionUrl, this.lightProverUrl);
        const addressTreeInfo = this.addressTreeInfo ?? getDefaultAddressTreeInfo();
        const stateTreeInfo =
          this.stateTreeInfo ??
          selectStateTreeInfo(await rpc.getStateTreeInfos(), TreeType.StateV1);

        const receiptContext = await buildLightRecordReceiptContext({
          rpc,
          receiptProgramId: this.receiptsProgramId,
          addressTreeInfo,
          outputStateTreeInfo: stateTreeInfo,
          vendor: new Uint8Array(vendorPubKey.toBytes()),
          amount: BigInt(request.amount),
          memoHash
        });

        proofBytes = serializeValidityProof(receiptContext.proof);
        addressTreeInfoBytes = serializePackedAddressTreeInfo(receiptContext.addressTreeInfo);
        outputStateTreeIndex = receiptContext.outputStateTreeIndex;
        receiptAccounts = receiptContext.remainingAccounts;
      } catch (error) {
        throw new Error(`Receipt context unavailable: ${error instanceof Error ? error.message : String(error)}`);
      }

      const ix = createRequestPaymentInstruction(
        {
          requestId: BigInt(Date.now()),
          amount: BigInt(request.amount),
          vendor: Array.from(vendorPubKey.toBuffer()),
          memoHash: Array.from(memoHash),
          proof: proofBytes,
          addressTreeInfo: addressTreeInfoBytes,
          outputStateTreeIndex: outputStateTreeIndex
        },
        {
          configAccount: configPda,
          creditLineAccount: creditLinePda,
          agentSigner: agentPubKey,
          receiptsProgram: this.receiptsProgramId
        },
        this.coreProgramId
      );

      if (receiptAccounts.length) {
        ix.keys.push(...receiptAccounts);
      }

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

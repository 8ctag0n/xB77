import { PublicKey, TransactionInstruction, AccountMeta } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { WincodeSerializer } from '../../utils/wincode';

export interface CompressedReceipt {
  owner: PublicKey;
  vendor: Uint8Array | number[];
  amount: bigint | number;
  timestamp: bigint | number;
  memoHash: Uint8Array | number[];
}

export function serializeCompressedReceipt(serializer: WincodeSerializer, value: CompressedReceipt) {
  serializer.writePubkey(value.owner);
  serializer.writeFixedArray(Buffer.from(value.vendor), 32);
  serializer.writeU64(value.amount);
  serializer.writeI64(value.timestamp);
  serializer.writeFixedArray(Buffer.from(value.memoHash), 32);
}

export interface RecordReceiptInstructionData {
  proof: Uint8Array | Buffer;
  addressTreeInfo: Uint8Array | Buffer;
  outputStateTreeIndex: number;
  vendor: Uint8Array | number[];
  amount: bigint | number;
  memoHash: Uint8Array | number[];
}

export function serializeRecordReceiptInstructionData(serializer: WincodeSerializer, value: RecordReceiptInstructionData) {
  serializer.writeVec(Buffer.from(value.proof));
  serializer.writeVec(Buffer.from(value.addressTreeInfo));
  serializer.writeU8(value.outputStateTreeIndex);
  serializer.writeFixedArray(Buffer.from(value.vendor), 32);
  serializer.writeU64(value.amount);
  serializer.writeFixedArray(Buffer.from(value.memoHash), 32);
}

export const PROGRAM_ID = new PublicKey('9kknYrFBjkBUuMyZZhksoHcj29gjfzGsDMgnyfp3Y6VM');

export function createRecordReceiptInstruction(recordReceiptInstructionData: RecordReceiptInstructionData, accounts: { signer: PublicKey, agentAccount: PublicKey, lightCpiSigner: PublicKey, systemProgram: PublicKey, lightSystemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU8(0);
  serializeRecordReceiptInstructionData(serializer, recordReceiptInstructionData);

  const keys: AccountMeta[] = [
    { pubkey: accounts.signer, isSigner: true, isWritable: false },
    { pubkey: accounts.agentAccount, isSigner: false, isWritable: false },
    { pubkey: accounts.lightCpiSigner, isSigner: false, isWritable: false },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
    { pubkey: accounts.lightSystemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}


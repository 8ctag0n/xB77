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

function encodeU32LE(value: number): Uint8Array {
  const buffer = new ArrayBuffer(4);
  new DataView(buffer).setUint32(0, value, true);
  return new Uint8Array(buffer);
}

function encodeU64LE(value: bigint | number): Uint8Array {
  const buffer = new ArrayBuffer(8);
  new DataView(buffer).setBigUint64(0, BigInt(value), true);
  return new Uint8Array(buffer);
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

export function serializeRecordReceiptInstructionData(_: WincodeSerializer, value: RecordReceiptInstructionData) {
  const proof = Buffer.from(value.proof);
  const addressTreeInfo = Buffer.from(value.addressTreeInfo);
  const vendor = Buffer.from(value.vendor);
  const memoHash = Buffer.from(value.memoHash);

  if (vendor.length !== 32) {
    throw new Error(`vendor must be 32 bytes, got ${vendor.length}`);
  }
  if (memoHash.length !== 32) {
    throw new Error(`memoHash must be 32 bytes, got ${memoHash.length}`);
  }

  return concatBytes([
    encodeU32LE(proof.length),
    proof,
    encodeU32LE(addressTreeInfo.length),
    addressTreeInfo,
    new Uint8Array([value.outputStateTreeIndex]),
    vendor,
    encodeU64LE(value.amount),
    memoHash,
  ]);
}

export const PROGRAM_ID = new PublicKey('8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W');

export function createRecordReceiptInstruction(recordReceiptInstructionData: RecordReceiptInstructionData, accounts: { signer: PublicKey, agentAccount: PublicKey, lightCpiSigner: PublicKey, systemProgram: PublicKey, lightSystemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  const payload = serializeRecordReceiptInstructionData(serializer, recordReceiptInstructionData);
  const data = new Uint8Array(1 + payload.length);
  data[0] = 0;
  data.set(payload, 1);

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
    data: Buffer.from(data),
  });
}

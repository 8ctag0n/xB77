import { array, option, struct, u16, u8 } from '@coral-xyz/borsh';
import type {
  PackedAddressTreeInfo,
  Rpc,
  TreeInfo,
  ValidityProof,
} from '@lightprotocol/stateless.js';
import {
  bn,
  deriveAddress,
  deriveAddressSeed,
  PackedAccounts,
  SystemAccountMetaConfig,
  TreeType,
} from '@lightprotocol/stateless.js';
import type { AccountMeta } from '@solana/web3.js';
import { PublicKey } from '@solana/web3.js';
import { Buffer } from 'buffer';
import type { SupportedToken } from './wallet';

const RECEIPT_ADDRESS_SEED = new TextEncoder().encode('receipt');

const CompressedProofLayout = struct([
  array(u8(), 32, 'a'),
  array(u8(), 64, 'b'),
  array(u8(), 32, 'c'),
]);

const ValidityProofLayout = struct([option(CompressedProofLayout, 'proof')]);

const PackedAddressTreeInfoLayout = struct([
  u8('addressMerkleTreePubkeyIndex'),
  u8('addressQueuePubkeyIndex'),
  u16('rootIndex'),
]);

export type PaymentType = 'internal' | 'external';

export interface PaymentReceipt {
  sender: string;
  recipient: string;
  token: SupportedToken;
  amount: number;
  type: PaymentType;
  proofPda?: string;
  nonce?: number | bigint;
  txSignature?: string;
  timestamp: number;
}

export interface ReceiptStore {
  recordPayment(receipt: PaymentReceipt): Promise<void>;
  listReceipts(limit?: number): Promise<PaymentReceipt[]>;
  getLatestReceipt(): Promise<PaymentReceipt | null>;
}

export type ReceiptInstructionKind = 'record';

export const RECEIPT_INSTRUCTION_DISCRIMINATORS: Record<ReceiptInstructionKind, number> = {
  record: 0,
};

export function buildReceiptInstructionData(
  kind: ReceiptInstructionKind,
  payloadBytes: Uint8Array
): Uint8Array {
  const discriminator = RECEIPT_INSTRUCTION_DISCRIMINATORS[kind];
  const data = new Uint8Array(1 + payloadBytes.length);
  data[0] = discriminator;
  data.set(payloadBytes, 1);
  return data;
}

export interface ReceiptProgramAccounts {
  receiptProgram: string;
  remainingAccounts: string[];
}

export function buildReceiptProgramAccounts(
  receiptProgram: string,
  remainingAccounts: string[]
): ReceiptProgramAccounts {
  return {
    receiptProgram,
    remainingAccounts,
  };
}

export interface RecordReceiptInstructionInput {
  proofBytes: Uint8Array;
  addressTreeInfoBytes: Uint8Array;
  outputStateTreeIndex: number;
  vendor: Uint8Array;
  amount: bigint;
  memoHash: Uint8Array;
}

function encodeU32LE(value: number): Uint8Array {
  const buffer = new ArrayBuffer(4);
  new DataView(buffer).setUint32(0, value, true);
  return new Uint8Array(buffer);
}

function encodeU64LE(value: bigint): Uint8Array {
  const buffer = new ArrayBuffer(8);
  new DataView(buffer).setBigUint64(0, value, true);
  return new Uint8Array(buffer);
}

function getOutputStateTreeAccount(treeInfo: TreeInfo): PublicKey {
  return treeInfo.treeType === TreeType.StateV2 ? treeInfo.queue : treeInfo.tree;
}

function encodeBorsh(layout: { encode: (value: any, buffer: Buffer) => number }, value: any) {
  const buffer = Buffer.alloc(256);
  const length = layout.encode(value, buffer);
  return new Uint8Array(buffer.subarray(0, length));
}

function normalizeFixedBytes(
  name: string,
  value: Uint8Array | number[],
  length: number
): number[] {
  const bytes = Array.from(value);
  if (bytes.length !== length) {
    throw new Error(`${name} must be ${length} bytes, got ${bytes.length}`);
  }
  return bytes;
}

export function serializeValidityProof(proof: ValidityProof | null): Uint8Array {
  const proofValue = proof
    ? {
        a: normalizeFixedBytes('proof.a', proof.a, 32),
        b: normalizeFixedBytes('proof.b', proof.b, 64),
        c: normalizeFixedBytes('proof.c', proof.c, 32),
      }
    : null;

  return encodeBorsh(ValidityProofLayout, { proof: proofValue });
}

export function serializePackedAddressTreeInfo(info: PackedAddressTreeInfo): Uint8Array {
  return encodeBorsh(PackedAddressTreeInfoLayout, {
    addressMerkleTreePubkeyIndex: info.addressMerkleTreePubkeyIndex,
    addressQueuePubkeyIndex: info.addressQueuePubkeyIndex,
    rootIndex: info.rootIndex,
  });
}

function ensureLength(name: string, value: Uint8Array, length: number): void {
  if (value.length !== length) {
    throw new Error(`${name} must be ${length} bytes, got ${value.length}`);
  }
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

export function serializeRecordReceiptInstruction(
  input: RecordReceiptInstructionInput
): Uint8Array {
  ensureLength('vendor', input.vendor, 32);
  ensureLength('memoHash', input.memoHash, 32);

  return concatBytes([
    encodeU32LE(input.proofBytes.length),
    input.proofBytes,
    encodeU32LE(input.addressTreeInfoBytes.length),
    input.addressTreeInfoBytes,
    new Uint8Array([input.outputStateTreeIndex]),
    input.vendor,
    encodeU64LE(input.amount),
    input.memoHash,
  ]);
}

export interface RecordReceiptInstructionLightInput {
  proof: ValidityProof | null;
  addressTreeInfo: PackedAddressTreeInfo;
  outputStateTreeIndex: number;
  vendor: Uint8Array;
  amount: bigint;
  memoHash: Uint8Array;
}

export function serializeRecordReceiptInstructionFromLight(
  input: RecordReceiptInstructionLightInput
): Uint8Array {
  return serializeRecordReceiptInstruction({
    proofBytes: serializeValidityProof(input.proof),
    addressTreeInfoBytes: serializePackedAddressTreeInfo(input.addressTreeInfo),
    outputStateTreeIndex: input.outputStateTreeIndex,
    vendor: input.vendor,
    amount: input.amount,
    memoHash: input.memoHash,
  });
}

export interface LightRecordReceiptContext {
  instructionData: Uint8Array;
  remainingAccounts: AccountMeta[];
  derivedAddress: PublicKey;
  proof: ValidityProof | null;
  addressTreeInfo: PackedAddressTreeInfo;
  outputStateTreeIndex: number;
}

export interface ReceiptAccountSpec {
  pubkey: string;
  isSigner: boolean;
  isWritable: boolean;
}

export function toReceiptAccountSpecs(accounts: AccountMeta[]): ReceiptAccountSpec[] {
  return accounts.map((account) => ({
    pubkey: account.pubkey.toBase58(),
    isSigner: account.isSigner,
    isWritable: account.isWritable
  }));
}

export async function buildLightRecordReceiptContext(input: {
  rpc: Rpc;
  receiptProgramId: PublicKey;
  addressTreeInfo: TreeInfo;
  outputStateTreeInfo: TreeInfo;
  vendor: Uint8Array;
  amount: bigint;
  memoHash: Uint8Array;
}): Promise<LightRecordReceiptContext> {
  const seeds = [RECEIPT_ADDRESS_SEED, input.vendor, input.memoHash];
  
  const addressSeed = deriveAddressSeed(
    seeds,
    input.receiptProgramId
  );
  const derivedAddress = deriveAddress(addressSeed, input.addressTreeInfo.tree);

  const validity = await input.rpc.getValidityProofV0([], [
    {
      tree: input.addressTreeInfo.tree,
      queue: input.addressTreeInfo.queue,
      address: bn(derivedAddress.toBytes())
    }
  ]);

  if (!validity.rootIndices.length || validity.rootIndices[0] === undefined) {
    throw new Error('No root indices returned from Light RPC for address proof');
  }

  const packedAccounts = PackedAccounts.newWithSystemAccounts(
    SystemAccountMetaConfig.new(input.receiptProgramId)
  );

  const addressMerkleTreePubkeyIndex = packedAccounts.insertOrGet(
    input.addressTreeInfo.tree
  );
  const addressQueuePubkeyIndex = packedAccounts.insertOrGet(input.addressTreeInfo.queue);
  const outputStateTreeIndex = packedAccounts.insertOrGet(
    getOutputStateTreeAccount(input.outputStateTreeInfo)
  );

  const addressTreeInfo: PackedAddressTreeInfo = {
    addressMerkleTreePubkeyIndex,
    addressQueuePubkeyIndex,
    rootIndex: validity.rootIndices[0]
  };

  const instructionData = serializeRecordReceiptInstructionFromLight({
    proof: validity.compressedProof,
    addressTreeInfo,
    outputStateTreeIndex,
    vendor: input.vendor,
    amount: input.amount,
    memoHash: input.memoHash
  });

  return {
    instructionData,
    remainingAccounts: packedAccounts.toAccountMetas().remainingAccounts,
    derivedAddress,
    proof: validity.compressedProof,
    addressTreeInfo,
    outputStateTreeIndex
  };
}

import { array, bool, option, struct, u16, u32, u8 } from '@coral-xyz/borsh';
import type {
  CompressedAccountMeta,
  CompressedAccountWithMerkleContext,
  PackedAddressTreeInfo,
  PackedStateTreeInfo,
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
import { SupportedToken } from './wallet';

const RECEIPT_ADDRESS_SEED = new TextEncoder().encode('receipt');

const CompressedProofLayout = struct([
  array(u8(), 32, 'a'),
  array(u8(), 64, 'b'),
  array(u8(), 32, 'c'),
]);

const ValidityProofLayout = struct([option(CompressedProofLayout, 'proof')]);

const PackedStateTreeInfoLayout = struct([
  u16('rootIndex'),
  bool('proveByIndex'),
  u8('merkleTreePubkeyIndex'),
  u8('queuePubkeyIndex'),
  u32('leafIndex'),
]);

const PackedAddressTreeInfoLayout = struct([
  u8('addressMerkleTreePubkeyIndex'),
  u8('addressQueuePubkeyIndex'),
  u16('rootIndex'),
]);

const CompressedAccountMetaLayout = struct([
  PackedStateTreeInfoLayout.replicate('treeInfo'),
  array(u8(), 32, 'address'),
  u8('outputStateTreeIndex'),
]);

export type PaymentType = 'internal' | 'external';

export interface PaymentReceipt {
  sender: string;
  recipient: string;
  token: SupportedToken;
  amount: number;
  type: PaymentType;
  proofPda?: string;
  nonce?: number;
  txSignature?: string;
  timestamp: number;
}

export interface ReceiptStore {
  recordPayment(receipt: PaymentReceipt): Promise<void>;
  listReceipts(limit?: number): Promise<PaymentReceipt[]>;
  getLatestReceipt(): Promise<PaymentReceipt | null>;
}

export type ReceiptInstructionKind = 'create' | 'update';

export const RECEIPT_INSTRUCTION_DISCRIMINATORS: Record<ReceiptInstructionKind, number> = {
  create: 0,
  update: 1,
};

export function buildReceiptInstructionData(
  kind: ReceiptInstructionKind,
  payloadBytes: Uint8Array
): Uint8Array {
  // payloadBytes must be Borsh-serialized for xb77_receipts.
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

export interface CreateReceiptInstructionInput {
  proofBytes: Uint8Array;
  addressTreeInfoBytes: Uint8Array;
  outputStateTreeIndex: number;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}

export interface UpdateReceiptInstructionInput {
  proofBytes: Uint8Array;
  accountMetaBytes: Uint8Array;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}

function encodeU32LE(value: number): Uint8Array {
  const buffer = new ArrayBuffer(4);
  new DataView(buffer).setUint32(0, value, true);
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

function toPackedStateTreeInfo(treeInfo: PackedStateTreeInfo): PackedStateTreeInfo {
  return {
    rootIndex: treeInfo.rootIndex,
    proveByIndex: treeInfo.proveByIndex,
    merkleTreePubkeyIndex: treeInfo.merkleTreePubkeyIndex,
    queuePubkeyIndex: treeInfo.queuePubkeyIndex,
    leafIndex: treeInfo.leafIndex,
  };
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

export function serializeCompressedAccountMeta(meta: CompressedAccountMeta): Uint8Array {
  if (!meta.address) {
    throw new Error('CompressedAccountMeta.address is required for receipts');
  }
  if (meta.lamports !== null && meta.lamports !== undefined) {
    throw new Error('CompressedAccountMeta.lamports is not supported for receipts');
  }

  return encodeBorsh(CompressedAccountMetaLayout, {
    treeInfo: toPackedStateTreeInfo(meta.treeInfo),
    address: normalizeFixedBytes('CompressedAccountMeta.address', meta.address, 32),
    outputStateTreeIndex: meta.outputStateTreeIndex,
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

export function serializeCreateReceiptInstruction(
  input: CreateReceiptInstructionInput
): Uint8Array {
  ensureLength('orderCommitment', input.orderCommitment, 32);
  ensureLength('receiptHash', input.receiptHash, 32);
  ensureLength('orderbookRoot', input.orderbookRoot, 32);

  return concatBytes([
    encodeU32LE(input.proofBytes.length),
    input.proofBytes,
    encodeU32LE(input.addressTreeInfoBytes.length),
    input.addressTreeInfoBytes,
    new Uint8Array([input.outputStateTreeIndex]),
    input.orderCommitment,
    input.receiptHash,
    input.orderbookRoot,
  ]);
}

export function serializeUpdateReceiptInstruction(
  input: UpdateReceiptInstructionInput
): Uint8Array {
  ensureLength('orderCommitment', input.orderCommitment, 32);
  ensureLength('receiptHash', input.receiptHash, 32);
  ensureLength('orderbookRoot', input.orderbookRoot, 32);

  return concatBytes([
    encodeU32LE(input.proofBytes.length),
    input.proofBytes,
    encodeU32LE(input.accountMetaBytes.length),
    input.accountMetaBytes,
    input.orderCommitment,
    input.receiptHash,
    input.orderbookRoot,
  ]);
}

export interface CreateReceiptInstructionLightInput {
  proof: ValidityProof | null;
  addressTreeInfo: PackedAddressTreeInfo;
  outputStateTreeIndex: number;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}

export interface UpdateReceiptInstructionLightInput {
  proof: ValidityProof | null;
  accountMeta: CompressedAccountMeta;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}

export function serializeCreateReceiptInstructionFromLight(
  input: CreateReceiptInstructionLightInput
): Uint8Array {
  return serializeCreateReceiptInstruction({
    proofBytes: serializeValidityProof(input.proof),
    addressTreeInfoBytes: serializePackedAddressTreeInfo(input.addressTreeInfo),
    outputStateTreeIndex: input.outputStateTreeIndex,
    orderCommitment: input.orderCommitment,
    receiptHash: input.receiptHash,
    orderbookRoot: input.orderbookRoot,
  });
}

export function serializeUpdateReceiptInstructionFromLight(
  input: UpdateReceiptInstructionLightInput
): Uint8Array {
  return serializeUpdateReceiptInstruction({
    proofBytes: serializeValidityProof(input.proof),
    accountMetaBytes: serializeCompressedAccountMeta(input.accountMeta),
    orderCommitment: input.orderCommitment,
    receiptHash: input.receiptHash,
    orderbookRoot: input.orderbookRoot,
  });
}

export interface LightCreateReceiptContext {
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

export interface LightUpdateReceiptContext {
  instructionData: Uint8Array;
  remainingAccounts: AccountMeta[];
  proof: ValidityProof | null;
  accountMeta: CompressedAccountMeta;
  outputStateTreeIndex: number;
}

export function toReceiptAccountSpecs(accounts: AccountMeta[]): ReceiptAccountSpec[] {
  return accounts.map((account) => ({
    pubkey: account.pubkey.toBase58(),
    isSigner: account.isSigner,
    isWritable: account.isWritable
  }));
}

export async function buildLightCreateReceiptContext(input: {
  rpc: Rpc;
  receiptProgramId: PublicKey;
  addressTreeInfo: TreeInfo;
  outputStateTreeInfo: TreeInfo;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}): Promise<LightCreateReceiptContext> {
  const addressSeed = deriveAddressSeed(
    [RECEIPT_ADDRESS_SEED, input.orderCommitment],
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

  if (!validity.rootIndices.length) {
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

  const instructionData = serializeCreateReceiptInstructionFromLight({
    proof: validity.compressedProof,
    addressTreeInfo,
    outputStateTreeIndex,
    orderCommitment: input.orderCommitment,
    receiptHash: input.receiptHash,
    orderbookRoot: input.orderbookRoot
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

export async function buildLightUpdateReceiptContext(input: {
  rpc: Rpc;
  receiptProgramId: PublicKey;
  compressedAccount: CompressedAccountWithMerkleContext;
  outputStateTreeInfo: TreeInfo;
  orderCommitment: Uint8Array;
  receiptHash: Uint8Array;
  orderbookRoot: Uint8Array;
}): Promise<LightUpdateReceiptContext> {
  if (!input.compressedAccount.address) {
    throw new Error('Compressed account address is required to update a receipt');
  }

  const validity = await input.rpc.getValidityProofV0(
    [
      {
        hash: input.compressedAccount.hash,
        tree: input.compressedAccount.treeInfo.tree,
        queue: input.compressedAccount.treeInfo.queue
      }
    ],
    []
  );

  if (!validity.rootIndices.length) {
    throw new Error('No root indices returned from Light RPC for account proof');
  }

  const packedAccounts = PackedAccounts.newWithSystemAccounts(
    SystemAccountMetaConfig.new(input.receiptProgramId)
  );

  const merkleTreePubkeyIndex = packedAccounts.insertOrGet(
    input.compressedAccount.treeInfo.tree
  );
  const queuePubkeyIndex = packedAccounts.insertOrGet(
    input.compressedAccount.treeInfo.queue
  );
  const outputStateTreeIndex = packedAccounts.insertOrGet(
    getOutputStateTreeAccount(input.outputStateTreeInfo)
  );

  const accountMeta: CompressedAccountMeta = {
    treeInfo: {
      rootIndex: validity.rootIndices[0],
      proveByIndex: input.compressedAccount.proveByIndex,
      merkleTreePubkeyIndex,
      queuePubkeyIndex,
      leafIndex: input.compressedAccount.leafIndex
    },
    address: input.compressedAccount.address,
    outputStateTreeIndex
  };

  const instructionData = serializeUpdateReceiptInstructionFromLight({
    proof: validity.compressedProof,
    accountMeta,
    orderCommitment: input.orderCommitment,
    receiptHash: input.receiptHash,
    orderbookRoot: input.orderbookRoot
  });

  return {
    instructionData,
    remainingAccounts: packedAccounts.toAccountMetas().remainingAccounts,
    proof: validity.compressedProof,
    accountMeta,
    outputStateTreeIndex
  };
}

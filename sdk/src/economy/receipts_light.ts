import { array, option, struct, u16, u8 } from '@coral-xyz/borsh';
import type {
  PackedAddressTreeInfo,
  Rpc,
  TreeInfo,
  ValidityProof,
} from '@lightprotocol/stateless.js';
import {
  bn,
  deriveAddressV2,
  deriveAddressSeedV2,
  PackedAccounts,
  SystemAccountMetaConfig,
  TreeType,
} from '@lightprotocol/stateless.js';
import type { AccountMeta } from '@solana/web3.js';
import { PublicKey } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import type { SupportedToken } from './wallet';

const RECEIPT_ADDRESS_SEED = new TextEncoder().encode('receipt');
const LIGHT_SYSTEM_PROGRAM_ID = new PublicKey('SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7');

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
  return treeInfo.tree;
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
  console.log("[DEBUGGEANDO PARCERO]",seeds); 
  let addressTreeInfo = input.addressTreeInfo;
  const addressSeed = deriveAddressSeedV2(
    seeds,
  );
  console.log(`[Client] Address Seed: [${Array.from(addressSeed).join(', ')}]`);
  const derivedAddress = deriveAddressV2(addressSeed, addressTreeInfo.tree,input.receiptProgramId);
  console.log(`[Client] Derived Address: ${derivedAddress.toBase58()}`);
  console.log(`[Client] Seeds Components: receipt, ${Buffer.from(input.vendor).toString('hex').slice(0,8)}..., ${Buffer.from(input.memoHash).toString('hex').slice(0,8)}...`);
  console.log("INFO->" ,addressTreeInfo);
  console.log("INFO[tree]->" ,addressTreeInfo.tree);
  console.log("INFO->" ,addressTreeInfo.queue);
  const validity = await input.rpc.getValidityProofV0([], [
    {
      tree: addressTreeInfo.tree,
      queue: addressTreeInfo.queue,
      address: bn(addressSeed)
    }
  ]);
  const proofTreeInfo = validity.treeInfos?.[0];
  if (proofTreeInfo && !proofTreeInfo.queue.equals(addressTreeInfo.queue)) {
    console.log('[DEBUG_RECEIPT_CONTEXT] Overriding queue from proof treeInfo to match validity proof.');
    addressTreeInfo = { ...addressTreeInfo, queue: proofTreeInfo.queue };
  }
  const overridePath = process.env.RECEIPT_VALIDITY_OVERRIDE_PATH;
  if (overridePath) {
    try {
      const override = JSON.parse(readFileSync(overridePath, 'utf-8'));
      if (override.proof) {
        validity.compressedProof = {
          a: Uint8Array.from(override.proof.a),
          b: Uint8Array.from(override.proof.b),
          c: Uint8Array.from(override.proof.c),
        };
        validity.rootIndices = override.rootIndices;
      }
      console.log('[DEBUG_RECEIPT_CONTEXT] Using overridden proof data from', overridePath);
    } catch (err) {
      console.warn('[DEBUG_RECEIPT_CONTEXT] Failed to load override proof', err);
    }
  }
  console.log("VALIDITY::::->",validity);
  const dumpPath = process.env.RECEIPT_VALIDITY_DUMP_PATH;
  if (dumpPath) {
    try {
      mkdirSync(path.dirname(dumpPath), { recursive: true });
      const serializedProof = validity.compressedProof
        ? {
            a: Array.from(validity.compressedProof.a),
            b: Array.from(validity.compressedProof.b),
            c: Array.from(validity.compressedProof.c),
          }
        : null;
      const dump = {
        timestamp: new Date().toISOString(),
        tree: addressTreeInfo.tree.toBase58(),
        queue: addressTreeInfo.queue.toBase58(),
        addressSeed: Array.from(addressSeed),
        derivedAddress: derivedAddress.toBase58(),
        proof: serializedProof,
        rootIndices: validity.rootIndices,
        leaves: validity.leaves?.map(leaf => leaf.toString(16)),
        treeInfos: validity.treeInfos.map(info => ({
          tree: info.tree.toBase58(),
          queue: info.queue.toBase58(),
          treeType: info.treeType,
        })),
      };
      writeFileSync(dumpPath, JSON.stringify(dump, null, 2));
      console.log(`[DEBUG_RECEIPT_CONTEXT] Saved validity dump to ${dumpPath}`);
    } catch (err) {
      console.warn('[DEBUG_RECEIPT_CONTEXT] Failed to persist validity dump', err);
    }
  }
  if (validity.rootIndices.length === 0) {
    validity.rootIndices = [0];
  }

  if (!validity.rootIndices.length || validity.rootIndices[0] === undefined) {
    throw new Error('No root indices returned from Light RPC for address proof');
  }

  const packedAccounts = PackedAccounts.newWithSystemAccountsV2(
    SystemAccountMetaConfig.new(input.receiptProgramId)
  );
  const [lightCpiSigner] = PublicKey.findProgramAddressSync(
    [Buffer.from('light_cpi')],
    input.receiptProgramId
  );
  packedAccounts.insertOrGet(lightCpiSigner);

  const addressMerkleTreePubkeyIndex = packedAccounts.insertOrGet(
    addressTreeInfo.tree
  );
  const addressQueuePubkeyIndex = packedAccounts.insertOrGet(addressTreeInfo.queue);
  const outputStateTreeAccount = getOutputStateTreeAccount(input.outputStateTreeInfo);
  const outputStateTreeIndex = packedAccounts.insertOrGet(outputStateTreeAccount);

  const accountMetas = packedAccounts.toAccountMetas();

  const indexByKey = new Map<string, number>();
  accountMetas.remainingAccounts.forEach((meta, idx) => {
    indexByKey.set(meta.pubkey.toBase58(), idx);
  });

  const realTreeIndex = indexByKey.get(addressTreeInfo.tree.toBase58());
  const realQueueIndex = indexByKey.get(addressTreeInfo.queue.toBase58());
  const realOutputIndex = indexByKey.get(outputStateTreeAccount.toBase58());

  if (
    realTreeIndex === undefined ||
    realQueueIndex === undefined ||
    realOutputIndex === undefined
  ) {
    throw new Error('Packed accounts missing required tree/queue/output entries');
  }

  if (realOutputIndex === realQueueIndex) {
    throw new Error('Output state tree index is colliding with the address queue');
  }

  const packedAddressTreeInfo: PackedAddressTreeInfo = {
    addressMerkleTreePubkeyIndex: realTreeIndex,
    addressQueuePubkeyIndex: realQueueIndex,
    rootIndex: validity.rootIndices[0]
  };
  
  const finalOutputIndex = realOutputIndex;

  const receiptContext: LightRecordReceiptContext = {
    instructionData: serializeRecordReceiptInstructionFromLight({
      proof: validity.compressedProof,
      addressTreeInfo: packedAddressTreeInfo,
      outputStateTreeIndex: finalOutputIndex,
      vendor: input.vendor,
      amount: input.amount,
      memoHash: input.memoHash
    }),
    remainingAccounts: accountMetas.remainingAccounts,
    derivedAddress,
    proof: validity.compressedProof,
    addressTreeInfo: packedAddressTreeInfo,
    outputStateTreeIndex: finalOutputIndex
  };

  const outputAccountMeta = accountMetas.remainingAccounts[realOutputIndex];
  const queueAccountMeta = accountMetas.remainingAccounts[realQueueIndex];

  if (process.env.DEBUG_RECEIPT_CONTEXT === '1') {
    console.log('[DEBUG_RECEIPT_CONTEXT] PACKED ACCOUNTS MODE');
    console.log('[DEBUG_RECEIPT_CONTEXT] Tree Index (sent):', packedAddressTreeInfo.addressMerkleTreePubkeyIndex);
    console.log('[DEBUG_RECEIPT_CONTEXT] Queue Index (sent):', packedAddressTreeInfo.addressQueuePubkeyIndex);
    console.log('[DEBUG_RECEIPT_CONTEXT] Output Index (sent):', receiptContext.outputStateTreeIndex);
    accountMetas.remainingAccounts.forEach((a, i) => console.log(`[DEBUG_RECEIPT_CONTEXT] Rem[${i}]: ${a.pubkey.toBase58()}`));
    console.log('[DEBUG_RECEIPT_CONTEXT] Output Account Meta:', {
      index: realOutputIndex,
      pubkey: outputAccountMeta.pubkey.toBase58(),
      isSigner: outputAccountMeta.isSigner,
      isWritable: outputAccountMeta.isWritable,
    });
    console.log('[DEBUG_RECEIPT_CONTEXT] Queue Account Meta:', {
      index: realQueueIndex,
      pubkey: queueAccountMeta.pubkey.toBase58(),
      isSigner: queueAccountMeta.isSigner,
      isWritable: queueAccountMeta.isWritable,
    });
    try {
      const outputAccountInfo = await input.rpc.getAccountInfoInterface(
        outputAccountMeta.pubkey,
        LIGHT_SYSTEM_PROGRAM_ID,
        'confirmed',
        input.outputStateTreeInfo,
      );
      console.log('[DEBUG_RECEIPT_CONTEXT] Output Account Info:', outputAccountInfo?.accountInfo && {
        owner: outputAccountInfo.accountInfo.owner.toBase58(),
        lamports: outputAccountInfo.accountInfo.lamports,
        dataLength: outputAccountInfo.accountInfo.data.length,
        isCold: outputAccountInfo.isCold,
      });
    } catch (err) {
      console.warn('[DEBUG_RECEIPT_CONTEXT] Failed to fetch output account info', err);
    }
    try {
      const queueAccountInfo = await input.rpc.getAccountInfoInterface(
        queueAccountMeta.pubkey,
        LIGHT_SYSTEM_PROGRAM_ID,
        'confirmed',
        addressTreeInfo,
      );
      console.log('[DEBUG_RECEIPT_CONTEXT] Queue Account Info:', queueAccountInfo?.accountInfo && {
        owner: queueAccountInfo.accountInfo.owner.toBase58(),
        lamports: queueAccountInfo.accountInfo.lamports,
        dataLength: queueAccountInfo.accountInfo.data.length,
        isCold: queueAccountInfo.isCold,
      });
    } catch (err) {
      console.warn('[DEBUG_RECEIPT_CONTEXT] Failed to fetch queue account info', err);
    }
  }

  return receiptContext;
}

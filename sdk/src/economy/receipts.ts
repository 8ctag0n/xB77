import { SupportedToken } from './wallet';

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

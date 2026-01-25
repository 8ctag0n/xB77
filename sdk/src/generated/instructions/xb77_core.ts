import { PublicKey, TransactionInstruction, AccountMeta } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { WincodeSerializer } from '../../utils/wincode';

export interface InitCorePayload {
  admin: Uint8Array | number[];
  gatewayProgram: Uint8Array | number[];
  receiptsProgram: Uint8Array | number[];
  treasuryMint: Uint8Array | number[];
}

export function serializeInitCorePayload(serializer: WincodeSerializer, value: InitCorePayload) {
  serializer.writeFixedArray(Buffer.from(value.admin), 32);
  serializer.writeFixedArray(Buffer.from(value.gatewayProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.receiptsProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.treasuryMint), 32);
}

export interface RegisterAgentPayload {
  agentId: Uint8Array | number[];
  initialLimit: bigint | number;
}

export function serializeRegisterAgentPayload(serializer: WincodeSerializer, value: RegisterAgentPayload) {
  serializer.writeFixedArray(Buffer.from(value.agentId), 32);
  serializer.writeU64(value.initialLimit);
}

export interface VerifyAndCreditPayload {
  agentId: Uint8Array | number[];
  proofRef: Uint8Array | number[];
  creditAmount: bigint | number;
}

export function serializeVerifyAndCreditPayload(serializer: WincodeSerializer, value: VerifyAndCreditPayload) {
  serializer.writeFixedArray(Buffer.from(value.agentId), 32);
  serializer.writeFixedArray(Buffer.from(value.proofRef), 32);
  serializer.writeU64(value.creditAmount);
}

export interface RequestPaymentPayload {
  requestId: bigint | number;
  amount: bigint | number;
  vendor: Uint8Array | number[];
  memoHash: Uint8Array | number[];
  proof: Uint8Array | Buffer;
  addressTreeInfo: Uint8Array | Buffer;
  outputStateTreeIndex: number;
}

export function serializeRequestPaymentPayload(serializer: WincodeSerializer, value: RequestPaymentPayload) {
  serializer.writeU64(value.requestId);
  serializer.writeU64(value.amount);
  serializer.writeFixedArray(Buffer.from(value.vendor), 32);
  serializer.writeFixedArray(Buffer.from(value.memoHash), 32);
  serializer.writeVec(Buffer.from(value.proof));
  serializer.writeVec(Buffer.from(value.addressTreeInfo));
  serializer.writeU8(value.outputStateTreeIndex);
}

export const PROGRAM_ID = new PublicKey('11111111111111111111111111111111');

export function createInitCoreInstruction(payload: InitCorePayload, accounts: { configAccount: PublicKey, adminSigner: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(0);
  serializeInitCorePayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.configAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.adminSigner, isSigner: true, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createRegisterAgentInstruction(payload: RegisterAgentPayload, accounts: { configAccount: PublicKey, creditLineAccount: PublicKey, adminSigner: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(1);
  serializeRegisterAgentPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.configAccount, isSigner: false, isWritable: false },
    { pubkey: accounts.creditLineAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.adminSigner, isSigner: true, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createVerifyAndCreditInstruction(payload: VerifyAndCreditPayload, accounts: { configAccount: PublicKey, creditLineAccount: PublicKey, gatewaySigner: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(2);
  serializeVerifyAndCreditPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.configAccount, isSigner: false, isWritable: false },
    { pubkey: accounts.creditLineAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.gatewaySigner, isSigner: true, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createRequestPaymentInstruction(payload: RequestPaymentPayload, accounts: { configAccount: PublicKey, creditLineAccount: PublicKey, agentSigner: PublicKey, receiptsProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(3);
  serializeRequestPaymentPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.configAccount, isSigner: false, isWritable: false },
    { pubkey: accounts.creditLineAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.agentSigner, isSigner: true, isWritable: true },
    { pubkey: accounts.receiptsProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}


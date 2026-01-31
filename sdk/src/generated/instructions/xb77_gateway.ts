import { PublicKey, TransactionInstruction, AccountMeta } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { WincodeSerializer } from '../../utils/wincode';

export interface InitGatewayPayload {
  admin: Uint8Array | number[];
  merkleRoot: Uint8Array | number[];
  zkVerifier: Uint8Array | number[];
  auditor: Uint8Array | number[];
  creditRoot: Uint8Array | number[];
  orderbookRoot: Uint8Array | number[];
  mxeProgramId: Uint8Array | number[];
  receiptsProgramId: Uint8Array | number[];
  lightSystemProgram: Uint8Array | number[];
  lightAccountCompressionProgram: Uint8Array | number[];
  lightNoopProgram: Uint8Array | number[];
}

export function serializeInitGatewayPayload(serializer: WincodeSerializer, value: InitGatewayPayload) {
  serializer.writeFixedArray(Buffer.from(value.admin), 32);
  serializer.writeFixedArray(Buffer.from(value.merkleRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.zkVerifier), 32);
  serializer.writeFixedArray(Buffer.from(value.auditor), 32);
  serializer.writeFixedArray(Buffer.from(value.creditRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.orderbookRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.mxeProgramId), 32);
  serializer.writeFixedArray(Buffer.from(value.receiptsProgramId), 32);
  serializer.writeFixedArray(Buffer.from(value.lightSystemProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.lightAccountCompressionProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.lightNoopProgram), 32);
}

export interface UpdateGatewayPayload {
  merkleRoot: Uint8Array | number[];
  auditor: Uint8Array | number[];
  creditRoot: Uint8Array | number[];
  orderbookRoot: Uint8Array | number[];
  mxeProgramId: Uint8Array | number[];
  receiptsProgramId: Uint8Array | number[];
  lightSystemProgram: Uint8Array | number[];
  lightAccountCompressionProgram: Uint8Array | number[];
  lightNoopProgram: Uint8Array | number[];
}

export function serializeUpdateGatewayPayload(serializer: WincodeSerializer, value: UpdateGatewayPayload) {
  serializer.writeFixedArray(Buffer.from(value.merkleRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.auditor), 32);
  serializer.writeFixedArray(Buffer.from(value.creditRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.orderbookRoot), 32);
  serializer.writeFixedArray(Buffer.from(value.mxeProgramId), 32);
  serializer.writeFixedArray(Buffer.from(value.receiptsProgramId), 32);
  serializer.writeFixedArray(Buffer.from(value.lightSystemProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.lightAccountCompressionProgram), 32);
  serializer.writeFixedArray(Buffer.from(value.lightNoopProgram), 32);
}

export interface ProofPayload {
  root: Uint8Array | number[];
  merkleIndex: number;
  proof: Uint8Array | Buffer;
  publicWitness: Uint8Array | Buffer;
}

export function serializeProofPayload(serializer: WincodeSerializer, value: ProofPayload) {
  serializer.writeFixedArray(Buffer.from(value.root), 32);
  serializer.writeU32(value.merkleIndex);
  serializer.writeVec(Buffer.from(value.proof));
  serializer.writeVec(Buffer.from(value.publicWitness));
}

export interface SubmitPrivateOrderPayload {
  orderId: bigint | number;
  amount: bigint | number;
  token: Uint8Array | number[];
  recipient: Uint8Array | number[];
  nullifier: Uint8Array | number[];
}

export function serializeSubmitPrivateOrderPayload(serializer: WincodeSerializer, value: SubmitPrivateOrderPayload) {
  serializer.writeU64(value.orderId);
  serializer.writeU64(value.amount);
  serializer.writeFixedArray(Buffer.from(value.token), 32);
  serializer.writeFixedArray(Buffer.from(value.recipient), 32);
  serializer.writeFixedArray(Buffer.from(value.nullifier), 32);
}

export interface ConfidentialTransferPayload {
  instructionData: Uint8Array | Buffer;
}

export function serializeConfidentialTransferPayload(serializer: WincodeSerializer, value: ConfidentialTransferPayload) {
  serializer.writeVec(Buffer.from(value.instructionData));
}

export interface ReceiptPayload {
  receiptInstructionData: Uint8Array | Buffer;
}

export function serializeReceiptPayload(serializer: WincodeSerializer, value: ReceiptPayload) {
  serializer.writeVec(Buffer.from(value.receiptInstructionData));
}

export interface ResolvePrivateOrderPayload {
  orderCommitment: Uint8Array | number[];
  receiptLeafHash: Uint8Array | number[];
  newOrderbookRoot: Uint8Array | number[];
  receiptInstructionData: Uint8Array | Buffer;
}

export function serializeResolvePrivateOrderPayload(serializer: WincodeSerializer, value: ResolvePrivateOrderPayload) {
  serializer.writeFixedArray(Buffer.from(value.orderCommitment), 32);
  serializer.writeFixedArray(Buffer.from(value.receiptLeafHash), 32);
  serializer.writeFixedArray(Buffer.from(value.newOrderbookRoot), 32);
  serializer.writeVec(Buffer.from(value.receiptInstructionData));
}

export interface AuditRevealPayload {
  orderCommitment: Uint8Array | number[];
  auditHash: Uint8Array | number[];
}

export function serializeAuditRevealPayload(serializer: WincodeSerializer, value: AuditRevealPayload) {
  serializer.writeFixedArray(Buffer.from(value.orderCommitment), 32);
  serializer.writeFixedArray(Buffer.from(value.auditHash), 32);
}

export const PROGRAM_ID = new PublicKey('4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC');

export function createInitGatewayInstruction(payload: InitGatewayPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(0);
  serializeInitGatewayPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createUpdateGatewayInstruction(payload: UpdateGatewayPayload, accounts: { admin: PublicKey, gatewayState: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(1);
  serializeUpdateGatewayPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.admin, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: true },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createVerifyBadgeInstruction(payload: ProofPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, verifierProgram: PublicKey, swProofPda: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(2);
  serializeProofPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: false },
    { pubkey: accounts.verifierProgram, isSigner: false, isWritable: false },
    { pubkey: accounts.swProofPda, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createSubmitPrivateOrderInstruction(payload: SubmitPrivateOrderPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, nullifierAccount: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(3);
  serializeSubmitPrivateOrderPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: false },
    { pubkey: accounts.nullifierAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createExecuteConfidentialTransferInstruction(payload: ConfidentialTransferPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, mxeProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(4);
  serializeConfidentialTransferPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: false },
    { pubkey: accounts.mxeProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createRecordReceiptInstruction(payload: ReceiptPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, receiptProgram: PublicKey, agentAccount: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(5);
  serializeReceiptPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: false },
    { pubkey: accounts.receiptProgram, isSigner: false, isWritable: false },
    { pubkey: accounts.agentAccount, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createResolvePrivateOrderInstruction(payload: ResolvePrivateOrderPayload, accounts: { payer: PublicKey, gatewayState: PublicKey, instructionsSysvar: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(6);
  serializeResolvePrivateOrderPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: true },
    { pubkey: accounts.instructionsSysvar, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createAuditRevealInstruction(payload: AuditRevealPayload, accounts: { auditor: PublicKey, gatewayState: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(7);
  serializeAuditRevealPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.auditor, isSigner: true, isWritable: true },
    { pubkey: accounts.gatewayState, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}


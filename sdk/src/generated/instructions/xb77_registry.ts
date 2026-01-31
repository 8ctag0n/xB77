import { PublicKey, TransactionInstruction, AccountMeta } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { WincodeSerializer } from '../../utils/wincode';

export interface InitMerchantPayload {
  merchantId: Uint8Array | Buffer;
  supportedMethods: bigint | number;
}

export function serializeInitMerchantPayload(serializer: WincodeSerializer, value: InitMerchantPayload) {
  serializer.writeVec(Buffer.from(value.merchantId));
  serializer.writeU64(value.supportedMethods);
}

export interface UpdateMerchantPayload {
  merchantId: Uint8Array | Buffer;
  supportedMethods: bigint | number | null;
}

export function serializeUpdateMerchantPayload(serializer: WincodeSerializer, value: UpdateMerchantPayload) {
  serializer.writeVec(Buffer.from(value.merchantId));
  serializer.writeOption(value.supportedMethods, (v) => { serializer.writeU64(v); });
}

export interface AddCatalogPayload {
  merchantId: Uint8Array | Buffer;
  catalogId: bigint | number;
  category: number;
  catalogUrl: Uint8Array | Buffer;
  metadataHash: Uint8Array | number[] | null;
}

export function serializeAddCatalogPayload(serializer: WincodeSerializer, value: AddCatalogPayload) {
  serializer.writeVec(Buffer.from(value.merchantId));
  serializer.writeU64(value.catalogId);
  serializer.writeU8(value.category);
  serializer.writeVec(Buffer.from(value.catalogUrl));
  serializer.writeOption(value.metadataHash, (v) => { serializer.writeFixedArray(Buffer.from(v), 32); });
}

export interface UpdateCatalogPayload {
  merchantId: Uint8Array | Buffer;
  catalogId: bigint | number;
  category: number | null;
  catalogUrl: Uint8Array | Buffer | null;
  metadataHash: Uint8Array | number[] | null;
  active: boolean | null;
}

export function serializeUpdateCatalogPayload(serializer: WincodeSerializer, value: UpdateCatalogPayload) {
  serializer.writeVec(Buffer.from(value.merchantId));
  serializer.writeU64(value.catalogId);
  serializer.writeOption(value.category, (v) => { serializer.writeU8(v); });
  serializer.writeOption(value.catalogUrl, (v) => { serializer.writeVec(Buffer.from(v)); });
  serializer.writeOption(value.metadataHash, (v) => { serializer.writeFixedArray(Buffer.from(v), 32); });
  serializer.writeOption(value.active, (v) => { serializer.writeBool(v); });
}

export interface DeactivateCatalogPayload {
  merchantId: Uint8Array | Buffer;
  catalogId: bigint | number;
}

export function serializeDeactivateCatalogPayload(serializer: WincodeSerializer, value: DeactivateCatalogPayload) {
  serializer.writeVec(Buffer.from(value.merchantId));
  serializer.writeU64(value.catalogId);
}

export const PROGRAM_ID = new PublicKey('11111111111111111111111111111111');

export function createInitMerchantInstruction(payload: InitMerchantPayload, accounts: { payer: PublicKey, merchantAccount: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(0);
  serializeInitMerchantPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.merchantAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createUpdateMerchantInstruction(payload: UpdateMerchantPayload, accounts: { payer: PublicKey, merchantAccount: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(1);
  serializeUpdateMerchantPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.merchantAccount, isSigner: false, isWritable: true },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createAddCatalogInstruction(payload: AddCatalogPayload, accounts: { payer: PublicKey, merchantAccount: PublicKey, catalogAccount: PublicKey, systemProgram: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(2);
  serializeAddCatalogPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.merchantAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.catalogAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.systemProgram, isSigner: false, isWritable: false },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createUpdateCatalogInstruction(payload: UpdateCatalogPayload, accounts: { payer: PublicKey, merchantAccount: PublicKey, catalogAccount: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(3);
  serializeUpdateCatalogPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.merchantAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.catalogAccount, isSigner: false, isWritable: true },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}

export function createDeactivateCatalogInstruction(payload: DeactivateCatalogPayload, accounts: { payer: PublicKey, merchantAccount: PublicKey, catalogAccount: PublicKey }, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
  const serializer = new WincodeSerializer();
  serializer.writeU32(4);
  serializeDeactivateCatalogPayload(serializer, payload);

  const keys: AccountMeta[] = [
    { pubkey: accounts.payer, isSigner: true, isWritable: true },
    { pubkey: accounts.merchantAccount, isSigner: false, isWritable: true },
    { pubkey: accounts.catalogAccount, isSigner: false, isWritable: true },
  ];

  return new TransactionInstruction({
    keys,
    programId,
    data: serializer.data,
  });
}


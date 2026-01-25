import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import { createInitGatewayInstruction } from '../../sdk/src/generated/instructions/xb77_gateway';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const ROOT_DIR = path.resolve(__dirname, '../..');
const KEYPAIRS_DIR = path.join(ROOT_DIR, '.localnet', 'keypairs');
const PROGRAM_IDS_ENV = path.join(ROOT_DIR, '.localnet', 'program_ids.env');
const VERIFIER_ID_PATH = path.join(ROOT_DIR, '.localnet', 'verifier_program_id.txt');
const BADGE_META_PATH = path.join(ROOT_DIR, 'sdk', 'target', 'agent_badge.meta.json');

export const LOCALNET_URL = 'http://127.0.0.1:8899';

export type ProgramIdMap = {
  core: PublicKey;
  gateway: PublicKey;
  registry: PublicKey;
  receipts: PublicKey;
  testUtils: PublicKey;
};

export type BadgeMeta = {
  merkleRootHex: string;
  merkleIndex: number;
  orderId: string;
  nullifierHex: string;
};

export function parseProgramIds(): ProgramIdMap {
  const env: Record<string, string> = {};
  if (existsSync(PROGRAM_IDS_ENV)) {
    const data = readFileSync(PROGRAM_IDS_ENV, 'utf8');
    for (const line of data.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const [key, value] = trimmed.split('=');
      if (key && value) env[key.trim()] = value.trim();
    }
  }

  const loadFromKeypair = (name: string) => {
    const kpPath = path.join(KEYPAIRS_DIR, `${name}.json`);
    if (!existsSync(kpPath)) return undefined;
    const secret = JSON.parse(readFileSync(kpPath, 'utf8')) as number[];
    return Keypair.fromSecretKey(new Uint8Array(secret)).publicKey;
  };

  const core = env.xb77_core_ID ? new PublicKey(env.xb77_core_ID) : loadFromKeypair('xb77_core');
  const gateway = env.xb77_gateway_ID
    ? new PublicKey(env.xb77_gateway_ID)
    : loadFromKeypair('xb77_gateway');
  const registry = env.xb77_registry_ID
    ? new PublicKey(env.xb77_registry_ID)
    : loadFromKeypair('xb77_registry');
  const receipts = env.xb77_receipts_ID
    ? new PublicKey(env.xb77_receipts_ID)
    : loadFromKeypair('xb77_receipts');
  const testUtils = env.xb77_test_utils_ID
    ? new PublicKey(env.xb77_test_utils_ID)
    : loadFromKeypair('xb77_test_utils');

  if (!core || !gateway || !registry || !receipts || !testUtils) {
    throw new Error('Missing program IDs. Ensure .localnet/program_ids.env and keypairs are present.');
  }

  return { core, gateway, registry, receipts, testUtils };
}

export function loadKeypair(name: string): Keypair {
  const kpPath = path.join(KEYPAIRS_DIR, `${name}.json`);
  if (!existsSync(kpPath)) {
    throw new Error(`Keypair not found: ${kpPath}`);
  }
  const secret = JSON.parse(readFileSync(kpPath, 'utf8')) as number[];
  return Keypair.fromSecretKey(new Uint8Array(secret));
}

export function loadOrCreatePayer(): Keypair {
  const payerPath = path.join(KEYPAIRS_DIR, 'test_payer.json');
  if (existsSync(payerPath)) {
    const secret = JSON.parse(readFileSync(payerPath, 'utf8')) as number[];
    return Keypair.fromSecretKey(new Uint8Array(secret));
  }
  const payer = Keypair.generate();
  writeFileSync(payerPath, JSON.stringify(Array.from(payer.secretKey)));
  return payer;
}

export async function ensureAirdrop(connection: Connection, payer: Keypair, minSol = 2) {
  const balance = await connection.getBalance(payer.publicKey);
  if (balance >= minSol * LAMPORTS_PER_SOL) return;
  const sig = await connection.requestAirdrop(payer.publicKey, minSol * LAMPORTS_PER_SOL);
  await connection.confirmTransaction(sig, 'confirmed');
}

export function connection() {
  return new Connection(LOCALNET_URL, 'confirmed');
}

export function parseHex32(value: string, name: string) {
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

export function loadBadgeMeta(): BadgeMeta {
  if (!existsSync(BADGE_META_PATH)) {
    throw new Error('Missing sdk/target/agent_badge.meta.json. Run: make proof-badge');
  }
  const raw = readFileSync(BADGE_META_PATH, 'utf8');
  const meta = JSON.parse(raw) as {
    merkle_root_hex: string;
    merkle_index: string;
    order_id?: string;
    nullifier?: string;
    nullifier_hex?: string;
  };

  return {
    merkleRootHex: meta.merkle_root_hex,
    merkleIndex: Number(meta.merkle_index),
    orderId: meta.order_id ?? '',
    nullifierHex: meta.nullifier_hex ?? (meta.nullifier ? `0x${BigInt(meta.nullifier).toString(16)}` : ''),
  };
}

export async function createAndInitSwProofAccount(params: {
  connection: Connection;
  payer: Keypair;
  testUtilsProgramId: PublicKey;
  nullifier: Uint8Array;
}) {
  const { connection, payer, testUtilsProgramId, nullifier } = params;
  const swProof = Keypair.generate();
  const space = 88;
  const lamports = await connection.getMinimumBalanceForRentExemption(space);

  const createIx = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: swProof.publicKey,
    lamports,
    space,
    programId: SystemProgram.programId,
  });

  const data = Buffer.concat([Buffer.from([1]), Buffer.from(nullifier)]);
  const setIx = new TransactionInstruction({
    programId: testUtilsProgramId,
    keys: [
      { pubkey: payer.publicKey, isSigner: true, isWritable: true },
      { pubkey: swProof.publicKey, isSigner: false, isWritable: true },
    ],
    data,
  });

  const tx = new Transaction().add(createIx, setIx);
  await sendAndConfirmTransaction(connection, tx, [payer, swProof]);

  return swProof;
}

export async function ensureGatewayInitialized(params: {
  connection: Connection;
  payer: Keypair;
  ids: ProgramIdMap;
}) {
  const { connection, payer, ids } = params;
  const verifierProgramId = resolveVerifierProgramId(ids);
  const [gatewayStatePda] = PublicKey.findProgramAddressSync(
    [Buffer.from('gateway_state')],
    ids.gateway
  );

  const gwAccount = await connection.getAccountInfo(gatewayStatePda);
  if (gwAccount) {
    return gatewayStatePda;
  }

  const meta = loadBadgeMeta();
  const merkleRoot = Array.from(parseHex32(meta.merkleRootHex, 'merkleRootHex'));

  const initIx = createInitGatewayInstruction(
    {
      admin: Array.from(payer.publicKey.toBuffer()),
      merkleRoot,
      zkVerifier: Array.from(verifierProgramId.toBuffer()),
      auditor: Array(32).fill(0),
      creditRoot: Array(32).fill(0),
      orderbookRoot: Array(32).fill(0),
      mxeProgramId: Array.from(ids.testUtils.toBuffer()),
      receiptsProgramId: Array.from(ids.testUtils.toBuffer()),
      lightSystemProgram: Array(32).fill(0),
      lightAccountCompressionProgram: Array(32).fill(0),
      lightNoopProgram: Array(32).fill(0),
    },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      systemProgram: SystemProgram.programId,
    },
    ids.gateway
  );

  await sendAndConfirmTransaction(connection, new Transaction().add(initIx), [payer]);
  return gatewayStatePda;
}

export function resolveVerifierProgramId(ids: ProgramIdMap): PublicKey {
  if (process.env.XB77_USE_REAL_VERIFIER === 'true' && existsSync(VERIFIER_ID_PATH)) {
    const verifierId = readFileSync(VERIFIER_ID_PATH, 'utf8').trim();
    if (verifierId) {
      return new PublicKey(verifierId);
    }
  }
  return ids.testUtils;
}

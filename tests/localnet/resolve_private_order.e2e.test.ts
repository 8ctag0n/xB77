import { beforeAll, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  Keypair,
  Transaction,
  sendAndConfirmTransaction,
  SYSVAR_INSTRUCTIONS_PUBKEY,
} from '@solana/web3.js';
import {
  createResolvePrivateOrderInstruction,
  createVerifyBadgeInstruction,
} from '../../sdk/src/generated/instructions/xb77_gateway';
import {
  connection,
  createAndInitSwProofAccount,
  ensureAirdrop,
  ensureGatewayInitialized,
  loadBadgeMeta,
  loadOrCreatePayer,
  parseHex32,
  parseProgramIds,
} from './helpers';

const conn = connection();
const ids = parseProgramIds();
let payer: Keypair;

const ROOT_DIR = path.resolve(__dirname, '../..');
const PROOF_PATH = path.join(ROOT_DIR, 'circuits', 'agent_badge', 'target', 'agent_badge.proof');
const WITNESS_PATH = path.join(ROOT_DIR, 'circuits', 'agent_badge', 'target', 'agent_badge.pw');

beforeAll(async () => {
  payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 3);
});

test('resolve_private_order: requires verify_badge in same transaction', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const meta = loadBadgeMeta();
  const merkleRoot = parseHex32(meta.merkleRootHex, 'merkleRootHex');
  const nullifier = parseHex32(meta.nullifierHex, 'nullifierHex');

  const proof = readFileSync(PROOF_PATH);
  const witness = readFileSync(WITNESS_PATH);

  const swProof = await createAndInitSwProofAccount({
    connection: conn,
    payer,
    testUtilsProgramId: ids.testUtils,
    nullifier,
  });

  const verifyIx = createVerifyBadgeInstruction(
    {
      root: Array.from(merkleRoot),
      merkleIndex: meta.merkleIndex,
      proof: new Uint8Array(proof),
      publicWitness: new Uint8Array(witness),
    },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      verifierProgram: ids.testUtils,
      swProofPda: swProof.publicKey,
    },
    ids.gateway
  );

  const resolveIx = createResolvePrivateOrderInstruction(
    {
      orderCommitment: Array(32).fill(1),
      receiptLeafHash: Array(32).fill(2),
      newOrderbookRoot: Array(32).fill(3),
      receiptInstructionData: new Uint8Array(),
    },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      instructionsSysvar: SYSVAR_INSTRUCTIONS_PUBKEY,
    },
    ids.gateway
  );

  const tx = new Transaction().add(verifyIx, resolveIx);
  await sendAndConfirmTransaction(conn, tx, [payer]);

  const updated = await conn.getAccountInfo(gatewayStatePda);
  expect(updated).not.toBeNull();
});

import { beforeAll, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { Keypair, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import { createVerifyBadgeInstruction } from '../../sdk/src/generated/instructions/xb77_gateway';
import {
  connection,
  createAndInitSwProofAccount,
  ensureAirdrop,
  ensureGatewayInitialized,
  loadBadgeMeta,
  loadOrCreatePayer,
  parseHex32,
  parseProgramIds,
  resolveVerifierProgramId,
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

test('verify_badge: success with verifier + sw binding', async () => {
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

  const verifierProgram = resolveVerifierProgramId(ids);

  const payload = {
    root: Array.from(merkleRoot),
    merkleIndex: meta.merkleIndex,
    proof: new Uint8Array(proof),
    publicWitness: new Uint8Array(witness),
  };

  const verifyIx = createVerifyBadgeInstruction(
    payload,
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      verifierProgram,
      swProofPda: swProof.publicKey,
    },
    ids.gateway
  );

  await sendAndConfirmTransaction(conn, new Transaction().add(verifyIx), [payer]);
});


test('verify_badge: fails with mismatched merkle root', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const meta = loadBadgeMeta();
  const nullifier = parseHex32(meta.nullifierHex, 'nullifierHex');

  const proof = readFileSync(PROOF_PATH);
  const witness = readFileSync(WITNESS_PATH);

  const swProof = await createAndInitSwProofAccount({
    connection: conn,
    payer,
    testUtilsProgramId: ids.testUtils,
    nullifier,
  });

  const verifierProgram = resolveVerifierProgramId(ids);

  const badWitness = Buffer.from(witness);
  const headerOffset = badWitness.length === 108 ? 12 : 0;
  badWitness.fill(9, headerOffset, headerOffset + 32);
  const payload = {
    root: Array.from(parseHex32(meta.merkleRootHex, 'merkleRootHex')),
    merkleIndex: meta.merkleIndex,
    proof: new Uint8Array(proof),
    publicWitness: new Uint8Array(badWitness),
  };

  const verifyIx = createVerifyBadgeInstruction(
    payload,
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      verifierProgram,
      swProofPda: swProof.publicKey,
    },
    ids.gateway
  );

  let failed = false;
  try {
    await sendAndConfirmTransaction(conn, new Transaction().add(verifyIx), [payer]);
  } catch {
    failed = true;
  }

  expect(failed).toBe(true);
});

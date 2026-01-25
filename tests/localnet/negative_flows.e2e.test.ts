import { beforeAll, expect, test } from 'bun:test';
import {
  Keypair,
  Transaction,
  sendAndConfirmTransaction,
  SYSVAR_INSTRUCTIONS_PUBKEY,
} from '@solana/web3.js';
import {
  createExecuteConfidentialTransferInstruction,
  createRecordReceiptInstruction,
  createResolvePrivateOrderInstruction,
} from '../../sdk/src/generated/instructions/xb77_gateway';
import {
  connection,
  ensureAirdrop,
  ensureGatewayInitialized,
  loadOrCreatePayer,
  parseProgramIds,
} from './helpers';

const conn = connection();
const ids = parseProgramIds();
let payer: Keypair;

beforeAll(async () => {
  payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 3);
});

test('resolve_private_order: fails without verify_badge in same tx', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

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

  let failed = false;
  try {
    await sendAndConfirmTransaction(conn, new Transaction().add(resolveIx), [payer]);
  } catch {
    failed = true;
  }

  expect(failed).toBe(true);
});

test('execute_confidential_transfer: fails with empty instruction data', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const ix = createExecuteConfidentialTransferInstruction(
    { instructionData: new Uint8Array() },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      mxeProgram: ids.testUtils,
    },
    ids.gateway
  );

  let failed = false;
  try {
    await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  } catch {
    failed = true;
  }

  expect(failed).toBe(true);
});

test('record_receipt: fails with empty instruction data', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const ix = createRecordReceiptInstruction(
    { receiptInstructionData: new Uint8Array() },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      receiptProgram: ids.testUtils,
      agentAccount: payer.publicKey,
    },
    ids.gateway
  );

  let failed = false;
  try {
    await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  } catch {
    failed = true;
  }

  expect(failed).toBe(true);
});

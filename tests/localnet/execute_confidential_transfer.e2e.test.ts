import { beforeAll, expect, test } from 'bun:test';
import { Keypair, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import { createExecuteConfidentialTransferInstruction } from '../../sdk/src/generated/instructions/xb77_gateway';
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

test('execute_confidential_transfer: CPI passthrough', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const payload = {
    instructionData: new Uint8Array([1, 2, 3, 4]),
  };

  const ix = createExecuteConfidentialTransferInstruction(
    payload,
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      mxeProgram: ids.testUtils,
    },
    ids.gateway
  );

  await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  const account = await conn.getAccountInfo(gatewayStatePda);
  expect(account).not.toBeNull();
});

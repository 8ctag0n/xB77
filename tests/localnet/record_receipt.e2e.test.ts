import { beforeAll, expect, test } from 'bun:test';
import { Keypair, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import { createRecordReceiptInstruction } from '../../sdk/src/generated/instructions/xb77_gateway';
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

test('record_receipt: CPI passthrough', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const agent = Keypair.generate();
  const payload = {
    receiptInstructionData: new Uint8Array([9, 9, 9, 9]),
  };

  const ix = createRecordReceiptInstruction(
    payload,
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      receiptProgram: ids.testUtils,
      agentAccount: agent.publicKey,
    },
    ids.gateway
  );

  await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
  const account = await conn.getAccountInfo(gatewayStatePda);
  expect(account).not.toBeNull();
});

import { beforeAll, expect, test } from 'bun:test';
import { Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import { createSubmitPrivateOrderInstruction } from '../../sdk/src/generated/instructions/xb77_gateway';
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

test('gateway: init + submit private order', async () => {
  const gatewayStatePda = await ensureGatewayInitialized({
    connection: conn,
    payer,
    ids,
  });

  const nullifier = Array.from(Buffer.alloc(32).map(() => Math.floor(Math.random() * 255)));
  const [nullifierPda] = PublicKey.findProgramAddressSync(
    [Buffer.from('nullifier'), Buffer.from(nullifier)],
    ids.gateway
  );

  const submitIx = createSubmitPrivateOrderInstruction(
    {
      orderId: BigInt(123),
      amount: BigInt(100),
      token: Array(32).fill(1),
      recipient: Array(32).fill(2),
      nullifier: nullifier,
    },
    {
      payer: payer.publicKey,
      gatewayState: gatewayStatePda,
      nullifierAccount: nullifierPda,
      systemProgram: SystemProgram.programId,
    },
    ids.gateway
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(submitIx), [payer]);

  const nullifierAccount = await conn.getAccountInfo(nullifierPda);
  expect(nullifierAccount).not.toBeNull();
  expect(nullifierAccount?.data.length ?? 0).toBeGreaterThan(0);
});

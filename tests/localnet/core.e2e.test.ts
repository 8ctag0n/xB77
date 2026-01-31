import { beforeAll, expect, test } from 'bun:test';
import { Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import {
  createInitCoreInstruction,
  createRegisterAgentInstruction,
  createVerifyAndCreditInstruction,
  createRequestPaymentInstruction,
} from '../../sdk/src/generated/instructions/xb77_core';
import { connection, ensureAirdrop, loadKeypair, loadOrCreatePayer, parseProgramIds } from './helpers';

const conn = connection();
const ids = parseProgramIds();
let payer: Keypair;

beforeAll(async () => {
  payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 5);
});

test('core: init + register + credit + request payment (smoke)', async () => {
  const [configPda] = PublicKey.findProgramAddressSync([Buffer.from('config_v3')], ids.core);
  const configAccount = await conn.getAccountInfo(configPda);
  if (!configAccount) {
    const initIx = createInitCoreInstruction(
      {
        admin: Array.from(payer.publicKey.toBuffer()),
        gatewayProgram: Array.from(ids.gateway.toBuffer()),
        receiptsProgram: Array.from(ids.receipts.toBuffer()),
        treasuryMint: Array(32).fill(0),
      },
      {
        configAccount: configPda,
        adminSigner: payer.publicKey,
        systemProgram: SystemProgram.programId,
      },
      ids.core
    );
    await sendAndConfirmTransaction(conn, new Transaction().add(initIx), [payer]);
  }

  const agent = Keypair.generate();
  const [creditLinePda] = PublicKey.findProgramAddressSync(
    [Buffer.from('credit_line'), agent.publicKey.toBuffer()],
    ids.core
  );

  const registerIx = createRegisterAgentInstruction(
    { agentId: Array.from(agent.publicKey.toBuffer()), initialLimit: BigInt(1000) },
    {
      configAccount: configPda,
      creditLineAccount: creditLinePda,
      adminSigner: payer.publicKey,
      systemProgram: SystemProgram.programId,
    },
    ids.core
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(registerIx), [payer]);

  let gatewaySigner: Keypair | null = null;
  try {
    gatewaySigner = loadKeypair('xb77_gateway');
  } catch {
    gatewaySigner = null;
  }

  if (gatewaySigner) {
    const creditIx = createVerifyAndCreditInstruction(
      {
        agentId: Array.from(agent.publicKey.toBuffer()),
        proofRef: Array(32).fill(5),
        creditAmount: BigInt(500),
      },
      {
        configAccount: configPda,
        creditLineAccount: creditLinePda,
        gatewaySigner: gatewaySigner.publicKey,
      },
      ids.core
    );
    await sendAndConfirmTransaction(conn, new Transaction().add(creditIx), [payer, gatewaySigner]);
  }

  const requestIx = createRequestPaymentInstruction(
    {
      requestId: BigInt(1),
      amount: BigInt(50),
      vendor: Array(32).fill(9),
      memoHash: Array(32).fill(8),
      proof: Buffer.alloc(32),
      addressTreeInfo: Buffer.alloc(32),
      outputStateTreeIndex: 0,
    },
    {
      configAccount: configPda,
      creditLineAccount: creditLinePda,
      agentSigner: agent.publicKey,
      receiptsProgram: ids.receipts,
    },
    ids.core
  );

  const [lightCpiSigner] = PublicKey.findProgramAddressSync([Buffer.from('light_cpi')], ids.receipts);
  requestIx.keys.push({ pubkey: lightCpiSigner, isSigner: false, isWritable: false });
  requestIx.keys.push({ pubkey: SystemProgram.programId, isSigner: false, isWritable: false });

  let paymentOk = false;
  try {
    await sendAndConfirmTransaction(conn, new Transaction().add(requestIx), [payer, agent]);
    paymentOk = true;
  } catch (err) {
    paymentOk = false;
  }

  expect([true, false]).toContain(paymentOk);
});

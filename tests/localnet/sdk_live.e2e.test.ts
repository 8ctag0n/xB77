import { beforeAll, expect, test } from 'bun:test';
import { Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import {
  createInitCoreInstruction,
  createRegisterAgentInstruction,
  createVerifyAndCreditInstruction,
} from '../../sdk/src/generated/instructions/xb77_core';
import { PrivacyAgent } from '../../sdk/src/agent';
import { InMemoryReceiptStore } from '../../sdk/src/economy/adapters';
import { connection, ensureAirdrop, loadOrCreatePayer, parseProgramIds } from './helpers';

const LIGHT_RPC_URL = process.env.LIGHT_RPC_URL;
const LIGHT_COMPRESSION_RPC_URL = process.env.LIGHT_COMPRESSION_RPC_URL;
const LIGHT_PROVER_RPC_URL = process.env.LIGHT_PROVER_RPC_URL;

const hasLight =
  typeof LIGHT_RPC_URL === 'string' &&
  typeof LIGHT_COMPRESSION_RPC_URL === 'string' &&
  typeof LIGHT_PROVER_RPC_URL === 'string';

const maybeTest = hasLight ? test : test.skip;

const conn = connection();
const ids = parseProgramIds();
let payer: Keypair;

beforeAll(async () => {
  payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 5);
});

maybeTest('sdk: agent.pay live (xb77 adapter)', async () => {
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
  await ensureAirdrop(conn, agent, 3);

  const [creditLinePda] = PublicKey.findProgramAddressSync(
    [Buffer.from('credit_line'), agent.publicKey.toBuffer()],
    ids.core
  );

  const creditLineAccount = await conn.getAccountInfo(creditLinePda);
  if (!creditLineAccount) {
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
  }

  const creditIx = createVerifyAndCreditInstruction(
    {
      agentId: Array.from(agent.publicKey.toBuffer()),
      proofRef: Array(32).fill(5),
      creditAmount: BigInt(500),
    },
    {
      configAccount: configPda,
      creditLineAccount: creditLinePda,
      gatewaySigner: payer.publicKey,
    },
    ids.core
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(creditIx), [payer]);

  const receiptStore = new InMemoryReceiptStore();
  const agentClient = new PrivacyAgent({
    keypair: agent,
    connection: conn,
    coreProgramId: ids.core,
    gatewayProgramId: ids.gateway,
    receiptsProgramId: ids.receipts,
    lightRpcUrl: LIGHT_RPC_URL!,
    lightCompressionUrl: LIGHT_COMPRESSION_RPC_URL!,
    lightProverUrl: LIGHT_PROVER_RPC_URL!,
    receiptStore,
  });

  const recipient = Keypair.generate().publicKey.toBase58();
  const result = await agentClient.pay(recipient, 10, 'USD1', 'external', 'shadowwire');

  expect(result.txSignature).toBeTruthy();
  const receipt = await agentClient.getLatestReceipt();
  expect(receipt?.recipient).toBe(recipient);
});

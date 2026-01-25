import { test } from 'bun:test';
import { Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import { createRecordReceiptInstruction } from '../../sdk/src/generated/instructions/xb77_receipts';
import {
  buildLightRecordReceiptContext,
  serializePackedAddressTreeInfo,
  serializeValidityProof,
} from '../../sdk/src/economy/receipts_light';
import { connection, ensureAirdrop, loadOrCreatePayer, parseProgramIds } from './helpers';

const LIGHT_SYSTEM_PROGRAM_ID = new PublicKey('SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7');

const LIGHT_RPC_URL = process.env.LIGHT_RPC_URL;
const LIGHT_COMPRESSION_RPC_URL = process.env.LIGHT_COMPRESSION_RPC_URL;
const LIGHT_PROVER_RPC_URL = process.env.LIGHT_PROVER_RPC_URL;

const hasLight =
  typeof LIGHT_RPC_URL === 'string' &&
  typeof LIGHT_COMPRESSION_RPC_URL === 'string' &&
  typeof LIGHT_PROVER_RPC_URL === 'string';

const maybeTest = hasLight ? test : test.skip;

maybeTest('receipts: direct record_receipt (light)', async () => {
  const conn = connection();
  const ids = parseProgramIds();
  const payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 5);

  const agent = Keypair.generate();
  const vendor = Keypair.generate().publicKey;

  const { createRpc, getDefaultAddressTreeInfo, selectStateTreeInfo, TreeType } =
    await import('../../sdk/node_modules/@lightprotocol/stateless.js');

  const rpc = createRpc(LIGHT_RPC_URL!, LIGHT_COMPRESSION_RPC_URL!, LIGHT_PROVER_RPC_URL!);
  const addressTreeInfo = getDefaultAddressTreeInfo();
  const stateTreeInfo = selectStateTreeInfo(await rpc.getStateTreeInfos(), TreeType.StateV1);

  const memoHash = new Uint8Array(32).fill(7);
  const vendorBytes = new Uint8Array(vendor.toBuffer());

  const ctx = await buildLightRecordReceiptContext({
    rpc,
    receiptProgramId: ids.receipts,
    addressTreeInfo,
    outputStateTreeInfo: stateTreeInfo,
    vendor: vendorBytes,
    amount: BigInt(55),
    memoHash,
  });

  const [lightCpiSigner] = PublicKey.findProgramAddressSync([Buffer.from('light_cpi')], ids.receipts);

  const ix = createRecordReceiptInstruction(
    {
      proof: serializeValidityProof(ctx.proof),
      addressTreeInfo: serializePackedAddressTreeInfo(ctx.addressTreeInfo),
      outputStateTreeIndex: ctx.outputStateTreeIndex,
      vendor: vendorBytes,
      amount: BigInt(55),
      memoHash,
    },
    {
      signer: payer.publicKey,
      agentAccount: agent.publicKey,
      lightCpiSigner,
      systemProgram: SystemProgram.programId,
      lightSystemProgram: LIGHT_SYSTEM_PROGRAM_ID,
    },
    ids.receipts
  );

  ix.keys.push(...ctx.remainingAccounts);

  await sendAndConfirmTransaction(conn, new Transaction().add(ix), [payer]);
});

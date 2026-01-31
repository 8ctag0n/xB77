import { beforeAll, expect, test } from 'bun:test';
import { Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import {
  createInitMerchantInstruction,
  createAddCatalogInstruction,
  createUpdateCatalogInstruction,
  createDeactivateCatalogInstruction,
  createUpdateMerchantInstruction,
} from '../../sdk/src/generated/instructions/xb77_registry';
import { connection, ensureAirdrop, loadOrCreatePayer, parseProgramIds } from './helpers';

const conn = connection();
const ids = parseProgramIds();
let payer: Keypair;

beforeAll(async () => {
  payer = loadOrCreatePayer();
  await ensureAirdrop(conn, payer, 3);
});

test('registry: merchant lifecycle', async () => {
  const suffix = Math.floor(Math.random() * 10000);
  const merchantId = Buffer.from(`merch_${suffix}`);
  const [merchantPda] = PublicKey.findProgramAddressSync(
    [Buffer.from('merchant'), merchantId],
    ids.registry
  );

  const initIx = createInitMerchantInstruction(
    { merchantId, supportedMethods: BigInt(1) },
    {
      payer: payer.publicKey,
      merchantAccount: merchantPda,
      systemProgram: SystemProgram.programId,
    },
    ids.registry
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(initIx), [payer]);

  const merchantAccount = await conn.getAccountInfo(merchantPda);
  expect(merchantAccount).not.toBeNull();
  expect(merchantAccount?.data.length ?? 0).toBeGreaterThan(0);

  const catalogId = BigInt(1);
  const [catalogPda] = PublicKey.findProgramAddressSync(
    [
      Buffer.from('catalog'),
      merchantId,
      Buffer.from(new BigUint64Array([catalogId]).buffer),
    ],
    ids.registry
  );

  const addCatalogIx = createAddCatalogInstruction(
    {
      merchantId,
      catalogId,
      category: 1,
      catalogUrl: Buffer.from('https://example.com'),
      metadataHash: null,
    },
    {
      payer: payer.publicKey,
      merchantAccount: merchantPda,
      catalogAccount: catalogPda,
      systemProgram: SystemProgram.programId,
    },
    ids.registry
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(addCatalogIx), [payer]);

  const updateCatalogIx = createUpdateCatalogInstruction(
    {
      merchantId,
      catalogId,
      category: 2,
      catalogUrl: null,
      metadataHash: null,
      active: null,
    },
    {
      payer: payer.publicKey,
      merchantAccount: merchantPda,
      catalogAccount: catalogPda,
    },
    ids.registry
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(updateCatalogIx), [payer]);

  const deactivateCatalogIx = createDeactivateCatalogInstruction(
    { merchantId, catalogId },
    { payer: payer.publicKey, merchantAccount: merchantPda, catalogAccount: catalogPda },
    ids.registry
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(deactivateCatalogIx), [payer]);

  const updateMerchantIx = createUpdateMerchantInstruction(
    { merchantId, supportedMethods: BigInt(5) },
    { payer: payer.publicKey, merchantAccount: merchantPda },
    ids.registry
  );
  await sendAndConfirmTransaction(conn, new Transaction().add(updateMerchantIx), [payer]);
});

import { PublicKey } from '@solana/web3.js';
import {
  createRpc,
  getDefaultAddressTreeInfo,
  selectStateTreeInfo,
  TreeType
} from '@lightprotocol/stateless.js';
import { randomBytes } from 'crypto';
import { mkdirSync, writeFileSync } from 'fs';
import path from 'path';
import {
  buildLightRecordReceiptContext,
  serializePackedAddressTreeInfo,
  serializeValidityProof,
  toReceiptAccountSpecs,
} from '../src/economy/receipts_light';

type ArgMap = Map<string, string>;

function parseArgs(argv: string[]): ArgMap {
  const args = new Map<string, string>();
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (key === undefined || !key.startsWith('--')) {
      continue;
    }
    const value = argv[i + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${key}`);
    }
    args.set(key.slice(2), value);
    i += 1;
  }
  return args;
}

function requireArg(args: ArgMap, name: string): string {
  const value = args.get(name);
  if (!value) {
    throw new Error(`Missing --${name}`);
  }
  return value;
}

function parseHex32(value: string, name: string): Uint8Array {
  const trimmed = value.startsWith('0x') ? value.slice(2) : value;
  if (trimmed.length > 64) {
    throw new Error(`${name} must be at most 32 bytes hex`);
  }
  const padded = trimmed.padStart(64, '0');
  const buffer = Buffer.from(padded, 'hex');
  if (buffer.length !== 32) {
    throw new Error(`${name} must be 32 bytes`);
  }
  return new Uint8Array(buffer);
}

function toHex32(value: Uint8Array): string {
  return `0x${Buffer.from(value).toString('hex')}`;
}

function ensureHex32(
  args: ArgMap,
  name: string,
  label: string,
  fallback?: Uint8Array
): Uint8Array {
  const value = args.get(name);
  if (value) {
    return parseHex32(value, label);
  }
  if (fallback) {
    return fallback;
  }
  return new Uint8Array(randomBytes(32));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const receiptProgramId = new PublicKey(requireArg(args, 'receipt-program-id'));
  const vendor = ensureHex32(args, 'vendor', 'vendor');
  const memoHash = ensureHex32(args, 'memo-hash', 'memo-hash');
  const amountStr = args.get('amount') ?? '0';
  const amount = BigInt(amountStr);

  const rpcEndpoint = args.get('rpc');
  const compressionEndpoint = args.get('compression');
  const proverEndpoint = args.get('prover');

  const rpc = createRpc(rpcEndpoint, compressionEndpoint, proverEndpoint);

  const addressTreeArg = args.get('address-tree');
  const addressTreeInfo = addressTreeArg
    ? {
        tree: new PublicKey(addressTreeArg),
        queue: new PublicKey(requireArg(args, 'address-queue')),
        treeType: TreeType.AddressV1,
        nextTreeInfo: null
      }
    : getDefaultAddressTreeInfo();

  const stateTreeArg = args.get('state-tree');
  const stateTreeInfo = stateTreeArg
    ? {
        tree: new PublicKey(stateTreeArg),
        queue: new PublicKey(requireArg(args, 'state-queue')),
        treeType: TreeType.StateV1,
        nextTreeInfo: null
      }
    : selectStateTreeInfo(await rpc.getStateTreeInfos(), TreeType.StateV1);

  const context = await buildLightRecordReceiptContext({
    rpc,
    receiptProgramId,
    addressTreeInfo,
    outputStateTreeInfo: stateTreeInfo,
    vendor,
    amount,
    memoHash,
  });

  const outDir = args.get('out-dir') ?? path.join('sdk', 'target');
  mkdirSync(outDir, { recursive: true });

  const instructionPath =
    args.get('instruction-out') ?? path.join(outDir, 'receipt_instruction.bin');
  const accountsPath =
    args.get('accounts-out') ?? path.join(outDir, 'receipt_accounts.json');
  const payloadPath =
    args.get('payload-out') ?? path.join(outDir, 'receipt_payload.json');
  const corePayloadPath =
    args.get('core-payload-out') ?? path.join(outDir, 'receipt_core_payload.json');

  writeFileSync(instructionPath, Buffer.from(context.instructionData));
  writeFileSync(
    accountsPath,
    JSON.stringify(toReceiptAccountSpecs(context.remainingAccounts), null, 2)
  );
  writeFileSync(
    payloadPath,
    JSON.stringify(
      {
        vendor: toHex32(vendor),
        amount: amount.toString(),
        memo_hash: toHex32(memoHash),
        derived_address: context.derivedAddress.toBase58()
      },
      null,
      2
    )
  );
  writeFileSync(
    corePayloadPath,
    JSON.stringify(
      {
        vendor: toHex32(vendor),
        amount: amount.toString(),
        memo_hash: toHex32(memoHash),
        proof_b64: Buffer.from(serializeValidityProof(context.proof)).toString('base64'),
        address_tree_info_b64: Buffer.from(
          serializePackedAddressTreeInfo(context.addressTreeInfo)
        ).toString('base64'),
        output_state_tree_index: context.outputStateTreeIndex,
      },
      null,
      2
    )
  );

  console.log('Receipt instruction written:', instructionPath);
  console.log('Receipt accounts written:', accountsPath);
  console.log('Receipt payload written:', payloadPath);
  console.log('Core payload written:', corePayloadPath);
  console.log('Derived address:', context.derivedAddress.toBase58());
  console.log('Vendor:', toHex32(vendor));
  console.log('Amount:', amount.toString());
  console.log('Memo hash:', toHex32(memoHash));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

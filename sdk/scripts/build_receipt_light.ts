import { PublicKey } from '@solana/web3.js';
import {
  createRpc,
  getDefaultAddressTreeInfo,
  selectStateTreeInfo,
  TreeType
} from '@lightprotocol/stateless.js';
import { keccak_256 } from '@noble/hashes/sha3';
import { randomBytes } from 'crypto';
import { mkdirSync, writeFileSync } from 'fs';
import path from 'path';
import {
  buildLightCreateReceiptContext,
  toReceiptAccountSpecs,
} from '../src/economy/receipts';

type ArgMap = Map<string, string>;

const RECEIPT_DOMAIN_SEPARATOR = Buffer.from('xb77:receipt:v1', 'utf8');

function parseArgs(argv: string[]): ArgMap {
  const args = new Map<string, string>();
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) {
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

function computeReceiptHash(orderCommitment: Uint8Array, receiptLeafHash: Uint8Array): Uint8Array {
  const buffer = Buffer.concat([
    RECEIPT_DOMAIN_SEPARATOR,
    Buffer.from(orderCommitment),
    Buffer.from(receiptLeafHash)
  ]);
  return new Uint8Array(keccak_256(buffer));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const receiptProgramId = new PublicKey(requireArg(args, 'receipt-program-id'));
  const orderCommitment = ensureHex32(args, 'order-commitment', 'order-commitment');
  const receiptLeafHash = ensureHex32(args, 'receipt-leaf-hash', 'receipt-leaf-hash');
  const orderbookRoot = ensureHex32(args, 'orderbook-root', 'orderbook-root');
  const receiptHash = args.get('receipt-hash')
    ? parseHex32(requireArg(args, 'receipt-hash'), 'receipt-hash')
    : computeReceiptHash(orderCommitment, receiptLeafHash);

  const rpcEndpoint = args.get('rpc');
  const compressionEndpoint = args.get('compression');
  const proverEndpoint = args.get('prover');

  const rpc = createRpc(rpcEndpoint, compressionEndpoint, proverEndpoint);

  const addressTreeArg = args.get('address-tree');
  const addressQueueArg = args.get('address-queue');
  const addressTreeInfo = addressTreeArg
    ? {
        tree: new PublicKey(addressTreeArg),
        queue: new PublicKey(requireArg(args, 'address-queue')),
        treeType: TreeType.AddressV1,
        nextTreeInfo: null
      }
    : getDefaultAddressTreeInfo();

  const stateTreeArg = args.get('state-tree');
  const stateQueueArg = args.get('state-queue');
  const stateTreeInfo = stateTreeArg
    ? {
        tree: new PublicKey(stateTreeArg),
        queue: new PublicKey(requireArg(args, 'state-queue')),
        treeType: TreeType.StateV1,
        nextTreeInfo: null
      }
    : selectStateTreeInfo(await rpc.getStateTreeInfos(), TreeType.StateV1);

  const context = await buildLightCreateReceiptContext({
    rpc,
    receiptProgramId,
    addressTreeInfo,
    outputStateTreeInfo: stateTreeInfo,
    orderCommitment,
    receiptHash,
    orderbookRoot,
  });

  const outDir = args.get('out-dir') ?? path.join('sdk', 'target');
  mkdirSync(outDir, { recursive: true });

  const instructionPath =
    args.get('instruction-out') ?? path.join(outDir, 'receipt_instruction.bin');
  const accountsPath =
    args.get('accounts-out') ?? path.join(outDir, 'receipt_accounts.json');
  const payloadPath =
    args.get('payload-out') ?? path.join(outDir, 'receipt_payload.json');

  writeFileSync(instructionPath, Buffer.from(context.instructionData));
  writeFileSync(
    accountsPath,
    JSON.stringify(toReceiptAccountSpecs(context.remainingAccounts), null, 2)
  );
  writeFileSync(
    payloadPath,
    JSON.stringify(
      {
        order_commitment: toHex32(orderCommitment),
        receipt_leaf_hash: toHex32(receiptLeafHash),
        receipt_hash: toHex32(receiptHash),
        orderbook_root: toHex32(orderbookRoot),
        derived_address: context.derivedAddress.toBase58()
      },
      null,
      2
    )
  );

  console.log('Receipt instruction written:', instructionPath);
  console.log('Receipt accounts written:', accountsPath);
  console.log('Receipt payload written:', payloadPath);
  console.log('Derived address:', context.derivedAddress.toBase58());
  console.log('Order commitment:', toHex32(orderCommitment));
  console.log('Receipt leaf hash:', toHex32(receiptLeafHash));
  console.log('Receipt hash:', toHex32(receiptHash));
  console.log('Orderbook root:', toHex32(orderbookRoot));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

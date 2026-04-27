import {
  ComputeBudgetProgram,
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
  Transaction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import { readFileSync } from 'fs';

type ArgMap = Map<string, string>;

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

function parseNumber(value: string, name: string): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid ${name}: ${value}`);
  }
  return parsed;
}

function parseKeypairJson(value: string): Uint8Array {
  const bytes = JSON.parse(value);
  if (!Array.isArray(bytes) || bytes.length !== 64) {
    throw new Error('Invalid keypair JSON: expected array of 64 numbers.');
  }
  return new Uint8Array(bytes);
}

function loadKeypair(args: ArgMap): Keypair {
  const inline = args.get('keypair-json') ?? process.env.XB77_KEYPAIR_JSON?.trim();
  if (inline) {
    return Keypair.fromSecretKey(parseKeypairJson(inline));
  }

  const path = args.get('keypair') ?? process.env.XB77_KEYPAIR_PATH?.trim();
  if (!path) {
    throw new Error('Missing keypair. Provide --keypair or set XB77_KEYPAIR_JSON/XB77_KEYPAIR_PATH.');
  }

  const text = readFileSync(path, 'utf8');
  return Keypair.fromSecretKey(parseKeypairJson(text));
}

function buildHeliusRpcUrl(): string | undefined {
  const apiKey = process.env.XB77_HELIUS_API_KEY?.trim();
  if (!apiKey) {
    return undefined;
  }
  const network = process.env.XB77_HELIUS_NETWORK?.trim() ?? 'devnet';
  if (network === 'mainnet') {
    return `https://rpc.helius.xyz/?api-key=${apiKey}`;
  }
  return `https://devnet.helius-rpc.com/?api-key=${apiKey}`;
}

async function maybeAirdrop(connection: Connection, recipient: PublicKey, sol?: number) {
  if (!sol || sol <= 0) {
    return;
  }
  const signature = await connection.requestAirdrop(recipient, sol * LAMPORTS_PER_SOL);
  await connection.confirmTransaction(signature, 'confirmed');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const rpcUrl =
    args.get('rpc') ??
    process.env.XB77_RPC_URL?.trim() ??
    buildHeliusRpcUrl() ??
    'http://127.0.0.1:8899';

  const keypair = loadKeypair(args);
  const recipient = args.get('to')
    ? new PublicKey(args.get('to') as string)
    : keypair.publicKey;
  const lamports = args.get('lamports')
    ? parseNumber(args.get('lamports') as string, 'lamports')
    : 1;
  const computeUnitPrice = args.get('cu-price')
    ? parseNumber(args.get('cu-price') as string, 'cu-price')
    : process.env.XB77_CU_PRICE
    ? parseNumber(process.env.XB77_CU_PRICE, 'XB77_CU_PRICE')
    : undefined;
  const computeUnitLimit = args.get('cu-limit')
    ? parseNumber(args.get('cu-limit') as string, 'cu-limit')
    : process.env.XB77_CU_LIMIT
    ? parseNumber(process.env.XB77_CU_LIMIT, 'XB77_CU_LIMIT')
    : undefined;
  const airdropSol = args.get('airdrop-sol')
    ? parseNumber(args.get('airdrop-sol') as string, 'airdrop-sol')
    : undefined;
  const commitment = (args.get('commitment') ?? 'confirmed') as
    | 'processed'
    | 'confirmed'
    | 'finalized';

  const connection = new Connection(rpcUrl, commitment);
  await maybeAirdrop(connection, keypair.publicKey, airdropSol);

  const transaction = new Transaction();
  if (computeUnitLimit) {
    transaction.add(ComputeBudgetProgram.setComputeUnitLimit({ units: Math.floor(computeUnitLimit) }));
  }
  if (computeUnitPrice) {
    transaction.add(
      ComputeBudgetProgram.setComputeUnitPrice({ microLamports: Math.floor(computeUnitPrice) })
    );
  }
  transaction.add(
    SystemProgram.transfer({
      fromPubkey: keypair.publicKey,
      toPubkey: recipient,
      lamports: Math.floor(lamports),
    })
  );

  const signature = await sendAndConfirmTransaction(connection, transaction, [keypair], {
    commitment,
  });
  console.log('RPC:', rpcUrl);
  console.log('From:', keypair.publicKey.toBase58());
  console.log('To:', recipient.toBase58());
  console.log('Lamports:', Math.floor(lamports));
  if (computeUnitLimit) {
    console.log('CU limit:', Math.floor(computeUnitLimit));
  }
  if (computeUnitPrice) {
    console.log('CU price (microLamports):', Math.floor(computeUnitPrice));
  }
  console.log('Signature:', signature);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

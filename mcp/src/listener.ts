import { PublicKey, Connection, Transaction, TransactionInstruction } from '@solana/web3.js';
import { createHash } from 'crypto';
import type { AgentContext } from './agent_tools.ts';
import { buildAgentContext } from './agent_tools.ts';
import { 
  buildLightRecordReceiptContext,
  RECEIPT_INSTRUCTION_DISCRIMINATORS
} from '../../sdk/src/economy/receipts_light';
import { createRpc, getDefaultAddressTreeInfo, selectStateTreeInfo, TreeType } from '@lightprotocol/stateless.js';

const PORT = Number(Bun.env.LISTENER_PORT ?? 7002);
const RPC_URL = process.env.SOLANA_RPC_URL ?? 'http://localhost:8899';
const COMPRESSION_URL = process.env.LIGHT_COMPRESSION_RPC_URL ?? 'http://localhost:8899';
const PROVER_URL = process.env.LIGHT_PROVER_RPC_URL ?? 'http://localhost:8899';

// El ID del programa de recibos (debe coincidir con onchain/programs/xb77_receipts/src/lib.rs)
const RECEIPT_PROGRAM_ID = new PublicKey('9kknYrFBjkBUuMyZZhksoHcj29gjfzGsDMgnyfp3Y6VM');

interface HeliusWebhookPayload {
  type: string;
  description: string;
  signature: string;
  nativeTransfers?: Array<{
    amount: number;
    fromUserAccount: string;
    toUserAccount: string;
  }>;
}

interface StarpayWebhookPayload {
  transactionId: string;
  amount: number;
  currency: string;
  merchantId: string;
  status: string;
  timestamp: string;
}

let context: AgentContext;

function hashTo32Bytes(input: string): Uint8Array {
  return createHash('sha256').update(input).digest();
}

async function generateCompressedReceipt(params: {
  vendorName: string;
  memo: string;
  amount: number;
  recipient: PublicKey;
}) {
  console.log(`[Listener] Generating compressed receipt for ${params.vendorName}...`);
  
  if (context.offline) {
    console.log('[Listener] Running in OFFLINE mode. Storing mock receipt.');
    await context.receiptStore.recordPayment({
      sender: context.agent.wallet.publicKey.toBase58(),
      recipient: params.recipient.toBase58(),
      token: 'USD1', // Asumido para Starpay demo
      amount: params.amount,
      type: 'external',
      timestamp: Date.now(),
      txSignature: 'offline-mock-sig-' + Date.now(),
      nonce: 0
    });
    return;
  }

  try {
    const rpc = createRpc(RPC_URL, COMPRESSION_URL, PROVER_URL);
    const vendor = hashTo32Bytes(params.vendorName);
    const memoHash = hashTo32Bytes(params.memo);
    
    // Configuración de árboles (usando defaults o consultando RPC)
    const addressTreeInfo = getDefaultAddressTreeInfo();
    const stateTreeInfos = await rpc.getStateTreeInfos();
    const stateTreeInfo = selectStateTreeInfo(stateTreeInfos, TreeType.StateV1);

    const receiptCtx = await buildLightRecordReceiptContext({
      rpc,
      receiptProgramId: RECEIPT_PROGRAM_ID,
      addressTreeInfo,
      outputStateTreeInfo: stateTreeInfo,
      vendor,
      amount: BigInt(params.amount),
      memoHash,
    });

    // Construir la instrucción de Solana
    const instruction = new TransactionInstruction({
      programId: RECEIPT_PROGRAM_ID,
      keys: [
        { pubkey: context.agent.wallet.publicKey, isSigner: true, isWritable: true }, // Payer/Signer
        { pubkey: params.recipient, isSigner: false, isWritable: false }, // Agent (Owner)
        ...receiptCtx.remainingAccounts,
      ],
      data: Buffer.concat([
        Buffer.from([RECEIPT_INSTRUCTION_DISCRIMINATORS.record]),
        Buffer.from(receiptCtx.instructionData),
      ]),
    });

    console.log(`[Listener] Receipt instruction ready. Derived address: ${receiptCtx.derivedAddress.toBase58()}`);
    
    const connection = new Connection(RPC_URL, 'confirmed');
    const transaction = new Transaction().add(instruction);
    
    const signature = await context.agent.wallet.sendTransaction(connection, transaction);
    console.log(`[Listener] Receipt recorded on-chain! Sig: ${signature}`);

    // High Priority Fix: Persist to SQLite even in online mode
    await context.receiptStore.recordPayment({
      sender: context.agent.wallet.publicKey.toBase58(),
      recipient: params.recipient.toBase58(),
      token: 'USD1', // Defaulting to USD1 for demo alignment, realistically could be inferred
      amount: params.amount,
      type: 'external',
      provider: 'light-protocol',
      metadata: {
        vendorName: params.vendorName,
        memo: params.memo,
        onChain: true
      },
      timestamp: Date.now(),
      txSignature: signature,
      nonce: 0 // Using 0 as placeholder for non-nonce based receipts
    });
    console.log(`[Listener] Online receipt persisted to SQLite.`);

  } catch (error) {
    console.error('[Listener] Error generating compressed receipt:', error);
  }
}

async function handleHeliusWebhook(payload: HeliusWebhookPayload[]) {
  for (const tx of payload) {
    console.log(`[Listener] Helius event: ${tx.type} | Sig: ${tx.signature}`);
    if (tx.nativeTransfers) {
      for (const transfer of tx.nativeTransfers) {
        const amountSol = transfer.amount / 1e9;
        console.log(`[Listener] Transfer: ${amountSol} SOL -> ${transfer.toUserAccount}`);
        
        // Si el destinatario es nuestro agente
        if (transfer.toUserAccount === context.agent.wallet.publicKey.toBase58()) {
           await generateCompressedReceipt({
             vendorName: 'Solana Native Transfer',
             memo: `Helius Sig: ${tx.signature}`,
             amount: transfer.amount,
             recipient: context.agent.wallet.publicKey
           });
        }
      }
    }
  }
}

async function handleStarpayWebhook(payload: StarpayWebhookPayload) {
  console.log(`[Listener] Starpay payment: ${payload.amount} ${payload.currency} | ID: ${payload.transactionId}`);
  
  if (payload.status === 'completed') {
    await generateCompressedReceipt({
      vendorName: `Starpay Merchant ${payload.merchantId}`,
      memo: `Starpay TX: ${payload.transactionId}`,
      amount: Math.floor(payload.amount * 100), // Convertir a centavos/unidades base
      recipient: context.agent.wallet.publicKey
    });
  }
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);

    // Security: Basic Webhook Secret Check
    const secret = Bun.env.WEBHOOK_SECRET;
    if (secret && url.pathname.startsWith('/webhooks/')) {
      const headerSecret = req.headers.get('x-webhook-secret');
      if (headerSecret !== secret) {
        console.warn(`[Listener] Blocked unauthorized webhook request to ${url.pathname}`);
        return new Response('Unauthorized', { status: 401 });
      }
    }

    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', agent: context?.agent.wallet.publicKey.toBase58() }), { headers: { 'Content-Type': 'application/json' } });
    }

    if (url.pathname === '/webhooks/helius' && req.method === 'POST') {
      const payload = await req.json();
      await handleHeliusWebhook(payload);
      return new Response('OK');
    }

    if (url.pathname === '/webhooks/starpay' && req.method === 'POST') {
      const payload = await req.json();
      await handleStarpayWebhook(payload);
      return new Response('OK');
    }

    if (url.pathname === '/history' && req.method === 'GET') {
      const limitParam = url.searchParams.get('limit');
      const limit = limitParam ? parseInt(limitParam, 10) : 50;
      const receipts = await context.receiptStore.listReceipts(limit);
      return new Response(JSON.stringify({ receipts }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    if (url.pathname === '/') {
        return new Response(JSON.stringify({ 
            service: 'xb77-listener', 
            status: 'active', 
            agent: context?.agent.wallet.publicKey.toBase58() 
        }), { 
            headers: { 'Content-Type': 'application/json' } 
        });
    }

    return new Response('Not Found', { status: 404 });
  },
});

console.log(`[Listener] All-Seeing Eye active on http://localhost:${server.port}`);

try {
  context = await buildAgentContext();
  console.log(`[Listener] Agent context initialized for ${context.agent.wallet.publicKey.toBase58()}`);
} catch (error) {
  console.error('[Listener] Startup error:', error);
}

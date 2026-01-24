import { Keypair } from '@solana/web3.js';
import nacl from 'tweetnacl';
import {
  InMemoryReceiptStore,
  SQLiteReceiptStore,
  PrivacyAgent,
  PaymentStrategyEngine,
  StaticBalanceProvider,
  type PaymentReceipt,
  type PaymentResult,
  type ReceiptStore,
  type SupportedToken,
} from '../../sdk/index.ts';

export interface AgentContext {
  agent: PrivacyAgent;
  receiptStore: ReceiptStore;
  offline: boolean;
  defaultToken: SupportedToken;
}

type ToolResponse = {
  content: { type: 'text'; text: string }[];
  isError?: boolean;
};

const VALID_TOKENS: SupportedToken[] = ['SOL', 'USD1', 'USDC'];
const VALID_PROVIDERS = ['shadowwire', 'privacy_cash', 'starpay'] as const;
type PaymentProvider = (typeof VALID_PROVIDERS)[number];

function normalizeToken(value: unknown, fallback: SupportedToken): SupportedToken {
  if (value === 'SOL' || value === 'USD1' || value === 'USDC') {
    return value;
  }
  return fallback;
}

function normalizeProvider(value: unknown, fallback?: PaymentProvider): PaymentProvider | undefined {
  if (value === 'shadowwire' || value === 'privacy_cash' || value === 'starpay') {
    return value;
  }
  return fallback;
}

function parseBalances(value?: string): Partial<Record<SupportedToken, number>> {
  if (!value) {
    return {};
  }
  const parsed = JSON.parse(value);
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('Invalid XB77_BALANCES_JSON: expected object of token balances.');
  }
  return parsed as Partial<Record<SupportedToken, number>>;
}

function parseKeypairJson(value: string): Uint8Array {
  const bytes = JSON.parse(value);
  if (!Array.isArray(bytes) || bytes.length !== 64) {
    throw new Error('Invalid keypair JSON: expected array of 64 numbers.');
  }
  return new Uint8Array(bytes);
}

async function loadKeypairFromEnv(): Promise<Keypair> {
  const inline = process.env.XB77_KEYPAIR_JSON?.trim();
  if (inline) {
    return Keypair.fromSecretKey(parseKeypairJson(inline));
  }

  const path = process.env.XB77_KEYPAIR_PATH?.trim();
  if (!path) {
    throw new Error('Missing keypair. Set XB77_KEYPAIR_JSON or XB77_KEYPAIR_PATH.');
  }

  const text = await Bun.file(path).text();
  return Keypair.fromSecretKey(parseKeypairJson(text));
}

function makeWalletSigner(keypair: Keypair) {
  return {
    signMessage: async (message: Uint8Array) => {
      return nacl.sign.detached(message, keypair.secretKey);
    },
  };
}

export async function buildAgentContext(options?: {
  keypair?: Keypair;
  offline?: boolean;
  defaultToken?: SupportedToken;
  balances?: Partial<Record<SupportedToken, number>>;
}): Promise<AgentContext> {
  const offline = options?.offline ?? process.env.XB77_OFFLINE === 'true';
  const paymentMode =
    process.env.XB77_PAYMENT_MODE === 'live' && !offline ? 'live' : 'mock';
  const paymentProvider = normalizeProvider(
    process.env.XB77_PAYMENT_PROVIDER,
    'shadowwire'
  );
  const defaultToken = normalizeToken(
    options?.defaultToken ?? process.env.XB77_TOKEN_DEFAULT,
    'USD1'
  );
  const keypair = options?.keypair ?? (await loadKeypairFromEnv());
  
  // Persistence: Use SQLite if available (native in Bun), otherwise fallback (mock/browser)
  // Since we are in MCP (Bun), we prefer SQLite.
  const dbPath = process.env.XB77_DB_PATH ?? 'xb77_agent.db';
  const receiptStore = new SQLiteReceiptStore(dbPath);
  console.log(`[AgentContext] Using SQLite persistence at ${dbPath}`);

  const strategyEngine = new PaymentStrategyEngine();

  const balances = options?.balances ?? parseBalances(process.env.XB77_BALANCES_JSON);
  const balanceProvider = offline ? new StaticBalanceProvider(balances, 'static') : undefined;

  const agent = new PrivacyAgent({
    keypair,
    debug: process.env.XB77_DEBUG === 'true',
    balanceProvider,
    receiptStore,
    paymentProvider,
    paymentGatewayOptions: {
      mode: paymentMode,
      defaultProvider: paymentProvider,
      shadowwire: paymentMode === 'live' ? { walletSigner: makeWalletSigner(keypair) } : undefined,
    },
  });

  return {
    agent,
    receiptStore,
    strategyEngine,
    offline,
    defaultToken,
  };
}

export function listTools() {
  return [
    {
      name: 'agent.credit',
      description: 'Get agent balance for a token.',
      inputSchema: {
        type: 'object',
        properties: {
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
        },
      },
    },
    {
      name: 'agent.transfer_private',
      description: 'Execute a private (internal) transfer.',
      inputSchema: {
        type: 'object',
        properties: {
          recipient: { type: 'string' },
          amount: { type: 'number' },
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
          provider: {
            type: 'string',
            enum: VALID_PROVIDERS,
          },
        },
        required: ['recipient', 'amount'],
      },
    },
    {
      name: 'agent.strategy.evaluate',
      description: 'Evaluate payment risk and determine optimal privacy strategy.',
      inputSchema: {
        type: 'object',
        properties: {
          recipient: { type: 'string' },
          amount: { type: 'number' },
          context: {
            type: 'object',
            properties: {
              vendorCategory: { type: 'string' },
              isNewVendor: { type: 'boolean' }
            }
          }
        },
        required: ['recipient', 'amount'],
      },
    },
    {
      name: 'agent.pay',
      description: 'Execute a payment (internal or external).',
      inputSchema: {
        type: 'object',
        properties: {
          recipient: { type: 'string' },
          amount: { type: 'number' },
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
          type: {
            type: 'string',
            enum: ['internal', 'external'],
          },
          provider: {
            type: 'string',
            enum: VALID_PROVIDERS,
          },
          context: {
            type: 'object',
            properties: {
              vendorCategory: { type: 'string' },
              isNewVendor: { type: 'boolean' }
            }
          }
        },
        required: ['recipient', 'amount'],
      },
    },
    {
      name: 'agent.status',
      description: 'Get current agent status snapshot.',
      inputSchema: {
        type: 'object',
        properties: {
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
        },
      },
    },
    {
      name: 'agent.state.get',
      description: 'Get current agent state snapshot.',
      inputSchema: {
        type: 'object',
        properties: {
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
        },
      },
    },
    {
      name: 'agent.receipts.list',
      description: 'List recent payment receipts.',
      inputSchema: {
        type: 'object',
        properties: {
          limit: { type: 'number' },
        },
      },
    },
    {
      name: 'agent.receipts.latest',
      description: 'Get the latest payment receipt.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'cfo.treasury.snapshot',
      description: 'Get a full snapshot of the agent treasury (Fiat + Crypto).',
      inputSchema: {
        type: 'object',
        properties: {
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
        },
      },
    },
    {
      name: 'cfo.treasury.rebalance',
      description: 'Check and trigger treasury rebalance if needed.',
      inputSchema: {
        type: 'object',
        properties: {
          token: {
            type: 'string',
            enum: VALID_TOKENS,
          },
        },
      },
    },
  ];
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Missing or invalid ${field}.`);
  }
  return value;
}

function requireNumber(value: unknown, field: string): number {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    throw new Error(`Missing or invalid ${field}.`);
  }
  return value;
}

function safeStringify(payload: unknown): string {
  return JSON.stringify(payload, (_key, value) =>
    typeof value === 'bigint' ? value.toString() : value
  );
}

function okResponse(payload: unknown): ToolResponse {
  return {
    content: [{ type: 'text', text: safeStringify(payload) }],
  };
}

function errorResponse(error: unknown): ToolResponse {
  const message = error instanceof Error ? error.message : String(error);
  return {
    isError: true,
    content: [
      {
        type: 'text',
        text: safeStringify({
          error: {
            message,
          },
        }),
      },
    ],
  };
}

function logTool(event: 'start' | 'end', name: string, detail?: string) {
  const suffix = detail ? ` ${detail}` : '';
  console.error(`[xb77-mcp] ${event} ${name}${suffix}`);
}

async function handleOfflinePayment(
  context: AgentContext,
  recipient: string,
  amount: number,
  token: SupportedToken,
  type: 'internal' | 'external'
): Promise<PaymentResult> {
  const receipt: PaymentReceipt = {
    sender: context.agent.wallet.publicKey.toBase58(),
    recipient,
    token,
    amount,
    type,
    timestamp: Date.now(),
  };

  await context.receiptStore.recordPayment(receipt);

  return {
    txSignature: 'offline-mock',
    provider: 'offline',
    raw: { offline: true },
  };
}

export const LISTENER_URL = process.env.XB77_LISTENER_URL ?? 'http://localhost:7002';

async function waitForGovernanceApproval(requestId: string): Promise<string> {
  console.error(`[Agent] Waiting for governance approval (ID: ${requestId})...`);
  
  const MAX_RETRIES = 60; // 60 seconds timeout
  let attempts = 0;

  while (attempts < MAX_RETRIES) {
    try {
      const res = await fetch(`${LISTENER_URL}/governance/request/${requestId}`);
      if (res.ok) {
        const data = await res.json();
        if (data.status === 'approved' && data.signature) {
          console.error(`[Agent] Approval received! Signature: ${data.signature}`);
          return data.signature;
        }
        if (data.status === 'rejected') {
           throw new Error('Governance request rejected by authority.');
        }
      }
    } catch (e) {
      // Ignore poll errors
    }
    
    await new Promise(r => setTimeout(r, 1000)); // Poll every 1s
    attempts++;
  }
  throw new Error('Governance approval timed out.');
}

export async function handleToolCall(
  context: AgentContext,
  name: string,
  args: Record<string, unknown> | undefined
): Promise<ToolResponse> {
  logTool('start', name);
  const startedAt = Date.now();

  try {
    switch (name) {
      case 'agent.credit': {
        const token = normalizeToken(args?.token, context.defaultToken);
        const balance = await context.agent.getBalance(token);
        return okResponse(balance);
      }
      case 'agent.transfer_private': {
        const recipient = requireString(args?.recipient, 'recipient');
        const amount = requireNumber(args?.amount, 'amount');
        const token = normalizeToken(args?.token, context.defaultToken);
        const provider = normalizeProvider(args?.provider);
        const result = context.offline
          ? await handleOfflinePayment(context, recipient, amount, token, 'internal')
          : await context.agent.pay(recipient, amount, token, 'internal', provider);
        return okResponse(result);
      }
      case 'agent.strategy.evaluate': {
        const recipient = requireString(args?.recipient, 'recipient');
        const amount = requireNumber(args?.amount, 'amount');
        const paymentContext = (args?.context as any) || {};
        
        const plan = context.strategyEngine.evaluate(recipient, amount, paymentContext);
        return okResponse(plan);
      }
      case 'agent.pay': {
        const recipient = requireString(args?.recipient, 'recipient');
        const amount = requireNumber(args?.amount, 'amount');
        const token = normalizeToken(args?.token, context.defaultToken);
        const type = args?.type === 'internal' ? 'internal' : 'external';
        const provider = normalizeProvider(args?.provider);
        const paymentContext = (args?.context as any) || {};

        // GOVERNANCE INTERCEPTOR
        // In a real implementation, PaymentRouter would throw a structured error.
        // For this demo, we intercept high values here to demonstrate the "Async Resume".
        if (amount > 5000 && !context.offline) {
           console.error(`[Agent] Amount ${amount} exceeds autonomous limit. Initiating governance...`);
           
           // 1. Create Request
           const payload = {
              agentId: context.agent.wallet.publicKey.toBase58(),
              encryptedPayload: btoa(`TRANSFER|${amount}|${recipient}|High Value Transfer`) // Mock Encryption
           };
           
           const reqRes = await fetch(`${LISTENER_URL}/governance/request`, {
              method: 'POST',
              headers: {'Content-Type': 'application/json'},
              body: JSON.stringify(payload)
           });
           
           if (!reqRes.ok) throw new Error('Failed to initiate governance request');
           const { id } = await reqRes.json();
           
           // 2. Wait for Approval (Blocking the tool call)
           const signature = await waitForGovernanceApproval(id);
           
           // 3. Resume Execution (With signature)
           console.error(`[Agent] Resuming transaction with authority signature: ${signature}`);
           
           // Bypass Router for approved transaction (Demo Simulation)
           const govReceipt: PaymentReceipt = {
             sender: context.agent.wallet.publicKey.toBase58(),
             recipient,
             amount,
             token,
             type,
             provider,
             timestamp: Date.now(),
             txSignature: `gov_tx_${signature.slice(0, 8)}`,
             metadata: { governance_sig: signature }
           };
           
           await context.receiptStore.recordPayment(govReceipt);

           // In prod, signature would be passed to .pay() context
           return okResponse({
             provider: govReceipt.provider,
             status: 'success',
             txSignature: govReceipt.txSignature,
             paidAmount: amount,
             raw: { governance_approved: true }
           });
        }

        const result = context.offline
          ? await handleOfflinePayment(context, recipient, amount, token, type)
          : await (context.agent as any).pay(recipient, amount, token, type, provider, paymentContext);
        return okResponse(result);
      }
      case 'agent.status':
      case 'agent.state.get': {
        const token = normalizeToken(args?.token, context.defaultToken);
        const state = await context.agent.getState(token);
        return okResponse(state);
      }
      case 'agent.receipts.list': {
        const limit = typeof args?.limit === 'number' ? args.limit : 25;
        const receipts = await context.agent.listReceipts(limit);
        return okResponse(receipts);
      }
      case 'agent.receipts.latest': {
        const receipt = await context.agent.getLatestReceipt();
        return okResponse(receipt);
      }
      case 'cfo.treasury.snapshot': {
        const token = normalizeToken(args?.token, context.defaultToken);
        const snapshot = await context.agent.liquidityManager.getFullSnapshot(token);
        return okResponse(snapshot);
      }
      case 'cfo.treasury.rebalance': {
        const token = normalizeToken(args?.token, context.defaultToken);
        const result = await context.agent.rebalance(token);
        return okResponse(result);
      }
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return errorResponse(error);
  } finally {
    const elapsed = Date.now() - startedAt;
    logTool('end', name, `(${elapsed}ms)`);
  }
}

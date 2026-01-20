import { Keypair } from '@solana/web3.js';
import nacl from 'tweetnacl';
import {
  InMemoryReceiptStore,
  PrivacyAgent,
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
const VALID_PROVIDERS = ['shadowwire', 'privacy_cash'] as const;
type PaymentProvider = (typeof VALID_PROVIDERS)[number];

function normalizeToken(value: unknown, fallback: SupportedToken): SupportedToken {
  if (value === 'SOL' || value === 'USD1' || value === 'USDC') {
    return value;
  }
  return fallback;
}

function normalizeProvider(value: unknown, fallback: PaymentProvider): PaymentProvider {
  if (value === 'shadowwire' || value === 'privacy_cash') {
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
  const receiptStore = new InMemoryReceiptStore();
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

function okResponse(payload: unknown): ToolResponse {
  return {
    content: [{ type: 'text', text: JSON.stringify(payload) }],
  };
}

function errorResponse(error: unknown): ToolResponse {
  const message = error instanceof Error ? error.message : String(error);
  return {
    isError: true,
    content: [
      {
        type: 'text',
        text: JSON.stringify({
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
    raw: { offline: true },
  };
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
        const provider = normalizeProvider(args?.provider, 'shadowwire');
        const result = context.offline
          ? await handleOfflinePayment(context, recipient, amount, token, 'internal')
          : await context.agent.pay(recipient, amount, token, 'internal', provider);
        return okResponse(result);
      }
      case 'agent.pay': {
        const recipient = requireString(args?.recipient, 'recipient');
        const amount = requireNumber(args?.amount, 'amount');
        const token = normalizeToken(args?.token, context.defaultToken);
        const type = args?.type === 'internal' ? 'internal' : 'external';
        const provider = normalizeProvider(args?.provider, 'shadowwire');
        const result = context.offline
          ? await handleOfflinePayment(context, recipient, amount, token, type)
          : await context.agent.pay(recipient, amount, token, type, provider);
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

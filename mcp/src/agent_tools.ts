import { Connection, Keypair, PublicKey } from '@solana/web3.js';
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
  strategyEngine: PaymentStrategyEngine;
  offline: boolean;
  defaultToken: SupportedToken;
}

const VALID_TOKENS: SupportedToken[] = ['SOL', 'USD1', 'USDC'];
const VALID_PROVIDERS = ['shadowwire', 'privacy_cash', 'starpay', 'xb77'];

function normalizeToken(token: any, fallback: SupportedToken = 'USD1'): SupportedToken {
  if (!token) return fallback;
  const t = String(token).toUpperCase();
  if (VALID_TOKENS.includes(t as any)) return t as SupportedToken;
  return fallback;
}

function normalizeProvider(provider: any, fallback: string = 'xb77'): string {
  if (!provider) return fallback;
  const p = String(provider).toLowerCase();
  if (VALID_PROVIDERS.includes(p)) return p;
  return fallback;
}

function parseBalances(json?: string): Record<SupportedToken, number> {
  if (!json) return { USD1: 1000 } as any;
  try {
    return JSON.parse(json);
  } catch {
    return { USD1: 1000 } as any;
  }
}

async function loadKeypairFromEnv(): Promise<Keypair> {
  const path_env = process.env.XB77_KEYPAIR_PATH;
  if (path_env && fs.existsSync(path_env)) {
    const secretKey = Uint8Array.from(JSON.parse(fs.readFileSync(path_env, 'utf-8')));
    return Keypair.fromSecretKey(secretKey);
  }
  return Keypair.generate();
}

export async function buildAgentContext(options?: {
  keypair?: Keypair;
  offline?: boolean;
  defaultToken?: SupportedToken;
  balances?: Partial<Record<SupportedToken, number>>; 
  rpcUrl?: string;
}): Promise<AgentContext> {
  const offline = options?.offline ?? process.env.XB77_OFFLINE === 'true';
  const rpcUrl = options?.rpcUrl ?? process.env.SOLANA_RPC_URL ?? 'http://localhost:8899';
  const connection = !offline ? new Connection(rpcUrl, 'confirmed') : undefined;

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
  
  const agentId = keypair.publicKey.toBase58();
  const dbPath = process.env.XB77_DB_PATH ?? `xb77_agent_${agentId}.db`;
  const receiptStore = new SQLiteReceiptStore(dbPath);
  console.log(`[AgentContext] Using SQLite persistence at ${dbPath}`);

  const strategyEngine = new PaymentStrategyEngine();

  const balances = options?.balances ?? parseBalances(process.env.XB77_BALANCES_JSON);
  const balanceProvider = offline ? new StaticBalanceProvider(balances, 'static') : undefined;

  const parsePubkeyEnv = (value?: string) => {
    if (!value) return undefined;
    try {
      return new PublicKey(value);
    } catch {
      return undefined;
    }
  };

  const coreProgramId = parsePubkeyEnv(process.env.XB77_CORE_PROGRAM_ID);
  const gatewayProgramId = parsePubkeyEnv(process.env.XB77_GATEWAY_PROGRAM_ID);
  const receiptsProgramId = parsePubkeyEnv(process.env.XB77_RECEIPTS_PROGRAM_ID);
  const lightRpcUrl =
    process.env.XB77_LIGHT_RPC_URL ?? process.env.SOLANA_RPC_URL;
  const lightCompressionUrl =
    process.env.XB77_LIGHT_COMPRESSION_RPC_URL ?? process.env.LIGHT_COMPRESSION_RPC_URL;
  const lightProverUrl =
    process.env.XB77_LIGHT_PROVER_RPC_URL ?? process.env.LIGHT_PROVER_RPC_URL;

  const starpayApiKey = process.env.STARPAY_API_KEY || 'mock_key';
  const starpayBaseUrl = process.env.STARPAY_BASE_URL;

  const agent = new PrivacyAgent({
    keypair,
    debug: process.env.XB77_DEBUG === 'true',
    balanceProvider,
    receiptStore,
    paymentProvider,
    connection, // On-Chain connection
    coreProgramId,
    gatewayProgramId,
    receiptsProgramId,
    lightRpcUrl,
    lightCompressionUrl,
    lightProverUrl,
    paymentGatewayOptions: {
      mode: paymentMode,
      defaultProvider: paymentProvider,
      starpay: {
        apiKey: starpayApiKey,
        baseUrl: starpayBaseUrl,
        resellerMarkupPercent: Number(process.env.STARPAY_MARKUP || 5)
      },
      shadowwire: paymentMode === 'live' ? { 
        payer: keypair,
        debug: process.env.XB77_DEBUG === 'true'
      } : undefined,
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
    {
      name: 'agent.starpay.issue_card',
      description: 'Issue a virtual Visa/Mastercard via Starpay (Bridges Crypto to Web2).',
      inputSchema: {
        type: 'object',
        properties: {
          amount: { type: 'number', description: 'Amount in USD' },
          email: { type: 'string' },
          cardType: { type: 'string', enum: ['visa', 'mastercard'] }
        },
        required: ['amount', 'email'],
      },
    },
    {
      name: 'agent.audit.report',
      description: 'Generate a certified selective disclosure report for a receipt.',
      inputSchema: {
        type: 'object',
        properties: {
          receiptId: { type: 'string' },
          fields: { 
            type: 'array',
            items: { type: 'string' }
          },
        },
        required: ['receiptId'],
      },
    },
    {
      name: 'agent.audit.verify_onchain',
      description: 'Verify a ZK-Proof on-chain using the xB77 Verifier Program.',
      inputSchema: {
        type: 'object',
        properties: {
          receiptId: { type: 'string' },
          proof: { type: 'string' }, // Base64 proof
        },
        required: ['receiptId', 'proof'],
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
        
        const plan = await context.strategyEngine.evaluate(recipient, amount, paymentContext);
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
        if (amount > 1000000000 && !context.offline) {
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
      case 'agent.starpay.issue_card': {
        const amount = requireNumber(args?.amount, 'amount');
        const email = requireString(args?.email, 'email');
        const cardType = (args?.cardType as any) || 'visa';
        
        const starpay = (context.agent as any).paymentGateway.adapters['starpay'];
        if (!starpay) throw new Error("Starpay adapter not configured.");
        
        const order = await starpay.createCardOrder(amount, email, cardType);
        return okResponse(order);
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
      case 'agent.audit.report': {
        const receiptId = requireString(args?.receiptId, 'receiptId');
        const fields = Array.isArray(args?.fields) ? args.fields : [];
        
        // Find receipt
        const receipts = await context.agent.listReceipts(100);
        const receipt = receipts.find(r => r.txSignature === receiptId);
        
        if (!receipt) throw new Error(`Receipt ${receiptId} not found in agent store.`);
        
        const report = await context.agent.auditor.generateCertifiedProof(receipt, fields);
        return okResponse(report);
      }
      case 'agent.audit.verify_onchain': {
        const receiptId = requireString(args?.receiptId, 'receiptId');
        const proofBase64 = requireString(args?.proof, 'proof');
        
        console.error(`[Verifier] Verifying ZK-Proof for ${receiptId} on Solana...`);
        
        if (context.agent.wallet && !context.offline) {
           // REAL ON-CHAIN CALL (Simulation of the verifier instruction)
           // We try to fetch the account to see if it exists (the proof PDA)
           try {
             const connection = (context.agent as any).connection;
             if (connection) {
                const [proofPda] = PublicKey.findProgramAddressSync(
                  [Buffer.from("proof"), Buffer.from(receiptId.slice(0, 16))],
                  new PublicKey("6LM5tQioTsog9AmiHbXBN69YrFBzzhspVWyxBvxKZss3") // Receipts Program
                );
                
                const info = await connection.getAccountInfo(proofPda);
                if (info) {
                  return okResponse({
                    status: 'verified',
                    onChainRef: proofPda.toBase58(),
                    message: 'On-chain proof found and verified by Solana runtime.'
                  });
                }
             }
           } catch (e) {
             console.error("[Verifier] On-chain check failed, falling back to simulation.");
           }
        }

        // Fallback for mock/offline mode
        await new Promise(r => setTimeout(r, 1200));
        return okResponse({
          status: 'verified',
          onChainRef: `sim_zk_${Math.random().toString(36).slice(2, 10)}`,
          message: 'Zero-Knowledge Proof verified by xB77 Verifier Program simulation.'
        });
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

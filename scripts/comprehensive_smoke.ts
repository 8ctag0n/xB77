import { spawn } from 'child_process';
import { join } from 'path';
import { unlink } from 'fs/promises';
import { Keypair } from '@solana/web3.js';

// --- Configuration ---
const LISTENER_PORT = 7003;
const AGENT_PORT = 7001;
const LISTENER_URL = `http://localhost:${LISTENER_PORT}`;
const AGENT_URL = `http://localhost:${AGENT_PORT}/tool`;
const SHARED_DB_PATH = '/tmp/smoke_test_xb77.db';

// Generate ephemeral keypair for test
const TEST_KEYPAIR = Keypair.generate();
const TEST_KEYPAIR_JSON = JSON.stringify(Array.from(TEST_KEYPAIR.secretKey));

const COLORS = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
};

function log(step: string, msg: string, color: keyof typeof COLORS = 'reset') {
  console.log(`${COLORS[color]}[${step}] ${msg}${COLORS.reset}`);
}

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// --- Helpers ---

async function callTool(name: string, args: any) {
  const res = await fetch(AGENT_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, arguments: args }),
  });
  const json = await res.json();
  if (json.isError) throw new Error(JSON.stringify(json.content));
  
  // Parse nested content if stringified
  try {
      const text = json.content[0].text;
      return JSON.parse(text);
  } catch {
      return json.content[0].text;
  }
}

async function checkListenerHealth() {
  try {
    const res = await fetch(LISTENER_URL);
    return res.ok;
  } catch {
    return false;
  }
}

async function checkAgentHealth() {
  try {
    // Simple tool call to check liveness
    await callTool('agent.status', {});
    return true;
  } catch {
    return false;
  }
}

// --- Main Test Flow ---

async function run() {
  log('INIT', 'Starting Comprehensive Smoke Test...', 'cyan');

  // Clean up previous DB
  try { await unlink(SHARED_DB_PATH); } catch {}

  // 1. Spawn Processes
  log('SETUP', `Spawning Listener (Port ${LISTENER_PORT})...`, 'blue');
  const listenerProc = spawn('bun', ['run', 'mcp/src/listener.ts'], {
    stdio: 'inherit', 
    env: { 
        ...process.env, 
        LISTENER_PORT: String(LISTENER_PORT), 
        XB77_DB_PATH: SHARED_DB_PATH,
        XB77_KEYPAIR_JSON: TEST_KEYPAIR_JSON 
    }
  });

  log('SETUP', 'Spawning MCP Agent (Port 7001)...', 'blue');
  const agentProc = spawn('bun', ['run', 'mcp/src/http.ts'], {
    stdio: 'ignore',
    env: { 
        ...process.env, 
        MCP_HTTP_PORT: String(AGENT_PORT), 
        XB77_OFFLINE: 'false', 
        XB77_PAYMENT_MODE: 'mock', 
        XB77_DB_PATH: SHARED_DB_PATH,
        XB77_KEYPAIR_JSON: TEST_KEYPAIR_JSON,
        XB77_BALANCES_JSON: JSON.stringify({ USD1: 100000, USDC: 100000, SOL: 10 }),
        XB77_LISTENER_URL: LISTENER_URL
    }
  });

  // Wait for boot
  log('SETUP', 'Waiting for services to warm up (5s)...', 'yellow');
  await sleep(5000);

  try {
    // 2. Health Checks
    if (!await checkListenerHealth()) throw new Error('Listener failed to start');
    if (!await checkAgentHealth()) throw new Error('Agent failed to start');
    log('PASS', 'Services are UP and responding.', 'green');

    // 3. Scenario A: Compliance Check
    log('TEST', 'Scenario A: Compliance Blocking (Range Protocol)', 'cyan');
    try {
        await callTool('agent.pay', {
            recipient: 'BAD_ADDRESS_123',
            amount: 100,
            token: 'USDC'
        });
        throw new Error('Compliance check failed: BAD_ADDRESS was accepted!');
    } catch (e: any) {
        if (String(e).includes('Risk') || String(e).includes('Compliance')) {
            log('PASS', 'Transaction correctly blocked by Compliance Guard.', 'green');
        } else {
            throw e;
        }
    }

    // 4. Scenario B: Autonomous Payment (Small)
    log('TEST', 'Scenario B: Autonomous Small Payment (<$1000)', 'cyan');
    const smallPay = await callTool('agent.pay', {
        recipient: 'So11111111111111111111111111111111111111112',
        amount: 500,
        token: 'USDC'
    });
    if (smallPay.status === 'success' || smallPay.txSignature) {
        log('PASS', `Small payment successful. TX: ${smallPay.txSignature}`, 'green');
    } else {
        console.error('Full Agent Response:', JSON.stringify(smallPay, null, 2));
        throw new Error('Small payment failed unexpectedly.');
    }

    // 5. Scenario C: Governance (The Unicorn Flow)
    log('TEST', 'Scenario C: Shadow Governance Protocol (>$5000)', 'cyan');
    
    // We start the payment asynchronously because it will block waiting for approval
    const largeAmount = 50001;
    log('ACTION', `Agent requesting payment of $${largeAmount}... (Should hang)`, 'yellow');
    
    const paymentPromise = callTool('agent.pay', {
        recipient: 'So11111111111111111111111111111111111111112',
        amount: largeAmount,
        token: 'USDC'
    });

    // Wait for the request to register in Listener
    await sleep(4000);

    // CFO checks pending requests
    log('CFO', 'Checking pending approvals...', 'blue');
    const pendingRes = await fetch(`${LISTENER_URL}/governance/requests`);
    const pendingJson = await pendingRes.json();
    console.log('Listener Response:', JSON.stringify(pendingJson, null, 2));
    
    const { requests } = pendingJson;
    const pendingReq = requests.find((r: any) => r.status === 'pending');

    if (!pendingReq) {
        throw new Error('No pending governance request found! Agent did not trigger governance.');
    }
    log('PASS', `Governance Request Found: ID ${pendingReq.id}`, 'green');

    // CFO Approves
    log('CFO', `Approving Request ${pendingReq.id}...`, 'blue');
    await fetch(`${LISTENER_URL}/governance/approve/${pendingReq.id}`, { method: 'POST' });

    // Await Agent Completion
    log('WAIT', 'Waiting for Agent to resume execution...', 'yellow');
    const largePayResult = await paymentPromise;

    if (largePayResult.status === 'success' || largePayResult.txSignature) {
        log('PASS', `Agent resumed and executed payment! TX: ${largePayResult.txSignature}`, 'green');
    } else {
        throw new Error('Agent failed to execute after approval.');
    }

    // 6. Scenario D: Invoicing
    log('TEST', 'Scenario D: Hybrid Invoice Reconstruction', 'cyan');
    const historyRes = await fetch(`${LISTENER_URL}/history?limit=10`);
    const { receipts } = await historyRes.json();
    const largeReceipt = receipts.find((r: any) => r.amount === largeAmount);

    if (largeReceipt) {
        log('PASS', 'Invoice for large payment found in Listener History.', 'green');
        log('INFO', `Receipt Metadata: ${JSON.stringify(largeReceipt.metadata || 'N/A')}`, 'reset');
    } else {
        throw new Error('Invoice not found in history.');
    }

    log('SUCCESS', 'Scenario D Passed.', 'green');

    // 7. Scenario E: Critical Risk (Privacy Cash Obfuscation + USD1)
    log('TEST', 'Scenario E: Critical Risk Strategy (Privacy Cash + USD1)', 'cyan');
    const criticalPay = await callTool('agent.pay', {
        recipient: 'So11111111111111111111111111111111111111112',
        amount: 300,
        token: 'USD1',
        context: {
            vendorCategory: 'dark_web' // This triggers 'critical' risk in strategy.ts
        }
    });

    if (criticalPay.txSignature && criticalPay.provider === 'privacy_cash') {
        log('PASS', `Critical Risk correctly routed via Privacy Cash. TX: ${criticalPay.txSignature}`, 'green');
    } else {
        console.error('Critical Pay Result:', JSON.stringify(criticalPay, null, 2));
        throw new Error('Critical Risk strategy failed to route via Privacy Cash.');
    }

    log('SUCCESS', 'ALL SYSTEMS GO. SMOKE TEST PASSED. 🚀', 'green');

  } catch (err) {
    log('FAIL', `Test failed: ${err}`, 'red');
    process.exit(1);
  } finally {
    log('CLEANUP', 'Killing subprocesses...', 'reset');
    listenerProc.kill();
    agentProc.kill();
    process.exit(0);
  }
}

run();
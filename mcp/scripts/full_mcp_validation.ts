import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { buildAgentContext, handleToolCall } from '../src/agent_tools.ts';
import * as fs from 'fs';
import * as path from 'path';
import dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("\n" + "=".repeat(60));
  console.log(" 🚀 xB77 MISSION CONTROL: FULL STRESS TEST (DEVNET-100)");
  console.log("=".repeat(60) + "\n");

  // 1. Setup Environment
  const kpPath = path.resolve(process.cwd(), '../.devnet/deployer.json');
  const secretKey = Uint8Array.from(JSON.parse(fs.readFileSync(kpPath, 'utf-8')));
  const keypair = Keypair.fromSecretKey(secretKey);
  const connection = new Connection("https://api.devnet.solana.com", "confirmed");

  console.log(`[Identity] Loaded Agent: ${keypair.publicKey.toBase58()}`);
  console.log(`[Network] Connected to Solana Devnet (api.devnet.solana.com)`);
  
  const context = await buildAgentContext({
    keypair,
    offline: false,
    rpcUrl: "https://api.devnet.solana.com"
  });

  console.log("[System] Privacy Rails: ONLINE");
  console.log("[System] CFO Logic: CALIBRATED");
  console.log("[System] Helius Radar: ACTIVE\n");

  const results: Record<string, boolean> = {};

  async function testTool(name: string, args: any, section: string) {
    console.log(`[${section}] Dispatching ${name}...`);
    try {
      const response = await handleToolCall(context, name, args);
      if (response.isError) {
        console.error(`  ❌ Failed:`, response.content[0].text);
        results[name] = false;
        return null;
      }
      const data = JSON.parse(response.content[0].text);
      console.log(`  ✅ ${name} responded successfully.`);
      results[name] = true;
      return data;
    } catch (e) {
      console.error(`  ❌ Exception:`, e.message);
      if(e?.logs) console.error("LOGS->:",e.logs);
      results[name] = false;
      return null;
    }
  }

  // --- STEP 0: HELIUS DIAGNOSTIC ---
  console.log("[Diagnostic] Verifying Helius ZK Permissions...");
  const heliusKey = process.env.HELIUS_API_KEY;
  console.log("Heluis api key", heliusKey);
  if (heliusKey) {
    try {
      const diagRes = await fetch(`https://devnet.helius-rpc.com/?api-key=${heliusKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          id: 'diag',
          method: 'getCompressedBalanceByOwner',
          params: { owner: keypair.publicKey.toBase58() }
        })
      });
      const diagData = await diagRes.json();
      if (diagData.error) {
        console.warn(`[Diagnostic] Helius ZK Method failed: ${JSON.stringify(diagData.error)}`);
      } else {
        console.log(`[Diagnostic] Helius ZK Method OK. Balance: ${diagData.result?.balance || 0}`);
      }
    } catch (e) {
      console.warn(`[Diagnostic] Helius Fetch Exception: ${e.message}`);
    }
  }

  // --- STEP 1: SITUATIONAL AWARENESS ---
  console.log("-".repeat(40));
  console.log("PHASE 1: SITUATIONAL AWARENESS");
  console.log("-".repeat(40));
  await testTool('agent.status', {}, 'KNOWLEDGE');
  await testTool('cfo.treasury.snapshot', { token: 'USD1' }, 'CFO');

  // --- STEP 2: THREAT ANALYSIS & STRATEGY ---
  console.log("\n" + "-".repeat(40));
  console.log("PHASE 2: FORENSIC ANALYSIS & STRATEGY");
  console.log("-".repeat(40));
  const recipient = "E9Wx2TcTDPqFvT4VvYqkJ26XTYmxXHoVKmTkS9rDeibF";
  console.log(`[Forensics] Scanning recipient: ${recipient}...`);
  await testTool('agent.strategy.evaluate', {
    recipient,
    amount: 0.05,
    context: { vendorCategory: 'Privacy Infrastructure', isNewVendor: true }
  }, 'STRATEGY');

  // --- STEP 3: EXECUTION OF PRIVATE RAILS ---
  console.log("\n" + "-".repeat(40));
  console.log("PHASE 3: SHIELDED TRANSACTION EXECUTION");
  console.log("-".repeat(40));
  console.log(`[Privacy] Initiating atomic swap to xB77 Native (Light Protocol)...`);
  const payResult = await testTool('agent.pay', {
    recipient,
    amount: 5000000, // 0.005 SOL in lamports
    token: 'SOL',
    type: 'internal', // Trigger privacy rails
    provider: 'xb77'
  }, 'EXECUTION');

  //// --- STEP 4: ZK-AUDIT & VERIFICATION ---
  //console.log("\n" + "-".repeat(40));
  //console.log("PHASE 4: ZERO-KNOWLEDGE AUDIT RAIL");
  //console.log("-".repeat(40));
  //if (payResult && (payResult.txSignature || payResult.raw?.orderId)) {
  //  const receiptId = payResult.txSignature || "demo_receipt_id";
  //  console.log(`[Audit] Generating Selective Disclosure for TX: ${receiptId}...`);
  //  
  //  await testTool('agent.audit.report', {
  //    receiptId,
  //    fields: ['amount', 'timestamp', 'provider']
  //  }, 'AUDIT');

  //  console.log(`[ZK-Verifier] Pushing proof to Solana on-chain verifier...`);
  //  await testTool('agent.audit.verify_onchain', {
  //    receiptId,
  //    proof: "bm9pci1wcm9vZi1kZW1vLWJhc2U2NA==" 
  //  }, 'VERIFIER');
  //}

  //// --- STEP 5: OFF-RAMP & WEB2 BRIDGING ---
  //console.log("\n" + "-".repeat(40));
  //console.log("PHASE 5: WEB2 INTEROPERABILITY (STARPAY)");
  //console.log("-".repeat(40));
  //await testTool('agent.starpay.issue_card', {
  //  amount: 50,
  //  email: 'alpha-merchant@proton.me'
  //}, 'BRIDGE');

  //// --- SUMMARY ---
  //console.log("\n" + "=".repeat(60));
  //console.log(" 🏁 MISSION COMPLETE: STRESS TEST SUMMARY");
  //console.log("=".repeat(60));
  //
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(v => v).length;
  //
  //Object.entries(results).forEach(([tool, success]) => {
  //   console.log(`${success ? '✅' : '❌'} ${tool.padEnd(25)} : ${success ? 'OPERATIONAL' : 'FAILED'}`);
  //});

  //console.log("\n" + "-".repeat(60));
  //console.log(`Final Score: ${passed}/${total} Tools Operational`);
  //if (passed === total) {
  //  console.log("STATUS: BATTLE-READY. ZERO MOCKS DETECTED.");
  //} else {
  //  console.log("STATUS: DEGRADED. CHECK INDIVIDUAL FAILURES.");
  //}
  console.log("-".repeat(60) + "\n");
 
  process.exit(passed === total ? 0 : 1);
}

main().catch(console.error);

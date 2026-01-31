import { Keypair } from '@solana/web3.js';
import { buildAgentContext, handleToolCall } from '../src/agent_tools';

async function test() {
  const keypair = Keypair.generate();
  const context = await buildAgentContext({ offline: false, keypair });

  console.log("--- Testing cfo.treasury.snapshot ---");
  const snapshot = await handleToolCall(context, 'cfo.treasury.snapshot', { token: 'USD1' });
  console.log(JSON.stringify(snapshot, null, 2));

  console.log("\n--- Testing agent.pay (External Web2 Merchant -> Starpay) ---");
  const payWeb2 = await handleToolCall(context, 'agent.pay', {
    recipient: 'Amazon',
    amount: 50,
    token: 'USD1',
    type: 'external'
  });
  console.log(JSON.stringify(payWeb2, null, 2));

  console.log("\n--- Testing agent.pay (Internal -> ShadowWire) ---");
  const payInternal = await handleToolCall(context, 'agent.pay', {
    recipient: '55DaHZ4bmetUyT2KPqprC2VDBJ8agMw1ZwDjQCW387uA',
    amount: 20,
    token: 'USD1',
    type: 'internal'
  });
  console.log(JSON.stringify(payInternal, null, 2));

  console.log("\n--- Testing cfo.treasury.rebalance (Triggering rebalance) ---");
  // Set high threshold to trigger it
  context.agent.liquidityManager['config'].minLiquidityThreshold = 2000;
  context.agent.liquidityManager['config'].targetLiquidity = 3000;
  
  const rebalance = await handleToolCall(context, 'cfo.treasury.rebalance', { token: 'USD1' });
  console.log(JSON.stringify(rebalance, null, 2));

  console.log("\n--- Testing agent.pay (Compliance Block -> Amount too high) ---");
  const payHigh = await handleToolCall(context, 'agent.pay', {
    recipient: 'Amazon',
    amount: 6000,
    token: 'USD1',
    type: 'external'
  });
  console.log(JSON.stringify(payHigh, null, 2));
}

test().catch(console.error);

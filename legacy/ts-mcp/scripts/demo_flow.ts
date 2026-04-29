import { Keypair } from '@solana/web3.js';
import { buildAgentContext, handleToolCall } from '../src/agent_tools.ts';

async function main() {
  const context = await buildAgentContext({
    keypair: Keypair.generate(),
    offline: true,
    balances: { USD1: 2500 },
  });

  const recipient = Keypair.generate().publicKey.toBase58();
  const payResult = await handleToolCall(context, 'agent.pay', {
    recipient,
    amount: 125,
    token: 'USD1',
    type: 'external',
  });

  console.log('[demo] agent.pay', payResult.content[0].text);

  const latest = await handleToolCall(context, 'agent.receipts.latest', {});
  console.log('[demo] agent.receipts.latest', latest.content[0].text);

  const list = await handleToolCall(context, 'agent.receipts.list', { limit: 5 });
  console.log('[demo] agent.receipts.list', list.content[0].text);
}

main().catch((error) => {
  console.error('[demo] failed', error);
  process.exit(1);
});

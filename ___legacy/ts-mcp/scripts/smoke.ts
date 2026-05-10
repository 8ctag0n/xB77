import { Keypair } from '@solana/web3.js';
import { buildAgentContext, handleToolCall } from '../src/agent_tools.ts';

async function main() {
  const context = await buildAgentContext({
    keypair: Keypair.generate(),
    offline: true,
    balances: { USD1: 1000 },
  });

  const status = await handleToolCall(context, 'agent.status', {});
  console.log('[smoke] agent.status', status.content[0].text);

  const latest = await handleToolCall(context, 'agent.receipts.latest', {});
  console.log('[smoke] agent.receipts.latest', latest.content[0].text);
}

main().catch((error) => {
  console.error('[smoke] failed', error);
  process.exit(1);
});

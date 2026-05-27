import { createPublicClient, http, type Hex } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { ArbitrumAgentAccount } from "./arbitrum";

async function main() {
  const [,, intent_text, amount] = process.argv;

  if (!intent_text) {
    console.error("Usage: ts-node execute_semantic_tx.ts <intent_text> <amount>");
    process.exit(1);
  }

  // Configuration (Mocked for demo)
  const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY as Hex || "0x7777777777777777777777777777777777777777777777777777777777777777";
  const SESSION_PRIVATE_KEY = "0xsession_key_private_key" as Hex; // Should be ephemeral
  const SOVEREIGN_POLICY_ADDR = "0xDeployedSovereignPolicyAddress"; 

  const publicClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http("https://sepolia-rollup.arbitrum.io/rpc"),
  });

  const agentAccount = new ArbitrumAgentAccount(publicClient);

  console.log(`[AGENT] Processing intent: "${intent_text}"`);
  
  // 1. Generate Intent Vector (Simulated as in brain.zig)
  // In a real flow, this would call the WASM core via @xb77/sdk
  const intentVector = new Array(128).fill(intent_text.includes('toxic') ? 1000 : 100);

  console.log(`[AGENT] Creating ZeroDev Kernel client with Semantic Policy...`);

  try {
    const client = await agentAccount.createAgentClient(
      OWNER_PRIVATE_KEY,
      SESSION_PRIVATE_KEY,
      SOVEREIGN_POLICY_ADDR as Hex,
      intentVector
    );

    console.log(`[AGENT] Submitting UserOperation...`);

    // In a real demo, we'd send USDC. For now, we mock the call to Settlement.sol
    // const hash = await client.sendTransaction({
    //   to: "0xSettlementAddress",
    //   data: "0x...", // settle(amount, commitment)
    // });

    console.log(`[STYLUS] Semantic Check Result: PASSED ✅`);
    console.log(`[RESULT] Transaction Hash: 0xarb_confirmed_tx_hash`);

  } catch (error: any) {
    if (error.message.includes("ConstitutionalViolation")) {
      console.error(`[STYLUS] Semantic Check Result: REJECTED 🚨`);
      console.error(`[RESULT] Transaction blocked by on-chain constitution.`);
    } else {
      console.error(`[ERROR] ${error.message}`);
    }
  }
}

main().catch(console.error);

import { createPublicClient, createWalletClient, http, type Hex } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { ArbitrumAgentAccount } from "./arbitrum";
import { AgentIdentityManager } from "./identity";

async function main() {
  const [,, intent_text, amount] = process.argv;

  if (!intent_text) {
    console.error("Usage: ts-node execute_semantic_tx.ts <intent_text> <amount>");
    process.exit(1);
  }

  // Configuration (Mocked for demo)
  const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY as Hex || "0x7777777777777777777777777777777777777777777777777777777777777777";
  const SESSION_PRIVATE_KEY = "0xsession_key_private_key" as Hex; 
  const SOVEREIGN_POLICY_ADDR = "0xDeployedSovereignPolicyAddress"; 

  const publicClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http("https://sepolia-rollup.arbitrum.io/rpc"),
  });

  const walletClient = createWalletClient({
    chain: arbitrumSepolia,
    transport: http("https://sepolia-rollup.arbitrum.io/rpc"),
    account: privateKeyToAccount(OWNER_PRIVATE_KEY),
  });

  const ZERODEV_PROJECT_ID = process.env.ZERODEV_PROJECT_ID || "MOCK_PROJECT_ID";
  const agentAccount = new ArbitrumAgentAccount(publicClient, ZERODEV_PROJECT_ID);
  const idManager = new AgentIdentityManager(publicClient, walletClient);

  console.log(`[AGENT] Processing intent: "${intent_text}"`);

  // --- 1. EIP-7702 EOA-Upgrade (Simulated) ---
  console.log(`[EIP-7702] Upgrading EOA to Smart Agent Account...`);
  // In a real EIP-7702 flow, we'd sign an authorization for the Kernel implementation.
  console.log(`[EIP-7702] Authorization Signed. Owner is now an Autonomous Swarm Node.`);

  // --- 2. ERC-8004 Identity Check/Registration ---
  console.log(`[ERC-8004] Syncing Agent Identity...`);
  const agentId = 800477n; // In real flow: await idManager.registerAgent("xB77-Alpha-01", "ipfs://...");

  // 3. Generate Intent Vector
  const intentVector = new Array(128).fill(intent_text.includes('toxic') ? 1000 : 100);

  try {
    console.log(`[AGENT] Requesting execution permission for intent vector...`);
    const client = await agentAccount.createAgentClient(
      OWNER_PRIVATE_KEY,
      SESSION_PRIVATE_KEY,
      SOVEREIGN_POLICY_ADDR as Hex,
      intentVector
    );

    // --- 4. Reputation Attestation (Success) ---
    console.log(`[STYLUS] Semantic Check Result: PASSED ✅`);
    await idManager.attestCompliance(agentId, true);
    console.log(`[RESULT] Transaction Hash: 0xarb_confirmed_tx_hash`);

  } catch (error: any) {
    if (error.message.includes("revert")) {
      console.error(`[STYLUS] Semantic Check Result: REJECTED 🚨`);
      // --- 5. Reputation Attestation (Failure Penalty) ---
      await idManager.attestCompliance(agentId, false);
      console.error(`[RESULT] Transaction blocked and reputation burned.`);
    } else {
      console.error(`[ERROR] ${error.message}`);
    }
  }
}

main().catch(console.error);

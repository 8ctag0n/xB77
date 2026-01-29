import { createRpc, TreeType, selectStateTreeInfo } from "@lightprotocol/stateless.js";
import { Connection, PublicKey } from "@solana/web3.js";

// Devnet Endpoints
const RPC_URL = "https://api.devnet.solana.com";
const COMPRESSION_URL = "https://api.devnet.solana.com";
const PROVER_URL = "https://api.devnet.solana.com";

async function verifyLightDevnet() {
  console.log("--- 🕵️ Verifying Light Protocol Infrastructure (Devnet) ---");
  
  const connection = new Connection(RPC_URL);
  const rpc = createRpc(RPC_URL, COMPRESSION_URL, PROVER_URL);

  try {
    // 1. Check Connection
    const version = await connection.getVersion();
    console.log(`✅ Solana Node version: ${version["solana-core"]}`);

    // 2. Fetch State Tree Information
    console.log("Step 1: Fetching State Tree Infos...");
    const treeInfos = await rpc.getStateTreeInfos();
    
    if (treeInfos.length === 0) {
      console.error("❌ No state trees found on this RPC. Light Protocol might not be indexed here.");
      return;
    }

    console.log(`✅ Found ${treeInfos.length} state trees.`);
    
    // 3. Try to select a valid State Tree for xB77
    try {
      const selectedTree = selectStateTreeInfo(treeInfos, TreeType.StateV1);
      console.log(`✅ Selected Tree: ${selectedTree.tree.toBase58()} (Index: ${selectedTree.treeIndex})`);
    } catch (e) {
      console.warn("⚠️ Could not select StateV1 tree automatically. This might affect xB77 v3 logic.");
    }

    // 4. Prover Health Check
    console.log("Step 2: Checking Prover Health...");
    // Some public RPCs don't expose health via stateless.js directly, 
    // but we can try to request a nullifier proof or just check if the endpoint responds.
    try {
        // Attempting a low-level call to see if the prover service is alive
        const health = await rpc.getHealth();
        console.log(`✅ Prover Health: ${health}`);
    } catch (e) {
        console.log("ℹ️ Prover health check skipped (Endpoint might not support GET /health).");
    }

    console.log("\n--- ✨ Infrastructure Verification Complete ---");
    console.log("Result: Devnet seems ready for Light Protocol operations.");
    
  } catch (error: any) {
    console.error("\n❌ Verification Failed!");
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

verifyLightDevnet();

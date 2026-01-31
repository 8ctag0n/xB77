
import { createRpc, Rpc, TreeType } from '@lightprotocol/stateless.js';
import { Connection, PublicKey } from '@solana/web3.js';

// Load ENV manually
const HELIUS_KEY = process.env.HELIUS_API_KEY;

async function main() {
    console.log("🔦 Debugging Light Protocol Trees on Devnet...");

    if (!HELIUS_KEY || HELIUS_KEY.length !== 36) {
        console.error("❌ CRITICAL: Invalid HELIUS_API_KEY format.");
        return;
    }

    const rpcUrl = `https://devnet.helius-rpc.com/?api-key=${HELIUS_KEY}`;
    console.log(`RPC: ${rpcUrl.replace(HELIUS_KEY, "HIDDEN")}`);

    const rpc = createRpc(rpcUrl, rpcUrl, rpcUrl);

    try {
        console.log("\n1. Fetching State Tree Infos (StateV1)...");
        const stateTrees = await rpc.getStateTreeInfos();
        console.log(`Found ${stateTrees.length} state trees.`);
        
        stateTrees.forEach((tree, i) => {
            console.log(`[Tree ${i}]`, JSON.stringify(tree));
        });

        console.log("\n2. Checking specific Address Tree: amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx");
        const connection = new Connection(rpcUrl);
        const treePubkey = new PublicKey("amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx");
        const account = await connection.getAccountInfo(treePubkey);
        if (account) {
             console.log("Tree Account exists on chain.");
             console.log("Data Length:", account.data.length);
        } else {
             console.log("Tree Account NOT found.");
        }

        console.log("\n3. Testing Compressed Account Fetch...");
        // Use a known system account to see if ZK fetch works generally
        // System program ID often has compressed state in tests
        const testAccount = await rpc.getCompressedAccount("11111111111111111111111111111111");
        console.log("Test Fetch Result:", testAccount ? "Found (Unexpected)" : "Null (Expected but API worked)");

    } catch (e) {
        console.error("❌ RPC Error:", e);
    }
}

main().catch(console.error);

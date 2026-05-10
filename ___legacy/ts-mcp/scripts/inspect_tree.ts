
import dotenv from 'dotenv';
import { Connection, PublicKey } from '@solana/web3.js';
import * as borsh from '@coral-xyz/borsh';

dotenv.config();
const HELIUS_KEY = process.env.HELIUS_KEY;
if (!HELIUS_KEY) {
    throw new Error('Missing HELIUS_KEY in environment');
}
const RPC_URL = `https://devnet.helius-rpc.com/?api-key=${HELIUS_KEY}`;

async function inspectTree(address: string) {
    const connection = new Connection(RPC_URL);
    const pubkey = new PublicKey(address);

    console.log(`\n🔍 Inspecting Tree: ${address}`);
    
    const accountInfo = await connection.getAccountInfo(pubkey);

    if (!accountInfo) {
        console.error("❌ Account not found!");
        return;
    }

    console.log(`✅ Account Found!`);
    console.log(`- Owner: ${accountInfo.owner.toBase58()}`);
    console.log(`- Data Length: ${accountInfo.data.length} bytes`);
    console.log(`- Lamports: ${accountInfo.lamports}`);

    const data = accountInfo.data;
    const discriminator = data.subarray(0, 8);
    console.log(`- Discriminator (Hex): ${discriminator.toString('hex')}`);

    // Light Protocol Discriminators (approximate based on plan)
    // We can try to guess or just analyze the array
    
    // If it's a BatchedAddressTree, it might have a 'root_history' or 'roots' array.
    // Let's try to find where the roots might be.
    // A root is 32 bytes.
    // We are looking for where index 181 might fall.
    
    // Let's dump the first 100 bytes to see structure
    console.log(`- First 64 bytes: ${data.subarray(0, 64).toString('hex')}`);

    // Assuming some header size.
    // Try to detect non-zero regions which might indicate the roots array.
    
    // Calculate max possible roots if the whole file was roots
    const maxRoots = Math.floor(accountInfo.data.length / 32);
    console.log(`- Max theoretical capacity (if 100% data): ${maxRoots} roots`);

    // We want to check index 181. 
    // 181 * 32 = 5792 bytes.
    // Plus header offset.
    
    // Let's look at the bytes around where index 181 would be if offset was small (e.g. 8 bytes or 100 bytes).
    // offset 8 + 181 * 32 = 5800.
    
    if (data.length > 5800 + 32) {
        const potentialRoot = data.subarray(5800, 5800 + 32);
        console.log(`- Potential Root at index 181 (offset ~8): ${potentialRoot.toString('hex')}`);
    } else {
        console.log("⚠️ File too small for simple index 181 at offset 8.");
    }

    // Try to decode using a generic schema if possible or just heuristic
    // If we assume a Cyclic Buffer (common in Solana queues), there might be a head/tail index at the start.
    
    // Let's look for u64 or u32s at the start.
    const firstU64 = data.readBigUInt64LE(8); // Skip 8 byte discriminator
    const secondU64 = data.readBigUInt64LE(16);
    
    console.log(`- U64 at offset 8: ${firstU64}`);
    console.log(`- U64 at offset 16: ${secondU64}`);
}

async function main() {
    await inspectTree("amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx");
    await inspectTree("amt1Ayt45jfbdw5YSo7iz6WZxUmnZsQTYXy82hVwyC2");
}

main().catch(console.error);

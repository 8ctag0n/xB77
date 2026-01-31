
import dotenv from 'dotenv';
import { PublicKey } from '@solana/web3.js';
import { deriveAddressV2, deriveAddressSeedV2 } from '@lightprotocol/stateless.js';
import { createHash } from 'crypto';

dotenv.config();
const HELIUS_KEY = process.env.HELIUS_KEY;
if (!HELIUS_KEY) {
    throw new Error('Missing HELIUS_KEY in environment');
}
const RPC_URL = `https://devnet.helius-rpc.com/?api-key=${HELIUS_KEY}`;

// Constants from receipts_light.ts
const RECEIPT_PROGRAM_ID = new PublicKey('6LM5tQioTsog9AmiHbXBN69YrFBzzhspVWyxBvxKZss3');
const RECEIPT_ADDRESS_SEED = new TextEncoder().encode('receipt');

// Inputs causing the crash (mocked)
const vendorName = 'Starpay Merchant 123';
const memo = 'Starpay TX: tx-12345';
const vendor = createHash('sha256').update(vendorName).digest();
const memoHash = createHash('sha256').update(memo).digest();

const TREE_ADDRESS = "amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx";
const QUEUE_ADDRESS = "aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F";

async function main() {
    console.log("🔍 Checking Validity Proof from Helius...");
    
    // 1. Derive Address
    const seeds = [RECEIPT_ADDRESS_SEED, vendor, memoHash];
    const addressSeed = deriveAddressSeedV2(seeds);
    const treePubkey = new PublicKey(TREE_ADDRESS);
    const derivedAddress = deriveAddressV2(addressSeed, treePubkey, RECEIPT_PROGRAM_ID);
    
    console.log(`- Derived Address: ${derivedAddress.toBase58()}`);
    console.log(`- Tree: ${TREE_ADDRESS}`);

    const payload = {
        jsonrpc: "2.0",
        id: "test-proof",
        method: "getValidityProof",
        params: [
            [], 
            [
                {
                    tree: TREE_ADDRESS,
                    queue: QUEUE_ADDRESS,
                    address: derivedAddress.toBase58()
                }
            ]
        ]
    };

    const response = await fetch(RPC_URL, {
        method: "POST",
        body: JSON.stringify(payload),
        headers: { "Content-Type": "application/json" }
    });

    const json = await response.json();
    console.log("RPC Response:", JSON.stringify(json, null, 2));
}

main().catch(console.error);

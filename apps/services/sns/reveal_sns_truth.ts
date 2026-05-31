import { getDomainKeySync, NAME_PROGRAM_ID } from "@bonfida/spl-name-service";
import { Connection, PublicKey } from "@solana/web3.js";
import * as bs58 from "bs58";

async function main() {
    const domain = "bonfida.sol";
    console.log(`Resolving: ${domain}`);

    // getDomainKeySync handles the hashing and derivation logic
    const result = getDomainKeySync(domain);
    const pubkey = result.pubkey;
    const hashed = result.hashed;

    console.log(`1. Registry Account Address: ${pubkey.toBase58()}`);
    
    // We need a connection to fetch the owner from the registry
    const connection = new Connection("https://api.mainnet-beta.solana.com");
    const accountInfo = await connection.getAccountInfo(pubkey);

    if (accountInfo) {
        // The owner is stored in the data. 
        // SPL Name Service Registry Layout:
        // Parent (32 bytes), Owner (32 bytes), Class (32 bytes), Data...
        const owner = new PublicKey(accountInfo.data.slice(32, 64));
        console.log(`2. Owner: ${owner.toBase58()}`);
    } else {
        console.log("2. Owner: Account not found on-chain");
    }

    console.log(`3. Hashed Name: ${hashed.toString('hex')}`);

    const parent = result.parent;
    console.log(`Parent Registry: ${parent.toBase58()}`);

    // In SPL Name Service, the seeds are: [hashedName, nameClass, nameParent]
    // nameClass is usually SystemProgram (all zeros) for domains.
    const nameClass = PublicKey.default; 
    
    console.log(`4. Seeds:`);
    console.log(`   - Hashed Name (hex): ${hashed.toString('hex')}`);
    console.log(`   - Name Class: ${nameClass.toBase58()}`);
    console.log(`   - Name Parent: ${parent.toBase58()}`);

    console.log(`5. Program ID: ${NAME_PROGRAM_ID.toBase58()}`);

    // Manual derivation check with 3 seeds
    const [derivedKey, bump] = PublicKey.findProgramAddressSync(
        [hashed, nameClass.toBuffer(), parent.toBuffer()],
        NAME_PROGRAM_ID
    );
    console.log(`Manual derivation check (3 seeds): ${derivedKey.toBase58()} (bump: ${bump})`);
    
    if (derivedKey.toBase58() === pubkey.toBase58()) {
        console.log("Derivation matches: [hashed, nameClass, nameParent] are the seeds.");
    } else {
        console.log("Derivation mismatch still!");
    }
}

main().catch(console.error);

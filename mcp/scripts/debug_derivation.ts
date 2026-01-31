import { PublicKey } from '@solana/web3.js';
import { deriveAddressV2, deriveAddressSeedV2 } from '@lightprotocol/stateless.js';

const PROGRAM_ID = new PublicKey("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
const ADDRESS_TREE = new PublicKey("amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx");

// From Client Log:
// [Client] Seeds Components: receipt, c356708b..., afe065f4...
// Hex: c356708b... corresponds to the first 4 bytes of vendor?
// Let's rely on the fact that I can reproduce the "Client" derivation if I know the inputs.

// But wait, I can just use the exact inputs from the user's log if I had the full hex.
// The user provided:
// [DEBUGGEANDO PARCERO] [
//   Uint8Array(7) [ 114, 101, 99, 101, 105, 112, 116 ], 
//   Uint8Array(32) [ 195, 86, 112, 139, 134, 131, 26, 225, 201, 242, 114, 234, 152, 141, 41, 153, 145, 208, 46, 200, 93, 245, 173, 49, 208, 231, 61, 149, 108, 68, 114, 46 ], 
//   Uint8Array(32) [ 175, 224, 101, 244, 89, 81, 206, 63, 130, 191, 145, 61, 255, 91, 194, 37, 124, 251, 173, 45, 206, 120, 62, 194, 189, 63, 51, 159, 255, 241, 24, 224 ]
// ]

const SEED_RECEIPT = new Uint8Array([114, 101, 99, 101, 105, 112, 116]);
const SEED_VENDOR = new Uint8Array([195, 86, 112, 139, 134, 131, 26, 225, 201, 242, 114, 234, 152, 141, 41, 153, 145, 208, 46, 200, 93, 245, 173, 49, 208, 231, 61, 149, 108, 68, 114, 46]);
const SEED_MEMO = new Uint8Array([175, 224, 101, 244, 89, 81, 206, 63, 130, 191, 145, 61, 255, 91, 194, 37, 124, 251, 173, 45, 206, 120, 62, 194, 189, 63, 51, 159, 255, 241, 24, 224]);

async function main() {
    console.log("Replicating Derivation...");

    const seeds = [SEED_RECEIPT, SEED_VENDOR, SEED_MEMO];
    
    // 1. Derive Seed (V2)
    const addressSeed = deriveAddressSeedV2(seeds);
    console.log("Derived Seed:", addressSeed);

    // 2. Derive Address (V2)
    const address = deriveAddressV2(addressSeed, ADDRESS_TREE, PROGRAM_ID);
    console.log("Derived Address:", address.toBase58());

    console.log("\nComparison:");
    console.log("Client Got:  14EMkWiymmSPW7SLFZeuXTjt6tjEUcNjgjtqNmAjJAHz");
    console.log("OnChain Got: 1gtQp75Far5bndU1t8ePsXTR2BVJopewWEu57njjKvP");
}

main();

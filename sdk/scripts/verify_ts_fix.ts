
import { keccak_256 } from '@noble/hashes/sha3';
import { PublicKey } from '@solana/web3.js';
import { deriveAddressV2,deriveAddressSeedV2 } from '@lightprotocol/stateless.js';

// TEST DATA from Rust Test
const programId = new PublicKey("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
const addressTree = new PublicKey("CCa2h58a36K2d6zJ6Sj45UjS2u9K5K3h2u5K5K3h2u5K");
const vendor = new Uint8Array(32).fill(1);
const memoHash = new Uint8Array(32).fill(2);

const RECEIPT_ADDRESS_SEED = new TextEncoder().encode('receipt');
const EXPECTED_SEED_HEX = "00c6ae5354205a4435e4879fdcc5537c748da44c4fb7fd88fa1552887bf56b6d";
const EXPECTED_ADDRESS = "14eu9cgRTwY1eUfwdDUYuwi1uHc5Hys8mvh8spK4jZ6s";

// IMPLEMENTATION TO TEST
// Rust: hash(program_id); hash("receipt"); hash(vendor); hash(memo); -> result[0]=0;

const seeds = [RECEIPT_ADDRESS_SEED, vendor, memoHash];

const seedHex = deriveAddressSeedV2(seeds)
console.log(`Calculated Seed: ${seedHex}`);
console.log(`Expected Seed:   ${EXPECTED_SEED_HEX}`);

if (seedHex.toHex() !== EXPECTED_SEED_HEX) {
    console.error("❌ SEED MISMATCH");
} else {
    console.log("✅ SEED MATCH");
}

const derivedAddress = deriveAddressV2(seedHex, addressTree, programId);
console.log(`Calculated Addr: ${derivedAddress.toBase58()}`);
console.log(`Expected Addr:   ${EXPECTED_ADDRESS}`);

if (derivedAddress.toBase58() !== EXPECTED_ADDRESS) {
    console.error("❌ ADDRESS MISMATCH");
} else {
    console.log("✅ ADDRESS MATCH");
}

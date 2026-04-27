
import { deriveAddressSeedV2 } from '@lightprotocol/stateless.js';
import { PublicKey } from '@solana/web3.js';
import { keccak_256 } from '@noble/hashes/sha3';

const vendor = new Uint8Array(32).fill(1);
const memoHash = new Uint8Array(32).fill(2);
const receiptSeed = new TextEncoder().encode('receipt');
const programId = new PublicKey("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");

const seeds = [receiptSeed, vendor, memoHash];

// 1. TS Library Derivation
const tsSeed = deriveAddressSeedV2(seeds);
console.log("TS Library Seed:", Buffer.from(tsSeed).toString('hex'));

// 2. Manual Keccak (No PID)
const combinedNoPid = new Uint8Array(receiptSeed.length + vendor.length + memoHash.length);
combinedNoPid.set(receiptSeed, 0);
combinedNoPid.set(vendor, receiptSeed.length);
combinedNoPid.set(memoHash, receiptSeed.length + vendor.length);
const manualHashNoPid = keccak_256(combinedNoPid);
manualHashNoPid[0] = 0; // Simulate zeroing
console.log("Manual Keccak (No PID):", Buffer.from(manualHashNoPid).toString('hex'));

// 3. Manual Keccak (With PID First)
const pidBytes = programId.toBytes();
const combinedWithPid = new Uint8Array(pidBytes.length + receiptSeed.length + vendor.length + memoHash.length);
combinedWithPid.set(pidBytes, 0);
combinedWithPid.set(receiptSeed, pidBytes.length);
combinedWithPid.set(vendor, pidBytes.length + receiptSeed.length);
combinedWithPid.set(memoHash, pidBytes.length + receiptSeed.length + vendor.length);
const manualHashWithPid = keccak_256(combinedWithPid);
manualHashWithPid[0] = 0; // Simulate zeroing
console.log("Manual Keccak (With PID):", Buffer.from(manualHashWithPid).toString('hex'));

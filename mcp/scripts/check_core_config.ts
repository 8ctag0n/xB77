import { Connection, PublicKey } from '@solana/web3.js';
import { Buffer } from 'buffer';

const CORE_PROGRAM_ID = new PublicKey('FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv');
const RPC_URL = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';

async function main() {
    console.log(`Checking Core Config on ${RPC_URL}...`);
    const connection = new Connection(RPC_URL);
    const [configPda] = PublicKey.findProgramAddressSync([Buffer.from("config_v3")], CORE_PROGRAM_ID);
    console.log(`Config PDA: ${configPda.toBase58()}`);

    const info = await connection.getAccountInfo(configPda);
    if (!info) {
        console.error("Config Account not found!");
        return;
    }

    // Layout from InitCorePayload in instruction.rs (Wincode / simple struct):
    // pub admin: [u8; 32],
    // pub gateway_program: [u8; 32],
    // pub receipts_program: [u8; 32],
    // pub treasury_mint: [u8; 32],
    
    if (info.data.length < 128) {
        console.error(`Data length mismatch. Expected >= 128, got ${info.data.length}`);
    }

    const admin = new PublicKey(info.data.subarray(0, 32));
    const gateway = new PublicKey(info.data.subarray(32, 64));
    const receipts = new PublicKey(info.data.subarray(64, 96));
    const mint = new PublicKey(info.data.subarray(96, 128));

    console.log(`Admin: ${admin.toBase58()}`);
    console.log(`Gateway: ${gateway.toBase58()}`);
    console.log(`Receipts: ${receipts.toBase58()}`);
    console.log(`Treasury Mint: ${mint.toBase58()}`);

    const EXPECTED_RECEIPTS = "8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W";
    if (receipts.toBase58() !== EXPECTED_RECEIPTS) {
        console.error(`
CRITICAL: Receipts Program ID mismatch!`);
        console.error(`Current Config: ${receipts.toBase58()}`);
        console.error(`Expected:       ${EXPECTED_RECEIPTS}`);
        process.exit(1);
    } else {
        console.log("\nReceipts Program ID matches. Config is correct.");
    }
}

main();

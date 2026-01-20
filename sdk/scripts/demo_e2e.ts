import { Connection, Keypair, PublicKey, Transaction, TransactionInstruction, sendAndConfirmTransaction } from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import { struct, u32, u8, u64, vec, array } from '@coral-xyz/borsh';

// --- Configuration ---
const RPC_URL = 'http://127.0.0.1:8899';
const KEYPAIRS_DIR = path.resolve(__dirname, '../../.localnet/keypairs');
const PAYER_KEYPAIR_PATH = path.resolve(__dirname, '../../.localnet/payer.json');

// --- Helper Functions ---
function loadKeypair(filePath: string): Keypair {
    const secretKey = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    return Keypair.fromSecretKey(new Uint8Array(secretKey));
}

function getProgramId(name: string): PublicKey {
    try {
        return loadKeypair(path.join(KEYPAIRS_DIR, `${name}.json`)).publicKey;
    } catch (e) {
        console.error(`Program keypair for ${name} not found. Did you run deploy-all.sh?`);
        process.exit(1);
    }
}

// --- Borsh Layouts (Automatic Serialization) ---

// Custom Layout for PublicKey (32 bytes)
const publicKeyLayout = (property: string) => {
    return {
        decode: (buffer: Buffer, offset = 0) => {
            const pubkey = new PublicKey(buffer.slice(offset, offset + 32));
            return [pubkey, offset + 32];
        },
        encode: (pubkey: PublicKey, buffer: Buffer, offset = 0) => {
            pubkey.toBuffer().copy(buffer, offset);
            return offset + 32;
        },
        span: 32,
        property,
    };
};

// Instruction Schemas
// Note: We use 'u32' for the Enum discriminator (Wincode default for enums is u32)

const InitCoreLayout = struct([
    u32('instruction'), // 0
    publicKeyLayout('admin'),
    publicKeyLayout('gateway_program'),
    publicKeyLayout('receipts_program'),
    publicKeyLayout('treasury_mint'),
]);

const RegisterAgentLayout = struct([
    u32('instruction'), // 1
    publicKeyLayout('agent_id'),
    u64('initial_limit'),
]);

const VerifyBadgeLayout = struct([
    u32('instruction'), // 2
    array(u8(), 32, 'root'),
    u32('merkle_index'),
    vec(u8(), 'proof'),
    vec(u8(), 'public_witness'),
]);

// --- Main Script ---
async function main() {
    const connection = new Connection(RPC_URL, 'confirmed');
    const payer = loadKeypair(PAYER_KEYPAIR_PATH);
    const coreProgramId = getProgramId('xb77_core');
    const gatewayProgramId = getProgramId('xb77_gateway');

    console.log('--- Config ---');
    console.log('Payer:', payer.publicKey.toBase58());
    console.log('Core ID:', coreProgramId.toBase58());
    console.log('Gateway ID:', gatewayProgramId.toBase58());

    // --- 1. Init Core ---
    console.log('\n--- 1. Init Core ---');
    const [coreConfigPda] = PublicKey.findProgramAddressSync([Buffer.from("config")], coreProgramId);
    
    const coreConfigInfo = await connection.getAccountInfo(coreConfigPda);
    if (!coreConfigInfo) {
        console.log('Initializing Core...');
        
        const buffer = Buffer.alloc(1000); // Alloc enough space
        const len = InitCoreLayout.encode({
            instruction: 0, // InitCore
            admin: payer.publicKey,
            gateway_program: gatewayProgramId,
            receipts_program: PublicKey.default, // Placeholder
            treasury_mint: PublicKey.default,    // Placeholder
        }, buffer);

        const initIx = new TransactionInstruction({
            programId: coreProgramId,
            keys: [
                { pubkey: coreConfigPda, isSigner: false, isWritable: true },
                { pubkey: payer.publicKey, isSigner: true, isWritable: true },
            ],
            data: buffer.slice(0, len),
        });
        
        try {
            const tx = new Transaction().add(initIx);
            const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
            console.log('Core Initialized:', sig);
        } catch (e) {
            console.error("Init Core Failed:", e);
        }
    } else {
        console.log('Core already initialized.');
    }

    // --- 2. Register Agent ---
    console.log('\n--- 2. Register Agent ---');
    const agent = payer; 
    const [creditLinePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("credit_line"), agent.publicKey.toBuffer()],
        coreProgramId
    );
    
    const creditInfo = await connection.getAccountInfo(creditLinePda);
    if (!creditInfo) {
        console.log('Registering Agent...');
        
        const buffer = Buffer.alloc(1000);
        const len = RegisterAgentLayout.encode({
            instruction: 1, // RegisterAgent
            agent_id: agent.publicKey,
            initial_limit: 10000n, // BN or BigInt depending on Borsh version, usually BN for @coral-xyz/borsh < 1.0
        }, buffer);

        const regIx = new TransactionInstruction({
            programId: coreProgramId,
            keys: [
                { pubkey: coreConfigPda, isSigner: false, isWritable: false },
                { pubkey: creditLinePda, isSigner: false, isWritable: true },
                { pubkey: payer.publicKey, isSigner: true, isWritable: true },
            ],
            data: buffer.slice(0, len),
        });

        try {
            const tx = new Transaction().add(regIx);
            const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
            console.log('Agent Registered:', sig);
        } catch (e) {
            console.error("Register Agent Failed:", e);
        }
    } else {
        console.log('Agent already registered.');
    }

    // --- 3. Verify Badge (Gateway -> Core CPI) ---
    console.log('\n--- 3. Verify Badge (CPI) ---');
    const [gatewayStatePda] = PublicKey.findProgramAddressSync([Buffer.from("gateway_state")], gatewayProgramId);

    // Ensure Gateway Init (Simplified check)
    // ... skipping explicit init check for demo speed, assume deployed means ready or we'd init it.

    const buffer = Buffer.alloc(2000);
    const len = VerifyBadgeLayout.encode({
        instruction: 2, // VerifyBadge
        root: Array(32).fill(0), // Mock Root
        merkle_index: 0,
        proof: Buffer.from([1, 2, 3]), // Mock Proof
        public_witness: Buffer.from([4, 5, 6]), // Mock Witness
    }, buffer);

    const verifyIx = new TransactionInstruction({
        programId: gatewayProgramId,
        keys: [
            { pubkey: payer.publicKey, isSigner: true, isWritable: true },
            { pubkey: gatewayStatePda, isSigner: false, isWritable: true },
            { pubkey: PublicKey.default, isSigner: false, isWritable: false }, // ZK Verifier
            // --- CPI Accounts ---
            { pubkey: coreProgramId, isSigner: false, isWritable: false }, // Executable
            { pubkey: coreConfigPda, isSigner: false, isWritable: false },
            { pubkey: creditLinePda, isSigner: false, isWritable: true },
        ],
        data: buffer.slice(0, len),
    });

    try {
        const tx = new Transaction().add(verifyIx);
        const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
        console.log('VerifyBadge (CPI) Success:', sig);
    } catch (e) {
        console.error('VerifyBadge Failed (Check logs):', e);
    }

    // --- 4. Check Credit Balance ---
    const updatedCreditInfo = await connection.getAccountInfo(creditLinePda);
    if (updatedCreditInfo) {
        // Deserialize State
        const CreditLineState = struct([
            publicKeyLayout('owner'),
            u64('balance'),
            u64('credit_limit'),
            // ... other fields
        ]);
        try {
            const state = CreditLineState.decode(updatedCreditInfo.data);
            console.log(`Updated Agent Balance: ${state.balance.toString()}`);
        } catch (e) {
            console.log("Could not decode credit state (might be partial or different layout):", e);
            // Fallback manual read if layout mismatch
            console.log("Raw Balance (offset 32):", updatedCreditInfo.data.readBigUInt64LE(32));
        }
    }
}

main().catch(console.error);

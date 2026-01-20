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

const InitCoreLayout = struct([
    u32('instruction'),
    publicKeyLayout('admin'),
    publicKeyLayout('gateway_program'),
    publicKeyLayout('receipts_program'),
    publicKeyLayout('treasury_mint'),
]);

const RegisterAgentLayout = struct([
    u32('instruction'),
    publicKeyLayout('agent_id'),
    u64('initial_limit'),
]);

const VerifyBadgeLayout = struct([
    u32('instruction'),
    array(u8(), 32, 'root'),
    u32('merkle_index'),
    vec(u8(), 'proof'),
    vec(u8(), 'public_witness'),
]);

const RequestPaymentLayout = struct([
    u32('instruction'),
    u64('request_id'),
    u64('amount'),
    array(u8(), 32, 'vendor'),
    array(u8(), 32, 'memo_hash'),
    vec(u8(), 'proof'),
    vec(u8(), 'address_tree_info'),
    u8('output_state_tree_index'),
]);

async function main() {
    const connection = new Connection(RPC_URL, 'confirmed');
    const payer = loadKeypair(PAYER_KEYPAIR_PATH);
    const coreProgramId = getProgramId('xb77_core');
    const gatewayProgramId = getProgramId('xb77_gateway');
    const receiptsProgramId = getProgramId('xb77_receipts');

    console.log('--- Config ---');
    console.log('Payer:', payer.publicKey.toBase58());
    console.log('Core ID:', coreProgramId.toBase58());
    console.log('Gateway ID:', gatewayProgramId.toBase58());
    console.log('Receipts ID:', receiptsProgramId.toBase58());

    const [coreConfigPda] = PublicKey.findProgramAddressSync([Buffer.from("config")], coreProgramId);
    
    // 1. Init Core
    console.log('\n--- 1. Init Core ---');
    const coreConfigInfo = await connection.getAccountInfo(coreConfigPda);
    if (!coreConfigInfo) {
        const buffer = Buffer.alloc(1000);
        const len = InitCoreLayout.encode({
            instruction: 0,
            admin: payer.publicKey,
            gateway_program: gatewayProgramId,
            receipts_program: receiptsProgramId,
            treasury_mint: PublicKey.default,
        }, buffer);

        const initIx = new TransactionInstruction({
            programId: coreProgramId,
            keys: [
                { pubkey: coreConfigPda, isSigner: false, isWritable: true },
                { pubkey: payer.publicKey, isSigner: true, isWritable: true },
            ],
            data: buffer.slice(0, len),
        });
        const tx = new Transaction().add(initIx);
        await sendAndConfirmTransaction(connection, tx, [payer]);
        console.log('Core Initialized');
    } else {
        console.log('Core already initialized');
    }

    // 2. Register Agent
    console.log('\n--- 2. Register Agent ---');
    const agent = payer; 
    const [creditLinePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("credit_line"), agent.publicKey.toBuffer()],
        coreProgramId
    );
    const creditInfo = await connection.getAccountInfo(creditLinePda);
    if (!creditInfo) {
        const buffer = Buffer.alloc(1000);
        const len = RegisterAgentLayout.encode({
            instruction: 1,
            agent_id: agent.publicKey,
            initial_limit: 10000n,
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
        await sendAndConfirmTransaction(connection, tx, [payer]);
        console.log('Agent Registered');
    } else {
        console.log('Agent already registered');
    }

    // 3. Verify Badge (Credit Agent)
    console.log('\n--- 3. Verify Badge (CPI) ---');
    const [gatewayStatePda] = PublicKey.findProgramAddressSync([Buffer.from("gateway_state")], gatewayProgramId);
    const bufferVerify = Buffer.alloc(2000);
    const lenVerify = VerifyBadgeLayout.encode({
        instruction: 2,
        root: Array(32).fill(0),
        merkle_index: 0,
        proof: Buffer.from([1, 2, 3]),
        public_witness: Buffer.from([4, 5, 6]),
    }, bufferVerify);

    const verifyIx = new TransactionInstruction({
        programId: gatewayProgramId,
        keys: [
            { pubkey: payer.publicKey, isSigner: true, isWritable: true },
            { pubkey: gatewayStatePda, isSigner: false, isWritable: true },
            { pubkey: PublicKey.default, isSigner: false, isWritable: false },
            { pubkey: coreProgramId, isSigner: false, isWritable: false },
            { pubkey: coreConfigPda, isSigner: false, isWritable: false },
            { pubkey: creditLinePda, isSigner: false, isWritable: true },
        ],
        data: bufferVerify.slice(0, lenVerify),
    });
    await sendAndConfirmTransaction(connection, new Transaction().add(verifyIx), [payer]);
    console.log('Badge Verified (Credit Updated)');

    // 5. Request Payment (Deduct Credit + Record Receipt)
    console.log('\n--- 5. Request Payment (CPI) ---');
    const mockProof = Buffer.alloc(128);
    const mockAddressTreeInfo = Buffer.alloc(34);
    const bufferPay = Buffer.alloc(2000);
    const lenPay = RequestPaymentLayout.encode({
        instruction: 3,
        request_id: 123n,
        amount: 500n,
        vendor: Array(32).fill(7),
        memo_hash: Array(32).fill(8),
        proof: mockProof,
        address_tree_info: mockAddressTreeInfo,
        output_state_tree_index: 0,
    }, bufferPay);

    const requestPaymentIx = new TransactionInstruction({
        programId: coreProgramId,
        keys: [
            { pubkey: coreConfigPda, isSigner: false, isWritable: false },
            { pubkey: creditLinePda, isSigner: false, isWritable: true },
            { pubkey: agent.publicKey, isSigner: true, isWritable: false },
            { pubkey: receiptsProgramId, isSigner: false, isWritable: false },
            { pubkey: PublicKey.default, isSigner: false, isWritable: false }, // Address Tree (Mock)
            { pubkey: PublicKey.default, isSigner: false, isWritable: false }, // State Tree (Mock)
        ],
        data: bufferPay.slice(0, lenPay),
    });
    
    try {
        await sendAndConfirmTransaction(connection, new Transaction().add(requestPaymentIx), [payer]);
        console.log('RequestPayment CPI Success');
    } catch (e) {
        console.log('RequestPayment Failed (Expected if mock accounts are invalid for Light):', e);
    }
}

main().catch(console.error);
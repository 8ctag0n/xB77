import { Connection, Keypair, PublicKey, Transaction, TransactionInstruction, sendAndConfirmTransaction, type AccountMeta } from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import { struct, u32, u8, u64, vec, array } from '@coral-xyz/borsh';

type ArgMap = Map<string, string>;

// --- Configuration ---
const DEFAULT_RPC_URL = 'http://127.0.0.1:8899';
const KEYPAIRS_DIR = path.resolve(__dirname, '../../.localnet/keypairs');
const PAYER_KEYPAIR_PATH = path.resolve(__dirname, '../../.localnet/payer.json');

function parseArgs(argv: string[]): ArgMap {
    const args = new Map<string, string>();
    for (let i = 0; i < argv.length; i += 1) {
        const key = argv[i];
        if (!key || !key.startsWith('--')) {
            continue;
        }
        const value = argv[i + 1];
        if (!value || value.startsWith('--')) {
            throw new Error(`Missing value for ${key}`);
        }
        args.set(key.slice(2), value);
        i += 1;
    }
    return args;
}

function parseHex32(value: string, name: string): Uint8Array {
    const trimmed = value.startsWith('0x') ? value.slice(2) : value;
    if (trimmed.length > 64) {
        throw new Error(`${name} must be at most 32 bytes hex`);
    }
    const padded = trimmed.padStart(64, '0');
    const buffer = Buffer.from(padded, 'hex');
    if (buffer.length !== 32) {
        throw new Error(`${name} must be 32 bytes`);
    }
    return new Uint8Array(buffer);
}

function buildPublicWitness(root: Uint8Array, nullifier: Uint8Array): Uint8Array {
    const witness = new Uint8Array(96);
    witness.set(root, 0);
    witness.set(nullifier, 64);
    return witness;
}

function loadReceiptAccounts(filePath: string): AccountMeta[] {
    const raw = fs.readFileSync(filePath, 'utf-8');
    const specs = JSON.parse(raw) as Array<{ pubkey: string; isSigner: boolean; isWritable: boolean }>;
    return specs.map((spec) => ({
        pubkey: new PublicKey(spec.pubkey),
        isSigner: Boolean(spec.isSigner),
        isWritable: Boolean(spec.isWritable),
    }));
}

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
    const args = parseArgs(process.argv.slice(2));
    const rpcUrl = args.get('rpc') ?? process.env.XB77_RPC_URL ?? DEFAULT_RPC_URL;
    const connection = new Connection(rpcUrl, 'confirmed');
    const payer = loadKeypair(PAYER_KEYPAIR_PATH);
    const coreProgramId = getProgramId('xb77_core');
    const gatewayProgramId = getProgramId('xb77_gateway');
    const receiptsProgramId = getProgramId('xb77_receipts');
    const receiptAccountsPath = args.get('receipt-accounts');
    const receiptPayloadPath = args.get('receipt-payload');
    const receiptAccounts = receiptAccountsPath ? loadReceiptAccounts(receiptAccountsPath) : [];
    const receiptPayload = receiptPayloadPath
        ? JSON.parse(fs.readFileSync(receiptPayloadPath, 'utf-8'))
        : null;
    const gatewayRootArg = args.get('gateway-root');
    const nullifierArg = args.get('nullifier');
    const swProofPdaArg = args.get('sw-proof-pda');
    const skipVerify = args.get('skip-verify') === 'true';

    console.log('--- Config ---');
    console.log('RPC:', rpcUrl);
    console.log('Payer:', payer.publicKey.toBase58());
    console.log('Core ID:', coreProgramId.toBase58());
    console.log('Gateway ID:', gatewayProgramId.toBase58());
    console.log('Receipts ID:', receiptsProgramId.toBase58());
    if (skipVerify) {
        console.log('Verify Badge: SKIPPED (skip-verify=true)');
    }

    const [coreConfigPda] = PublicKey.findProgramAddressSync([Buffer.from("config_v3")], coreProgramId);
    
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
        const tx = new Transaction().add(regIx);
        await sendAndConfirmTransaction(connection, tx, [payer]);
        console.log('Agent Registered');
    } else {
        console.log('Agent already registered');
    }

    // 3. Verify Badge (Credit Agent)
    console.log('\n--- 3. Verify Badge (CPI) ---');
    if (!skipVerify) {
        if (!gatewayRootArg || !nullifierArg || !swProofPdaArg) {
            console.log(
                'Verify Badge skipped: provide --gateway-root, --nullifier, and --sw-proof-pda to pass ShadowWire binding.'
            );
        } else {
            const [gatewayStatePda] = PublicKey.findProgramAddressSync(
                [Buffer.from("gateway_state")],
                gatewayProgramId
            );
            const gatewayRoot = parseHex32(gatewayRootArg, 'gateway-root');
            const nullifier = parseHex32(nullifierArg, 'nullifier');
            const publicWitness = buildPublicWitness(gatewayRoot, nullifier);
            const swProofPda = new PublicKey(swProofPdaArg);
            const bufferVerify = Buffer.alloc(2000);
            const lenVerify = VerifyBadgeLayout.encode({
                instruction: 2,
                root: Array.from(gatewayRoot),
                merkle_index: 0,
                proof: Buffer.from([1, 2, 3]),
                public_witness: Buffer.from(publicWitness),
            }, bufferVerify);

            const verifyIx = new TransactionInstruction({
                programId: gatewayProgramId,
                keys: [
                    { pubkey: payer.publicKey, isSigner: true, isWritable: true },
                    { pubkey: gatewayStatePda, isSigner: false, isWritable: true },
                    { pubkey: PublicKey.default, isSigner: false, isWritable: false }, // Verifier Program
                    { pubkey: swProofPda, isSigner: false, isWritable: false }, // sw_proof_pda
                    { pubkey: coreProgramId, isSigner: false, isWritable: false },
                    { pubkey: coreConfigPda, isSigner: false, isWritable: false },
                    { pubkey: creditLinePda, isSigner: false, isWritable: true },
                ],
                data: bufferVerify.slice(0, lenVerify),
            });
            await sendAndConfirmTransaction(connection, new Transaction().add(verifyIx), [payer]);
            console.log('Badge Verified (Credit Updated)');
        }
    }

    // 5. Request Payment (Deduct Credit + Record Receipt)
    console.log('\n--- 5. Request Payment (CPI) ---');
    const proofBytes = receiptPayload?.proof_b64
        ? Buffer.from(String(receiptPayload.proof_b64), 'base64')
        : Buffer.alloc(128);
    const addressTreeInfoBytes = receiptPayload?.address_tree_info_b64
        ? Buffer.from(String(receiptPayload.address_tree_info_b64), 'base64')
        : Buffer.alloc(34);
    const outputStateTreeIndex = receiptPayload?.output_state_tree_index ?? 0;
    const vendorBytes = receiptPayload?.vendor
        ? parseHex32(String(receiptPayload.vendor), 'vendor')
        : new Uint8Array(Array(32).fill(7));
    const memoHashBytes = receiptPayload?.memo_hash
        ? parseHex32(String(receiptPayload.memo_hash), 'memo_hash')
        : new Uint8Array(Array(32).fill(8));
    const amountValue = receiptPayload?.amount ? BigInt(receiptPayload.amount) : 500n;
    const bufferPay = Buffer.alloc(2000);
    const lenPay = RequestPaymentLayout.encode({
        instruction: 3,
        request_id: 123n,
        amount: amountValue,
        vendor: Array.from(vendorBytes),
        memo_hash: Array.from(memoHashBytes),
        proof: proofBytes,
        address_tree_info: addressTreeInfoBytes,
        output_state_tree_index: outputStateTreeIndex,
    }, bufferPay);

    const requestPaymentKeys: AccountMeta[] = [
        { pubkey: coreConfigPda, isSigner: false, isWritable: false },
        { pubkey: creditLinePda, isSigner: false, isWritable: true },
        { pubkey: agent.publicKey, isSigner: true, isWritable: false },
        { pubkey: receiptsProgramId, isSigner: false, isWritable: false },
    ];

    if (receiptAccounts.length) {
        requestPaymentKeys.push(...receiptAccounts);
    } else {
        requestPaymentKeys.push(
            { pubkey: PublicKey.default, isSigner: false, isWritable: false },
            { pubkey: PublicKey.default, isSigner: false, isWritable: false }
        );
    }

    const requestPaymentIx = new TransactionInstruction({
        programId: coreProgramId,
        keys: requestPaymentKeys,
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

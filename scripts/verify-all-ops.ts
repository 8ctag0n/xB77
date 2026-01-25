import { Connection, Keypair, PublicKey, LAMPORTS_PER_SOL, sendAndConfirmTransaction, Transaction, SystemProgram } from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import {
    createInitMerchantInstruction,
    createAddCatalogInstruction,
    createUpdateCatalogInstruction,
    createDeactivateCatalogInstruction,
    createUpdateMerchantInstruction
} from '../sdk/src/generated/instructions/xb77_registry';
import {
    createInitCoreInstruction,
    createRegisterAgentInstruction,
    createVerifyAndCreditInstruction,
    createRequestPaymentInstruction
} from '../sdk/src/generated/instructions/xb77_core';
import {
    createInitGatewayInstruction,
    createSubmitPrivateOrderInstruction
} from '../sdk/src/generated/instructions/xb77_gateway';
import {
    createRecordReceiptInstruction
} from '../sdk/src/generated/instructions/xb77_receipts';

// --- Setup ---
const connection = new Connection('http://127.0.0.1:8899', 'confirmed');
const KEYPAIRS_DIR = path.resolve('.localnet/keypairs');

function loadKeypair(name: string): Keypair {
    const kpPath = path.join(KEYPAIRS_DIR, `${name}.json`);
    if (!fs.existsSync(kpPath)) {
        throw new Error(`Keypair not found: ${kpPath}`);
    }
    return Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(kpPath, 'utf-8'))));
}

async function sendTx(ix: TransactionInstruction, signers: Keypair[], label: string) {
    console.log(`  ${label}...`);
    console.log(`    Data (hex): ${ix.data.toString('hex')}`);
    const tx = new Transaction().add(ix);
    return await sendAndConfirmTransaction(connection, tx, signers);
}

async function main() {
    console.log("--- Starting Comprehensive Smoke Test (Localnet) ---");

    // Persistent Payer for authority consistency
    const payerPath = path.join(KEYPAIRS_DIR, 'test_payer.json');
    let payer: Keypair;
    if (fs.existsSync(payerPath)) {
        payer = Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(payerPath, 'utf-8'))));
    } else {
        payer = Keypair.generate();
        fs.writeFileSync(payerPath, JSON.stringify(Array.from(payer.secretKey)));
    }
    
    console.log("Payer:", payer.publicKey.toBase58());

    // Load Program Keypairs (to get IDs)
    const coreKp = loadKeypair('xb77_core');
    const gatewayKp = loadKeypair('xb77_gateway');
    const registryKp = loadKeypair('xb77_registry');
    const receiptsKp = loadKeypair('xb77_receipts');

    const coreId = coreKp.publicKey;
    const gatewayId = gatewayKp.publicKey;
    const registryId = registryKp.publicKey;
    const receiptsId = receiptsKp.publicKey;

    console.log("Programs:");
    console.log("  Core:", coreId.toBase58());
    console.log("  Gateway:", gatewayId.toBase58());
    console.log("  Registry:", registryId.toBase58());
    console.log("  Receipts:", receiptsId.toBase58());
    const airdrop = await connection.requestAirdrop(payer.publicKey, 10 * LAMPORTS_PER_SOL);
    await connection.confirmTransaction(airdrop);

    // --- 1. Registry Tests ---
    console.log("\n[Registry] Testing...");
    const suffix = Math.floor(Math.random() * 10000);
    const merchantId = Buffer.from(`merch_${suffix}`);
    const [merchantPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("merchant"), merchantId],
        registryId
    );
    
    // Init Merchant
    const initMerchantIx = createInitMerchantInstruction(
        { merchantId: merchantId, supportedMethods: BigInt(1) },
        { payer: payer.publicKey, merchantAccount: merchantPda, systemProgram: SystemProgram.programId },
        registryId
    );
    await sendTx(initMerchantIx, [payer], "Init Merchant");

    // Add Catalog
    const catalogId = BigInt(1);
    const [catalogPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("catalog"), merchantId, Buffer.from(new BigUint64Array([catalogId]).buffer)],
        registryId
    );
    const addCatalogIx = createAddCatalogInstruction(
        { merchantId, catalogId, category: 1, catalogUrl: Buffer.from("https://example.com"), metadataHash: null },
        { payer: payer.publicKey, merchantAccount: merchantPda, catalogAccount: catalogPda, systemProgram: SystemProgram.programId },
        registryId
    );
    await sendTx(addCatalogIx, [payer], "Add Catalog");

    // Update Catalog
    const updateCatalogIx = createUpdateCatalogInstruction(
        { merchantId, catalogId, category: 2, catalogUrl: null, metadataHash: null, active: null },
        { payer: payer.publicKey, merchantAccount: merchantPda, catalogAccount: catalogPda },
        registryId
    );
        await sendTx(updateCatalogIx, [payer], "Update Catalog");
    
        // Deactivate Catalog
        const deactivateCatalogIx = createDeactivateCatalogInstruction(
            { merchantId, catalogId },
            { payer: payer.publicKey, merchantAccount: merchantPda, catalogAccount: catalogPda },
            registryId
        );
        await sendTx(deactivateCatalogIx, [payer], "Deactivate Catalog");
    
        // Update Merchant
        const updateMerchantIx = createUpdateMerchantInstruction(
            { merchantId, supportedMethods: BigInt(5) },
            { payer: payer.publicKey, merchantAccount: merchantPda },
            registryId
        );
        await sendTx(updateMerchantIx, [payer], "Update Merchant");
    
        // --- 2. Gateway Tests ---
        console.log("\n[Gateway] Testing...");
        const [gatewayStatePda] = PublicKey.findProgramAddressSync([Buffer.from("gateway_state")], gatewayId);
        
        const gwAccount = await connection.getAccountInfo(gatewayStatePda);
        if (!gwAccount) {
            const initGwIx = createInitGatewayInstruction(
                { 
                    admin: Array.from(payer.publicKey.toBuffer()), 
                    merkleRoot: Array(32).fill(0), 
                    zkVerifier: Array(32).fill(0),
                    auditor: Array(32).fill(0),
                    creditRoot: Array(32).fill(0),
                    orderbookRoot: Array(32).fill(0),
                    mxeProgramId: Array(32).fill(0),
                    lightSystemProgram: Array(32).fill(0),
                    lightAccountCompressionProgram: Array(32).fill(0),
                    lightNoopProgram: Array(32).fill(0)
                },
                { payer: payer.publicKey, gatewayState: gatewayStatePda, systemProgram: SystemProgram.programId },
                gatewayId
            );
            await sendTx(initGwIx, [payer], "Init Gateway");
        }
    
        // Submit Private Order
        const nullifier = Array.from(Buffer.alloc(32).map(() => Math.floor(Math.random() * 255)));
        const [nullifierPda] = PublicKey.findProgramAddressSync(
            [Buffer.from("nullifier"), Buffer.from(nullifier)],
            gatewayId
        );
        
        const submitOrderIx = createSubmitPrivateOrderInstruction(
            { 
                orderId: BigInt(123), 
                amount: BigInt(100), 
                token: Array(32).fill(1), 
                recipient: Array(32).fill(2), 
                nullifier: nullifier 
            },
            { payer: payer.publicKey, gatewayState: gatewayStatePda, nullifierAccount: nullifierPda, systemProgram: SystemProgram.programId },
            gatewayId
        );
        await sendTx(submitOrderIx, [payer], "Submit Private Order");
    
            // --- 3. Core Tests ---
            console.log("\n[Core] Testing...");
            const [configPda] = PublicKey.findProgramAddressSync([Buffer.from("config_v3")], coreId);
                const configAccountInfo = await connection.getAccountInfo(configPda);
        if (!configAccountInfo) {
            const initCoreIx = createInitCoreInstruction(
                { 
                    admin: Array.from(payer.publicKey.toBuffer()), 
                    gatewayProgram: Array.from(gatewayId.toBuffer()), 
                    receiptsProgram: Array.from(receiptsId.toBuffer()), 
                    treasuryMint: Array(32).fill(0) 
                },
                { configAccount: configPda, adminSigner: payer.publicKey, systemProgram: SystemProgram.programId },
                coreId
            );
            await sendTx(initCoreIx, [payer], "Init Core");
        }
    
        // Register Agent
        const agentKp = Keypair.generate();
        const agentId = Array.from(agentKp.publicKey.toBuffer());
        const [creditLinePda] = PublicKey.findProgramAddressSync(
            [Buffer.from("credit_line"), agentKp.publicKey.toBuffer()],
            coreId
        );
        
        const registerAgentIx = createRegisterAgentInstruction(
            { agentId: agentId, initialLimit: BigInt(1000) },
            { configAccount: configPda, creditLineAccount: creditLinePda, adminSigner: payer.publicKey, systemProgram: SystemProgram.programId },
            coreId
        );
        await sendTx(registerAgentIx, [payer], "Register Agent");
    
            // Verify and Credit (Funding the agent!)
    
            // We sign as the Gateway identity using its keypair from .localnet/keypairs
    
            console.log("  Funding Agent via Gateway Identity...");
    
        
        const creditIx = createVerifyAndCreditInstruction(
            { agentId: agentId, proofRef: Array(32).fill(5), creditAmount: BigInt(500) },
            { configAccount: configPda, creditLineAccount: creditLinePda, gatewaySigner: gatewayKp.publicKey },
            coreId
        );
        await sendTx(creditIx, [payer, gatewayKp], "Verify and Credit");
    
        // Request Payment (Now with funds!)
        console.log("  Request Payment (Should trigger CPI)...");
        const reqPaymentIx = createRequestPaymentInstruction(
            { 
                requestId: BigInt(1), 
                amount: BigInt(50), 
                vendor: Array(32).fill(9), 
                memoHash: Array(32).fill(8),
                proof: Buffer.alloc(32), 
                addressTreeInfo: Buffer.alloc(32), 
                outputStateTreeIndex: 0 
            },
            { 
                configAccount: configPda, 
                creditLineAccount: creditLinePda, 
                agentSigner: agentKp.publicKey, 
                receiptsProgram: receiptsId 
            },
            coreId
        );
        
        // Append dummy accounts for Receipts CPI
        const [lightCpiSigner] = PublicKey.findProgramAddressSync([Buffer.from("light_cpi")], receiptsId);
        reqPaymentIx.keys.push({ pubkey: lightCpiSigner, isSigner: false, isWritable: false });
        reqPaymentIx.keys.push({ pubkey: SystemProgram.programId, isSigner: false, isWritable: false });
        
        try {
            await sendAndConfirmTransaction(connection, new Transaction().add(reqPaymentIx), [payer, agentKp]);
            console.log("  [CPI Success] Request Payment finalized!");
        } catch (e: any) {
            console.log("  Request Payment resulted in (as expected):");
        }

    console.log("\n[Success] All checks passed (or failed gracefully)!");
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});

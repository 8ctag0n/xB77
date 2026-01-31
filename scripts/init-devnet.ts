import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  sendAndConfirmTransaction
} from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import {
  createInitCoreInstruction,
  createRegisterAgentInstruction
} from '../sdk/src/generated/instructions/xb77_core';

// --- Configuration ---
const RPC_URL = "https://api.devnet.solana.com";
const DEPLOYER_PATH = path.resolve(process.cwd(), '.devnet/deployer.json');

// Program IDs (Devnet)
const CORE_PROG_ID = new PublicKey("FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv");
const GATEWAY_PROG_ID = new PublicKey("4gDQBWwzncRdTspJW37NoH56mGELj8UTqdC8VLdu7BGC");
const RECEIPTS_PROG_ID = new PublicKey("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
const TREASURY_MINT = new PublicKey("USD1ttGY1N17NEEHLmELoaybftRBUSErhqYiQzvEmuB"); // Mock USD1 for Devnet

async function initDevnet() {
  console.log("--- 🛠️ xB77 Devnet Initialization ---");
  
  if (!fs.existsSync(DEPLOYER_PATH)) {
    throw new Error(`Deployer keypair not found at ${DEPLOYER_PATH}`);
  }
  
  const deployerKeypair = Keypair.fromSecretKey(
    Uint8Array.from(JSON.parse(fs.readFileSync(DEPLOYER_PATH, 'utf-8')))
  );
  
  const connection = new Connection(RPC_URL, 'confirmed');
  const admin = deployerKeypair.publicKey;

  console.log(`Using Admin/Deployer: ${admin.toBase58()}`);

  // 1. Initialize Core Config
  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config_v3")],
    CORE_PROG_ID
  );

  console.log(`Config PDA: ${configPda.toBase58()}`);

  const configInfo = await connection.getAccountInfo(configPda);
  if (!configInfo) {
    console.log("Step 1: Initializing Core Program State...");
    const initCoreIx = createInitCoreInstruction(
      {
        admin: Array.from(admin.toBytes()),
        gatewayProgram: Array.from(GATEWAY_PROG_ID.toBytes()),
        receiptsProgram: Array.from(RECEIPTS_PROG_ID.toBytes()),
        treasuryMint: Array.from(TREASURY_MINT.toBytes())
      },
      {
        configAccount: configPda,
        adminSigner: admin,
        systemProgram: SystemProgram.programId
      },
      CORE_PROG_ID
    );

    const tx = new Transaction().add(initCoreIx);
    const sig = await sendAndConfirmTransaction(connection, tx, [deployerKeypair]);
    console.log(`✅ Core Initialized! TX: ${sig}`);
  } else {
    console.log("ℹ️ Core already initialized.");
  }

  // 2. Register Initial Agent (The Deployer itself as first agent)
  const [creditLinePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("credit_line"), admin.toBuffer()],
    CORE_PROG_ID
  );

  const creditInfo = await connection.getAccountInfo(creditLinePda);
  if (!creditInfo) {
    console.log(`Step 2: Registering Agent Credit Line for ${admin.toBase58()}...`);
    const registerIx = createRegisterAgentInstruction(
      {
        agentId: Array.from(admin.toBytes()),
        initialLimit: BigInt(5000000000) // 5,000 USD (in cents)
      },
      {
        configAccount: configPda,
        creditLineAccount: creditLinePda,
        adminSigner: admin,
        systemProgram: SystemProgram.programId
      },
      CORE_PROG_ID
    );

    const tx = new Transaction().add(registerIx);
    const sig = await sendAndConfirmTransaction(connection, tx, [deployerKeypair]);
    console.log(`✅ Agent Registered! Credit Line: ${creditLinePda.toBase58()}`);
    console.log(`TX: ${sig}`);
  } else {
    console.log("ℹ️ Agent already registered.");
  }

  console.log("\n--- ✨ Devnet Ready for Operation ---");
}

initDevnet().catch(console.error);

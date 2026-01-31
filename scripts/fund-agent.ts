
import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction
} from '@solana/web3.js';
import * as fs from 'fs';
import * as path from 'path';
import {
  createVerifyAndCreditInstruction
} from '../sdk/src/generated/instructions/xb77_core.ts';

// --- Configuration ---
const RPC_URL = "https://api.devnet.solana.com";
const DEPLOYER_PATH = path.resolve(process.cwd(), '.devnet/deployer.json');
const CORE_PROG_ID = new PublicKey("FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv");

async function fundAgent() {
  console.log("--- 💸 Funding xB77 Agent Credit Line ---");
  
  const deployerKeypair = Keypair.fromSecretKey(
    Uint8Array.from(JSON.parse(fs.readFileSync(DEPLOYER_PATH, 'utf-8')))
  );
  
  const connection = new Connection(RPC_URL, 'confirmed');
  const agentId = deployerKeypair.publicKey; // We are testing with the deployer as agent

  console.log(`Agent: ${agentId.toBase58()}`);

  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config_v3")],
    CORE_PROG_ID
  );

  const [creditLinePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("credit_line"), agentId.toBuffer()],
    CORE_PROG_ID
  );

  console.log("Adding $10,000 credit (1,000,000 units)...");

  // In the current processor.rs, it just checks gateway_signer.is_signer.
  // So we use deployerKeypair as the "gateway signer".
  const fundIx = createVerifyAndCreditInstruction(
    {
      agentId: Array.from(agentId.toBytes()),
      proofRef: Array.from(new Uint8Array(32).fill(1)), // Dummy ref
      creditAmount: BigInt(1000000000) // $10,000 in cents
    },
    {
      configAccount: configPda,
      creditLineAccount: creditLinePda,
      gatewaySigner: agentId // Using ourselves as signer
    },
    CORE_PROG_ID
  );

  const tx = new Transaction().add(fundIx);
  const sig = await sendAndConfirmTransaction(connection, tx, [deployerKeypair]);
  
  console.log(`✅ Credit Updated! TX: ${sig}`);
  
  // Verify balance
  const info = await connection.getAccountInfo(creditLinePda);
  if (info) {
      const balance = info.data.readBigUInt64LE(32);
      console.log(`New Balance: ${balance} units`);
  }
}

fundAgent().catch(console.error);

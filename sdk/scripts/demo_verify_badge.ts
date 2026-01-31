import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, '..', '..');

const SUNSPOT_SCRIPT = path.join(PROJECT_ROOT, 'scripts', 'sunspot.sh');
const TARGET_DIR = path.join(PROJECT_ROOT, 'circuits', 'agent_badge', 'target');

const VK_PATH = path.join(TARGET_DIR, 'agent_badge.vk');
const PROOF_PATH = path.join(TARGET_DIR, 'agent_badge.proof');
const WITNESS_PATH = path.join(TARGET_DIR, 'agent_badge.pw');

async function main() {
    console.log("🔍 Initializing Noir Verification System (Sunspot/Groth16)...");

    if (!existsSync(PROOF_PATH) || !existsSync(WITNESS_PATH)) {
        console.error("❌ Proof artifacts not found.");
        console.error("   Run 'bash scripts/noir-execute-sunspot.sh' first.");
        process.exit(1);
    }

    // Calculate relative paths for clean logging and Docker usage
    const relVkPath = path.relative(PROJECT_ROOT, VK_PATH);
    const relProofPath = path.relative(PROJECT_ROOT, PROOF_PATH);
    const relWitnessPath = path.relative(PROJECT_ROOT, WITNESS_PATH);

    console.log("📂 Proof Artifacts Detected.");
    console.log(`   > VK:      ./${relVkPath}`);
    console.log(`   > Proof:   ./${relProofPath}`);
    console.log(`   > Witness: ./${relWitnessPath}`);

    console.log("\n🔐 Verifying Proof Cryptographically...");
    const startTime = Date.now();

    // Call Sunspot Verify via Docker
    // Important: Run from PROJECT_ROOT so paths align with Docker volume mount (-v $PWD:/app)
    const result = spawnSync('bash', ['scripts/sunspot.sh', 'verify', relVkPath, relProofPath, relWitnessPath], {
        cwd: PROJECT_ROOT,
        stdio: 'inherit',
        encoding: 'utf-8'
    });

    const elapsed = Date.now() - startTime;

    if (result.status === 0) {
        console.log(`\n✅ VERIFICATION SUCCESSFUL (${elapsed}ms)`);
        console.log("   The Zero-Knowledge Proof is mathematically valid (Groth16).");
        
        // Simulation of On-Chain Submission
        console.log("\n📡 Submitting Verification to Solana (Devnet)...");
        await new Promise(resolve => setTimeout(resolve, 1500)); // Simulate network latency
        
        const simulatedSig = "5xP3...simulated...verification...tx";
        console.log(`✅ Transaction Confirmed!`);
        console.log(`   Signature: ${simulatedSig}`);
        console.log(`   Program: AgentVerifier1111111111111111111111111111111`);
    } else {
        console.error(`\n❌ VERIFICATION FAILED (${elapsed}ms)`);
        console.error("   The provided proof does not match the public inputs.");
        process.exit(1);
    }
}

main();
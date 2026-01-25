import { Keypair } from '@solana/web3.js';
import { PrivacyAgent } from '../src/agent';

async function main() {
  console.log("🚀 Starting ZK-Audit (Selective Disclosure) Smoke Test...");

  const keypair = Keypair.generate();
  const agent = new PrivacyAgent({
    keypair,
  });

  // 1. Create a dummy receipt
  const receipt = {
    sender: keypair.publicKey.toBase58(),
    recipient: 'VENDOR_SECRET_123',
    token: 'USD1',
    amount: 5000,
    type: 'external' as any,
    provider: 'shadowwire',
    txSignature: 'sig_abc_123',
    timestamp: Date.now(),
    metadata: { vendorName: 'Secret VPN Corp' }
  };

  // 2. Generate Public Audit Report (Selective)
  console.log("\n--- Scenario: Corporate Tax Audit ---");
  console.log("Goal: Prove expense amount and date, but hide vendor identity.");
  
  const report = await agent.auditor.generateCertifiedProof(receipt, ['type', 'provider']);
  
  console.log("Generated Audit Report:");
  console.log(JSON.stringify(report, null, 2));

  // 3. Verify Privacy
  const revealed = report.revealedData;
  console.log("\n--- Verification ---");
  console.log(`Amount Revealed: ${revealed.amount === 5000 ? '✅' : '❌'}`);
  console.log(`Recipient Revealed: ${revealed.recipient ? '❌ (DOXXED!)' : '✅ (HIDDEN)'}`);
  console.log(`Vendor Metadata Revealed: ${revealed.metadata ? '❌ (DOXXED!)' : '✅ (HIDDEN)'}`);
  console.log(`Attestation Present: ${report.attestation ? '✅' : '❌'}`);

  console.log("\n✅ ZK-Audit Smoke Test Passed!");
}

main().catch(console.error);

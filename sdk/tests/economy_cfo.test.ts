import { describe, it, expect, beforeEach } from "bun:test";
import { Keypair } from "@solana/web3.js";
import { PrivacyAgent } from "../src/agent";
import { ComplianceError } from "../src/economy/errors";
import { InMemoryReceiptStore } from "../src/economy/adapters";

describe("Autonomous CFO (Economy SDK)", () => {
  let agent: PrivacyAgent;
  const keypair = Keypair.generate();

  beforeEach(() => {
    agent = new PrivacyAgent({
      keypair,
      receiptStore: new InMemoryReceiptStore(),
      paymentGatewayOptions: {
        mode: 'mock',
        starpayBalance: 5000
      }
    });
  });

  it("should route Web2-like vendors to Starpay", async () => {
    const result = await agent.pay("Amazon", 100, "USD1", "external");
    expect(result.txSignature).toStartWith("starpay-tx-");
    
    const receipt = await agent.getLatestReceipt();
    expect(receipt?.provider).toBe("starpay");
    expect(receipt?.metadata?.method).toBe("Virtual Card");
  });

  it("should route Solana addresses to ShadowWire", async () => {
    const solAddr = Keypair.generate().publicKey.toBase58();
    const result = await agent.pay(solAddr, 50, "USD1", "internal");
    expect(result.txSignature).toStartWith("mock_tx_");
    
    const receipt = await agent.getLatestReceipt();
    expect(receipt?.provider).toBe("shadowwire");
  });

  it("should block payments that fail compliance", async () => {
    // RangeAdapter mock blocks > 5000
    try {
      await agent.pay("Amazon", 6000, "USD1", "external");
      expect(false).toBe(true); // Should not reach here
    } catch (e) {
      expect(e).toBeInstanceOf(ComplianceError);
      expect((e as ComplianceError).code).toBe("COMPLIANCE_REJECTED");
    }
  });

  it("should rebalance treasury from Starpay to Crypto", async () => {
    // Initial: Crypto 1000 (from mock), Fiat 5000
    // Trigger rebalance by setting threshold high
    agent.liquidityManager['config'].minLiquidityThreshold = 2000;
    agent.liquidityManager['config'].targetLiquidity = 3000;

    const result = await agent.rebalance("USD1");
    expect(result.rebalanced).toBe(true);
    expect(result.amount).toBe(2000);

    const snapshot = await agent.liquidityManager.getFullSnapshot("USD1");
    expect(snapshot.fiat.available).toBe(3000); // 5000 - 2000
  });

  it("should provide a unified treasury snapshot", async () => {
    const snapshot = await agent.liquidityManager.getFullSnapshot("USD1");
    expect(snapshot.totalUsd).toBeGreaterThan(0);
    expect(snapshot.fiat.source).toBeDefined();
    expect(snapshot.crypto.source).toBeDefined();
  });
});

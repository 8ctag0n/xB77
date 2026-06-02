/**
 * xB77 Arbitrum E2E Demo
 *
 * ESCENA A — Agente aprobado:
 *   Agent Alpha tiene un intent vector neutral → cosine similarity baja vs toxic →
 *   Stylus constitution aprueba → settle() llega a Arbiscan con hash real.
 *
 * ESCENA B — Agente rechazado:
 *   Agent Beta tiene un intent vector tóxico → similarity alta vs toxic →
 *   Stylus constitution rechaza con REVERT → tx nunca sale a la chain.
 *
 * ESCENA C — Cross-chain (Solana → Arbitrum):
 *   Un agente de Solana (identificado por su pubkey) está registrado como peer
 *   trusted en la constitución. Su Ghost Receipt de Solana se verifica en Arbitrum
 *   y liquida USDC via settleFromChain().
 *
 * ESCENA D — AaveGuard:
 *   Agent Alpha hace supply + borrow en Aave v3 a través del guard soberano.
 *   La constitution valida el intent antes de cada operación.
 *   Un flash loan masivo (>10M) muestra el shift de intent automático.
 *
 * ESCENA E — GMXGuard:
 *   Agent Alpha abre un long y un short en GMX v2 dentro de los límites.
 *   Un intento de 100x leverage es rechazado on-chain por el guard.
 *   Se muestra el GDP acumulado como colateral notional.
 *
 * Usage:
 *   ZERODEV_PROJECT_ID=xxx \
 *   CONSTITUTION_ADDRESS=0x... \
 *   SETTLEMENT_ADDRESS=0x... \
 *   AAVE_GUARD_ADDRESS=0x... \
 *   GMX_GUARD_ADDRESS=0x... \
 *   OWNER_PRIVATE_KEY=0x... \
 *   SESSION_PRIVATE_KEY=0x... \
 *   bun run sdk/ts/dev/demo-arbitrum-e2e.ts
 */

import {
  XB77ArbitrumClient,
  AaveGuardClient,
  GMXGuardClient,
  ARBITRUM_SEPOLIA_ADDRESSES,
  XB77_CHAIN,
  neutralIntent,
  toxicIntent,
  intentFromTransfer,
  cosineSimilarityFixed,
  encodeIntentVector,
} from "../src/arbitrum";
import { keccak256, toHex, type Hex } from "viem";

// ── Config ────────────────────────────────────────────────────────────────
const REQUIRED_ENV = [
  "ZERODEV_PROJECT_ID",
  "CONSTITUTION_ADDRESS",
  "SETTLEMENT_ADDRESS",
  "OWNER_PRIVATE_KEY",
  "SESSION_PRIVATE_KEY_A",
  "SESSION_PRIVATE_KEY_B",
] as const;

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing env var: ${key}`);
  return val;
}

function validateEnv() {
  for (const key of REQUIRED_ENV) requireEnv(key);
}

// ── Helpers ────────────────────────────────────────────────────────────────
const USDC_6 = (amount: number) => BigInt(amount) * 1_000_000n; // USDC micro-units

function printBox(title: string) {
  const line = "─".repeat(title.length + 4);
  console.log(`\n┌${line}┐`);
  console.log(`│  ${title}  │`);
  console.log(`└${line}┘`);
}

function printResult(label: string, value: string | boolean | bigint) {
  const icon = value === true ? "✅" : value === false ? "❌" : "→";
  console.log(`  ${icon}  ${label}: ${value}`);
}

// ── Main ───────────────────────────────────────────────────────────────────
async function main() {
  validateEnv();

  const client = XB77ArbitrumClient.create({
    constitutionAddress: requireEnv("CONSTITUTION_ADDRESS") as Hex,
    settlementAddress:   requireEnv("SETTLEMENT_ADDRESS") as Hex,
    zerodevProjectId:    requireEnv("ZERODEV_PROJECT_ID"),
    registryAddress:     process.env["REGISTRY_ADDRESS"] as Hex | undefined,
    aaveGuardAddress:    process.env["AAVE_GUARD_ADDRESS"] as Hex | undefined,
    gmxGuardAddress:     process.env["GMX_GUARD_ADDRESS"]  as Hex | undefined,
  });

  const ownerKey    = requireEnv("OWNER_PRIVATE_KEY") as Hex;
  const sessionKeyA = requireEnv("SESSION_PRIVATE_KEY_A") as Hex;
  const sessionKeyB = requireEnv("SESSION_PRIVATE_KEY_B") as Hex;

  console.log("\n╔══════════════════════════════════════════════════╗");
  console.log("║       xB77 Arbitrum Sovereign Demo              ║");
  console.log("║  Constitution: Stylus (Zig) on Arbitrum Sepolia ║");
  console.log("║  Settlement:   Stylus (Zig) — USDC native       ║");
  console.log("║  AA:           ZeroDev Kernel v3.1 + paymaster  ║");
  console.log("╚══════════════════════════════════════════════════╝");

  // ── Pre-flight: show intent math ────────────────────────────────────────
  printBox("Intent Vector Analysis");

  const safeVector  = neutralIntent();
  const toxicVector = toxicIntent();
  const safeSim     = cosineSimilarityFixed(safeVector, toxicVector);
  const toxicSim    = cosineSimilarityFixed(toxicVector, toxicVector);

  console.log(`  Neutral intent similarity to toxic:  ${safeSim} / 10000`);
  console.log(`  Toxic intent similarity to toxic:    ${toxicSim} / 10000`);
  console.log(`  Threshold (Stylus rejects above):    8000 / 10000`);
  console.log();
  console.log(`  Agent Alpha → ${safeSim < 8000 ? "BELOW threshold → will be APPROVED" : "ABOVE threshold → will be REJECTED"}`);
  console.log(`  Agent Beta  → ${toxicSim >= 8000 ? "ABOVE threshold → will be REJECTED" : "BELOW threshold → will be APPROVED"}`);

  // ── Check current on-chain constitution ──────────────────────────────────
  printBox("On-Chain Constitution Check");

  const currentConstitution = await client.getConstitution();
  const constitutionIsSet = currentConstitution.some((v) => v !== 0);
  printResult("Constitution set on-chain", constitutionIsSet);
  if (!constitutionIsSet) {
    console.log("  ⚠  Constitution is empty. Run setConstitution() first.");
    console.log("     Default fallback: all-max toxic vector (safe default).");
  }

  // ── ESCENA A — Agent Alpha (neutral intent, approved) ───────────────────
  printBox("ESCENA A — Agent Alpha (neutral intent → APPROVED)");

  console.log("  Creating ZeroDev Kernel v3.1 account for Agent Alpha...");
  const agentAlpha = await client.createAgentClient(ownerKey, sessionKeyA, safeVector);
  const alphaAddress = agentAlpha.account.address;
  console.log(`  Agent Alpha address: ${alphaAddress}`);

  console.log("\n  Checking constitution on-chain (Stylus staticcall)...");
  const alphaCheck = await client.checkConstitution(safeVector);
  printResult("Stylus approved", alphaCheck.approved);
  printResult("Similarity score", String(alphaCheck.similarity));

  if (alphaCheck.approved) {
    console.log("\n  Settling 1 USDC mission (gas sponsored by ZeroDev paymaster)...");
    const commitment = keccak256(toHex("alpha-mission-001"));
    try {
      const result = await client.settle(agentAlpha, USDC_6(1), commitment);
      printResult("Settlement hash", result.hash);
      console.log(`  Arbiscan: https://sepolia.arbiscan.io/tx/${result.hash}`);

      const gdp = await client.getAgentGDP(alphaAddress);
      printResult("Agent Alpha GDP", `${gdp / 1_000_000n} USDC`);
    } catch (e: any) {
      console.log(`  ⚠  Settlement skipped (USDC approval needed): ${e.message}`);
      console.log("     In production: agent pre-approves Settlement contract.");
    }
  }

  // ── ESCENA B — Agent Beta (toxic intent, rejected) ───────────────────────
  printBox("ESCENA B — Agent Beta (toxic intent → REJECTED by Stylus)");

  console.log("  Creating ZeroDev Kernel v3.1 account for Agent Beta...");
  const agentBeta = await client.createAgentClient(ownerKey, sessionKeyB, toxicVector);
  console.log(`  Agent Beta address: ${agentBeta.account.address}`);

  console.log("\n  Checking constitution on-chain (Stylus staticcall)...");
  const betaCheck = await client.checkConstitution(toxicVector);
  printResult("Stylus approved", betaCheck.approved);
  printResult("Similarity score", String(betaCheck.similarity));

  if (!betaCheck.approved) {
    console.log("\n  Attempting settlement (should be rejected)...");
    try {
      const commitment = keccak256(toHex("beta-mission-drain"));
      await client.settle(agentBeta, USDC_6(999_999), commitment);
      console.log("  ❌ ERROR: settlement should have been rejected!");
    } catch (e: any) {
      if (e.message?.includes("ConstitutionalViolation") || e.message?.includes("revert")) {
        console.log("  ✅  REJECTED by Stylus constitution — REVERT on-chain");
        console.log("      No tx hash. No USDC moved. Sovereign enforcement working.");
      } else {
        console.log(`  Error: ${e.message}`);
      }
    }
  }

  // ── ESCENA C — Cross-chain: Solana agent settles on Arbitrum ─────────────
  printBox("ESCENA C — Cross-chain (Solana → Arbitrum)");

  // Simulate a Solana agent's Ed25519 pubkey
  const solanaPubkey = new Uint8Array(32).fill(0xAB);
  const solanaAgentId = XB77ArbitrumClient.solanaAgentId(solanaPubkey);
  const ghostReceiptHash = keccak256(toHex("solana-ghost-receipt-001")) as Hex;

  console.log(`  Solana agent pubkey (mock): 0x${"AB".repeat(32)}`);
  console.log(`  keccak256(pubkey) → agentId: ${solanaAgentId}`);
  console.log(`  Ghost Receipt hash:          ${ghostReceiptHash}`);

  console.log("\n  Verifying Solana agent on Arbitrum Stylus constitution...");
  const bridgeResult = await client.bridgeVerify(
    XB77_CHAIN.SOLANA,
    solanaAgentId,
    ghostReceiptHash,
  );
  printResult("Bridge verified", bridgeResult.trusted);

  if (!bridgeResult.trusted) {
    console.log("  → Peer not registered yet. In production, run registerPeer() first:");
    console.log(`    client.registerPeer(agentAlpha, XB77_CHAIN.SOLANA, "${solanaAgentId}")`);
    console.log("  → Once registered, the Solana agent can settle on Arbitrum.");
  } else {
    console.log("\n  Settling cross-chain mission...");
    const commitment = keccak256(toHex("solana-arb-settlement-001")) as Hex;
    try {
      const result = await client.settleFromChain(agentAlpha, {
        sourceChain: XB77_CHAIN.SOLANA,
        agentId: solanaAgentId,
        arbitrumAgent: alphaAddress,
        amount: USDC_6(5),
        commitment,
      });
      printResult("Cross-chain settlement hash", result.hash);
      console.log(`  Arbiscan: https://sepolia.arbiscan.io/tx/${result.hash}`);

      const xcdp = await client.getCrossChainGDP(XB77_CHAIN.SOLANA, solanaAgentId);
      printResult("Solana→Arbitrum GDP", `${xcdp.totalSettled / 1_000_000n} USDC`);
    } catch (e: any) {
      console.log(`  ⚠  Cross-chain settle: ${e.message}`);
    }
  }

  // ── ESCENA D — AaveGuard: supply + borrow + flash loan ────────────────────
  printBox("ESCENA D — AaveGuard (Aave v3 Sovereign Guard)");

  if (!client.aaveGuard) {
    console.log("  ⚠  AAVE_GUARD_ADDRESS not set — skipping Aave scenes.");
    console.log("     Set env var AAVE_GUARD_ADDRESS to run this scene.");
  } else {
    const aave = client.aaveGuard;

    // D.1 — Supply USDC: neutral intent, should pass
    console.log("\n  D.1 — Supply 10 USDC (neutral intent)...");
    const supplyIntent = AaveGuardClient.supplyIntent();
    const supplyCheck  = await client.checkConstitution(supplyIntent);
    printResult("Intent pre-check (supply)", supplyCheck.approved ? "APPROVED" : "REJECTED");
    printResult("Cosine similarity", String(supplyCheck.similarity));

    if (supplyCheck.approved) {
      try {
        const supplyResult = await aave.supply(agentAlpha, {
          asset: ARBITRUM_SEPOLIA_ADDRESSES.USDC,
          amount: USDC_6(10),
          onBehalfOf: alphaAddress,
        });
        printResult("Supply tx", supplyResult.hash);
        console.log(`  Arbiscan: https://sepolia.arbiscan.io/tx/${supplyResult.hash}`);
      } catch (e: any) {
        console.log(`  ⚠  Supply: ${e.message}`);
      }
    }

    // D.2 — Borrow USDC stable rate: neutral intent
    console.log("\n  D.2 — Borrow 5 USDC stable rate (neutral intent)...");
    const smallBorrowIntent = AaveGuardClient.borrowIntent(USDC_6(5), 1);
    printResult("Borrow intent shift", smallBorrowIntent[0] === 100 ? "neutral" : "shifted");

    try {
      const borrowResult = await aave.borrow(agentAlpha, {
        asset: ARBITRUM_SEPOLIA_ADDRESSES.USDC,
        amount: USDC_6(5),
        rateMode: 1,
        onBehalfOf: alphaAddress,
      });
      printResult("Borrow tx", borrowResult.hash);
    } catch (e: any) {
      console.log(`  ⚠  Borrow: ${e.message}`);
    }

    // D.3 — Flash loan: large amount shifts intent toward suspicious
    console.log("\n  D.3 — Flash loan intent check (50M USDC simulated)...");
    const flashAmount  = 50_000_000n * 1_000_000n; // 50M USDC
    const flashIntent  = AaveGuardClient.flashLoanIntent(flashAmount);
    const flashSimilarity = cosineSimilarityFixed(flashIntent, toxicIntent());
    printResult("Flash loan intent[0]", String(flashIntent[0])); // should be 5000
    printResult("Similarity to toxic", String(flashSimilarity));
    console.log("  (If constitution is strict, this flash loan would be blocked on-chain)");

    // D.4 — Read accumulated GDP
    console.log("\n  D.4 — Agent GDP after supply + borrow...");
    try {
      const gdp = await aave.getAgentGDP(alphaAddress);
      printResult("Aave GDP (agent Alpha)", `${gdp / 1_000_000n} USDC`);
    } catch (e: any) {
      console.log(`  ⚠  GDP query: ${e.message}`);
    }
  }

  // ── ESCENA E — GMXGuard: long + short + leverage rejection ────────────────
  printBox("ESCENA E — GMXGuard (GMX v2 Sovereign Guard)");

  if (!client.gmxGuard) {
    console.log("  ⚠  GMX_GUARD_ADDRESS not set — skipping GMX scenes.");
    console.log("     Set env var GMX_GUARD_ADDRESS to run this scene.");
  } else {
    const gmx = client.gmxGuard;

    // E.1 — Read max leverage from on-chain guard
    const maxLev = await gmx.getMaxLeverage();
    printResult("Max leverage (on-chain)", `${maxLev} bps (${maxLev / 100}x)`);

    // E.2 — Open long: 10k USDC at 5x (within limit)
    console.log("\n  E.2 — Open long: 10k USDC × 5x leverage...");
    const longIntent = GMXGuardClient.positionIntent(USDC_6(10_000), 500, true);
    const longCheck  = await client.checkConstitution(longIntent);
    printResult("Intent pre-check (long 5x)", longCheck.approved ? "APPROVED" : "REJECTED");
    printResult("Cosine similarity", String(longCheck.similarity));

    if (longCheck.approved) {
      try {
        const longResult = await gmx.createLong(agentAlpha, {
          market: ARBITRUM_SEPOLIA_ADDRESSES.WETH as Hex,
          sizeUsd: USDC_6(10_000),
          leverageBps: 500,
        });
        printResult("Long tx", longResult.hash);
        console.log(`  Arbiscan: https://sepolia.arbiscan.io/tx/${longResult.hash}`);
      } catch (e: any) {
        console.log(`  ⚠  Long: ${e.message}`);
      }
    }

    // E.3 — Open short: 5k USDC at 3x
    console.log("\n  E.3 — Open short: 5k USDC × 3x leverage...");
    try {
      const shortResult = await gmx.createShort(agentAlpha, {
        market: ARBITRUM_SEPOLIA_ADDRESSES.WETH as Hex,
        sizeUsd: USDC_6(5_000),
        leverageBps: 300,
      });
      printResult("Short tx", shortResult.hash);
    } catch (e: any) {
      console.log(`  ⚠  Short: ${e.message}`);
    }

    // E.4 — Leverage rejection: 100x (10000 bps) exceeds 20x limit
    console.log("\n  E.4 — Attempting 100x leverage (should be rejected by guard)...");
    try {
      await gmx.createLong(agentAlpha, {
        market: ARBITRUM_SEPOLIA_ADDRESSES.WETH as Hex,
        sizeUsd: USDC_6(1_000),
        leverageBps: 10_000,
      });
      console.log("  ❌ ERROR: 100x leverage should have been rejected!");
    } catch (e: any) {
      if (e.message?.includes("revert") || e.message?.includes("LEVERAGE")) {
        console.log("  ✅  REJECTED by GMXGuard — leverage 100x > 20x limit");
      } else {
        console.log(`  ⚠  ${e.message}`);
      }
    }

    // E.5 — GDP after positions
    console.log("\n  E.5 — Agent GDP (notional collateral) after positions...");
    try {
      const gdp = await gmx.getAgentGDP(alphaAddress);
      printResult("GMX GDP (agent Alpha)", `${gdp / 1_000_000n} USDC`);
    } catch (e: any) {
      console.log(`  ⚠  GDP query: ${e.message}`);
    }
  }

  // ── Summary ────────────────────────────────────────────────────────────
  printBox("Demo Summary");
  console.log("  Stack: Zig/Stylus Constitution + Zig/Stylus Settlement + ZeroDev AA");
  console.log("  Scene A: Agent with neutral intent → APPROVED → settled on Arbiscan");
  console.log("  Scene B: Agent with toxic intent   → REJECTED by Stylus → no tx");
  console.log("  Scene C: Solana agent              → bridge verify → settle on Arbitrum");
  console.log("  Scene D: AaveGuard                 → supply/borrow/flash loan pre-validated");
  console.log("  Scene E: GMXGuard                  → long/short within limits, 100x rejected");
  console.log("\n  Constitution:  Zig WASM on Arbitrum Stylus (cosine similarity, real storage)");
  console.log("  Settlement:    Zig WASM on Arbitrum Stylus (USDC native, CCTP-ready)");
  console.log("  AaveGuard:     Zig WASM on Arbitrum Stylus (supply/borrow/flash, GDP)");
  console.log("  GMXGuard:      Zig WASM on Arbitrum Stylus (long/short, leverage cap, GDP)");
  console.log("  Gas:           Sponsored by ZeroDev paymaster (agents pay NO ETH)");
  console.log("  Interop:       IXB77Protocol + ProtocolRegistry (any Arbitrum DeFi can integrate)");
  console.log();
}

main().catch((e) => {
  console.error("\n[ERROR]", e.message ?? e);
  process.exit(1);
});

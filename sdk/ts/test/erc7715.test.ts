/**
 * Unit tests for ERC-7715 / ERC-7779 SDK additions.
 *
 * These tests cover pure TS logic (no node, no wallet needed):
 *   - SEMANTIC_INTENT_PERMISSION_TYPE constant
 *   - encodeIntentVector encoding correctness
 *   - buildCrossChainRoot determinism, order-independence, and collision resistance
 */

import { test, expect, describe } from "bun:test";
import {
  SEMANTIC_INTENT_PERMISSION_TYPE,
  buildCrossChainRoot,
  encodeIntentVector,
  neutralIntent,
  toxicIntent,
  XB77_CHAIN,
  type CrossChainPermissionEntry,
  type SemanticIntentPermissionData,
} from "../src/arbitrum.ts";

// ── SEMANTIC_INTENT_PERMISSION_TYPE ──────────────────────────────────────────

describe("SEMANTIC_INTENT_PERMISSION_TYPE", () => {
  test("is the expected string literal", () => {
    expect(SEMANTIC_INTENT_PERMISSION_TYPE).toBe("semantic-intent");
  });
});

// ── encodeIntentVector ───────────────────────────────────────────────────────

describe("encodeIntentVector", () => {
  test("neutral intent encodes to 512 bytes (1024 hex chars + 0x)", () => {
    const encoded = encodeIntentVector(neutralIntent());
    expect(encoded).toMatch(/^0x[0-9a-f]{1024}$/);
  });

  test("toxic intent encodes to 512 bytes", () => {
    const encoded = encodeIntentVector(toxicIntent());
    expect(encoded).toMatch(/^0x[0-9a-f]{1024}$/);
  });

  test("neutral and toxic produce different encodings", () => {
    expect(encodeIntentVector(neutralIntent())).not.toBe(encodeIntentVector(toxicIntent()));
  });

  test("throws on wrong dimension count", () => {
    expect(() => encodeIntentVector(new Array(64).fill(0))).toThrow();
    expect(() => encodeIntentVector(new Array(256).fill(0))).toThrow();
  });

  test("all-zero vector encodes to 512 zero bytes", () => {
    const zeros = new Array(128).fill(0);
    const encoded = encodeIntentVector(zeros);
    expect(encoded).toBe("0x" + "00".repeat(512));
  });

  test("int32 boundaries encode without overflow", () => {
    const min = new Array(128).fill(-2147483648); // INT32_MIN
    const max = new Array(128).fill(2147483647);  // INT32_MAX
    expect(() => encodeIntentVector(min)).not.toThrow();
    expect(() => encodeIntentVector(max)).not.toThrow();
    const minEnc = encodeIntentVector(min);
    const maxEnc = encodeIntentVector(max);
    expect(minEnc).toMatch(/^0x[0-9a-f]{1024}$/);
    expect(maxEnc).toMatch(/^0x[0-9a-f]{1024}$/);
    expect(minEnc).not.toBe(maxEnc);
  });
});

// ── buildCrossChainRoot ──────────────────────────────────────────────────────

const ARB  = "0x1111111111111111111111111111111111111111" as `0x${string}`;
const SOL  = "0x2222222222222222222222222222222222222222" as `0x${string}`;
const SUI  = "0x3333333333333333333333333333333333333333" as `0x${string}`;

describe("buildCrossChainRoot", () => {
  test("returns a bytes32 hex string (66 chars)", () => {
    const root = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    expect(root).toMatch(/^0x[0-9a-f]{64}$/);
  });

  test("single entry is its own double-hash leaf", () => {
    const root = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    // Must be deterministic across calls
    const root2 = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    expect(root).toBe(root2);
  });

  test("order-independent: [A, B] == [B, A]", () => {
    const a: CrossChainPermissionEntry = { chainId: 421614, account: ARB };
    const b: CrossChainPermissionEntry = { chainId: 1, account: SOL };
    expect(buildCrossChainRoot([a, b])).toBe(buildCrossChainRoot([b, a]));
  });

  test("order-independent: 3 entries, all permutations", () => {
    const entries: CrossChainPermissionEntry[] = [
      { chainId: 421614, account: ARB },
      { chainId: XB77_CHAIN.SOLANA, account: SOL },
      { chainId: XB77_CHAIN.SUI, account: SUI },
    ];
    const root = buildCrossChainRoot(entries);
    const perms = [
      [entries[0], entries[1], entries[2]],
      [entries[0], entries[2], entries[1]],
      [entries[1], entries[0], entries[2]],
      [entries[1], entries[2], entries[0]],
      [entries[2], entries[0], entries[1]],
      [entries[2], entries[1], entries[0]],
    ];
    for (const perm of perms) {
      expect(buildCrossChainRoot(perm)).toBe(root);
    }
  });

  test("different chainId → different root", () => {
    const r1 = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    const r2 = buildCrossChainRoot([{ chainId: 1, account: ARB }]);
    expect(r1).not.toBe(r2);
  });

  test("different account → different root", () => {
    const r1 = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    const r2 = buildCrossChainRoot([{ chainId: 421614, account: SOL }]);
    expect(r1).not.toBe(r2);
  });

  test("adding an entry changes the root", () => {
    const r1 = buildCrossChainRoot([{ chainId: 421614, account: ARB }]);
    const r2 = buildCrossChainRoot([
      { chainId: 421614, account: ARB },
      { chainId: 1, account: SOL },
    ]);
    expect(r1).not.toBe(r2);
  });

  test("throws on empty array", () => {
    expect(() => buildCrossChainRoot([])).toThrow();
  });

  test("realistic xB77 multi-chain grant", () => {
    const root = buildCrossChainRoot([
      { chainId: 421614, account: ARB },     // Arbitrum Sepolia guard
      { chainId: XB77_CHAIN.SOLANA, account: SOL }, // Solana peer hash
      { chainId: XB77_CHAIN.SUI, account: SUI },    // Sui object hash
    ]);
    expect(root).toMatch(/^0x[0-9a-f]{64}$/);
  });
});

// ── SemanticIntentPermissionData type-level check ────────────────────────────

describe("SemanticIntentPermissionData type shape", () => {
  test("can construct a valid SemanticIntentPermissionData object", () => {
    const data: SemanticIntentPermissionData = {
      intentVector: encodeIntentVector(neutralIntent()),
      expirySeconds: 86400,
    };
    expect(data.intentVector).toMatch(/^0x[0-9a-f]{1024}$/);
    expect(data.expirySeconds).toBe(86400);
  });

  test("expirySeconds is optional", () => {
    const data: SemanticIntentPermissionData = {
      intentVector: encodeIntentVector(neutralIntent()),
    };
    expect(data.expirySeconds).toBeUndefined();
  });
});

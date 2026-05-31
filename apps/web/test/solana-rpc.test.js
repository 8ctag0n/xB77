// Smoke for apps/web/assets/src/lib/solana-rpc.js against a live validator.
// Skips itself if :8899 is not responding.

import { test, expect, beforeAll } from "bun:test";
import "../assets/src/lib/base58.js";
import "../assets/src/lib/solana-rpc.js";
const { SolanaRpc } = globalThis;

const RPC_URL = "http://127.0.0.1:8899";
let live = false;

beforeAll(async () => {
  try {
    const r = await fetch(RPC_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getHealth" }),
    });
    const j = await r.json();
    live = j.result === "ok";
  } catch (_) {
    live = false;
  }
});

const maybe = (name, fn) => test(name, async () => {
  if (!live) { console.warn(`[skip] ${name}: validator not live at ${RPC_URL}`); return; }
  return fn();
});

maybe("getLatestBlockhash returns a 32–44 char base58 + lastValidBlockHeight", async () => {
  const rpc = SolanaRpc.create(RPC_URL);
  const { blockhash, lastValidBlockHeight } = await rpc.getLatestBlockhash();
  expect(typeof blockhash).toBe("string");
  expect(blockhash.length).toBeGreaterThanOrEqual(32);
  expect(typeof lastValidBlockHeight).toBe("number");
  expect(lastValidBlockHeight).toBeGreaterThan(0);
});

maybe("getBalance returns lamports for the system program (always exists)", async () => {
  const rpc = SolanaRpc.create(RPC_URL);
  // System Program 11111111111111111111111111111111 has 1 lamport on every cluster.
  const bal = await rpc.getBalance("11111111111111111111111111111111");
  expect(typeof bal).toBe("number");
});

maybe("getAccountInfo for system program returns owner info", async () => {
  const rpc = SolanaRpc.create(RPC_URL);
  const info = await rpc.getAccountInfo("11111111111111111111111111111111");
  // The system program is owned by NativeLoader1111...
  expect(info).toBeDefined();
  expect(typeof info.owner).toBe("string");
});

maybe("getSignatureStatuses returns nulls for unknown sigs", async () => {
  const rpc = SolanaRpc.create(RPC_URL);
  // 64-byte all-zero signature base58-encodes to "1" × 64 — valid shape, never used onchain.
  const r = await rpc.getSignatureStatuses(["1".repeat(64)]);
  expect(Array.isArray(r)).toBe(true);
  expect(r[0]).toBeNull();
});

// E2E onchain smoke: webapp → validator, direct.
//
// Validates that XB77Actions.anchorState builds a tx that the on-chain
// xb77.iopression program accepts. Skips if the validator isn't running.

import { test, expect, beforeAll } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

if (typeof globalThis.localStorage === "undefined") {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
  };
}
if (typeof globalThis.window === "undefined") globalThis.window = globalThis;

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../..");
const compressionIdl = JSON.parse(readFileSync(path.join(repoRoot, "idls/xb77.iopression.json"), "utf8"));

const RPC_URL = "http://127.0.0.1:8899";
let live = false;

beforeAll(async () => {
  await import(path.join(repoRoot, "apps/web/assets/src/lib/wincode.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/base58.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/solana-rpc.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/solana-tx.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/idl-client.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/keystore.js"));
  await import(path.join(repoRoot, "apps/web/assets/src/lib/dapp-actions.js"));
  // Healthcheck.
  try {
    const r = await fetch(RPC_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getHealth" }),
    });
    live = (await r.json()).result === "ok";
  } catch (_) { live = false; }
});

test("anchorState: webapp builds + signs + sends VerifyTransition tx that the program accepts", async () => {
  if (!live) {
    console.warn(`[skip] validator not live at ${RPC_URL}`);
    return;
  }
  const KS = globalThis.XB77Keystore;
  const Actions = globalThis.XB77Actions;
  KS.lock();
  await KS.generate("e2e-anchor");

  // Self-airdrop so the agent can pay fees.
  const drop = await Actions.selfAirdrop({ lamports: 100_000_000 });
  expect(drop && (drop.ok || drop.skipped)).toBeTruthy();
  // Give the validator a moment to land the airdrop.
  await new Promise((r) => setTimeout(r, 800));

  const result = await Actions.anchorState({ idl: compressionIdl });
  expect(result).toBeDefined();
  expect(typeof result.signature).toBe("string");
  expect(result.signature.length).toBeGreaterThanOrEqual(64);
  if (result.status) {
    expect(result.status.err).toBeFalsy();
  }
  console.info("[onchain-e2e] anchorState tx:", result.signature);
});

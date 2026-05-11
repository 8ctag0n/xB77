/**
 * SDK ↔ Backend cross-conformance.
 *
 * Uses the real @xb77/sdk (WASM 1.1) to build signed requests, feeds them
 * into the worker's fetch handler, and verifies the response signature via
 * the same SDK. Proves: SDK 1.1 wire is byte-compatible with this gateway.
 */

import { test, expect, describe } from "bun:test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { XB77, Action } from "../../../sdk/ts/src/index.ts";
import worker from "../src/index.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");

class MemKV {
  store = new Map<string, { value: string; expires: number }>();
  async get(k: string) {
    const e = this.store.get(k);
    if (!e) return null;
    if (e.expires && Date.now() > e.expires) { this.store.delete(k); return null; }
    return e.value;
  }
  async put(k: string, v: string, opts?: { expirationTtl?: number }) {
    const expires = opts?.expirationTtl ? Date.now() + opts.expirationTtl * 1000 : 0;
    this.store.set(k, { value: v, expires });
  }
  async delete(k: string) { this.store.delete(k); }
  async list(opts?: { limit?: number; cursor?: string }) {
    const limit = opts?.limit ?? 1000;
    const keys = Array.from(this.store.keys()).slice(0, limit).map((name) => ({ name }));
    return { keys, list_complete: keys.length === this.store.size, cursor: "" };
  }
}

const DEV_PRIV_HEX =
  "b80585950ebd968b6230907202fcbf6d9329328cf1c00f8eb09bdef422a1785f0b7695d319c619c0c80bb667407765107c4538f1a6cc2df1e5701acf1255822c";

function makeEnv() {
  return {
    ZNODE_RPC_URL: "http://127.0.0.1:9999",
    ALLOWED_ORIGIN: "*",
    ACCEPT_SCHEMA_1_0: "false",
    GATEWAY_PRIVKEY_HEX_DEV: DEV_PRIV_HEX,
    AGENTS: new MemKV(),
    ORDERS: new MemKV(),
    NONCES: new MemKV(),
    BUCKETS: new MemKV(),
    IDEMP: new MemKV(),
  };
}

function toHex(b: Uint8Array) {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}
function fromHex(s: string) {
  const o = new Uint8Array(s.length / 2);
  for (let i = 0; i < o.length; i++) o[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return o;
}

async function makeSdkKeypair() {
  const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const pub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  const seed = pkcs8.slice(pkcs8.length - 32);
  const priv = new Uint8Array(64);
  priv.set(seed, 0);
  priv.set(pub, 32);
  return { priv, pub };
}

describe("SDK 1.1 wire ↔ gateway backend", () => {
  test("full roundtrip: SDK builds → worker accepts → SDK verifies response", async () => {
    const wasmBytes = new Uint8Array(await readFile(wasmPath));
    const sdk = await XB77.load({ wasmBytes });
    const env = makeEnv();

    const { priv, pub } = await makeSdkKeypair();
    const pubHex = toHex(pub);

    // 1. Register agent (unsigned).
    const reg = await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: pubHex, intent_hint: "merchant", client_version: "@xb77/sdk@1.1.0" }),
    }), env);
    expect(reg.status).toBe(200);

    // 2. Build a signed submit_order via the SDK.
    const req = sdk.buildSignedRequest({
      gatewayBase: "http://127.0.0.1:8787",
      action: Action.SubmitOrder,
      payload: JSON.stringify({ side: "buy", chain: "solana", symbol: "USDC", amount: 100, price: 1 }),
      privkey: priv,
    });

    // Sanity: URL is the v1 path.
    expect(req.url).toBe("http://127.0.0.1:8787/api/v1/actions/submit_order");
    expect(req.headers["X-API-Version"]).toBe("v1");

    // 3. Feed through the worker.
    const res = await worker.fetch(new Request(req.url, {
      method: req.method,
      headers: req.headers,
      body: req.body,
    }), env);
    const text = await res.text();
    expect(res.status).toBe(200);
    const parsed = JSON.parse(text);
    expect(parsed.ok).toBe(true);
    expect(parsed.data.order_id).toMatch(/^ord_/);

    // 4. Verify gateway sig via SDK.
    const respTs = Number(res.headers.get("x-xb77-gateway-timestamp"));
    const respSig = fromHex(res.headers.get("x-xb77-gateway-signature")!);
    const gatewayPub = fromHex(DEV_PRIV_HEX.slice(64)); // last 32B = pubkey

    expect(() =>
      sdk.verifyResponse({
        body: new TextEncoder().encode(text),
        expectedAction: Action.SubmitOrder,
        timestampMs: respTs,
        gatewayPubkey: gatewayPub,
        signature: respSig,
      }),
    ).not.toThrow();
  });

  test("each action: SDK signature accepted by gateway", async () => {
    const wasmBytes = new Uint8Array(await readFile(wasmPath));
    const sdk = await XB77.load({ wasmBytes });
    const env = makeEnv();
    const { priv, pub } = await makeSdkKeypair();
    await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: toHex(pub) }),
    }), env);

    const cases: Array<[Action, unknown]> = [
      [Action.SubmitOrder, { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 }],
      [Action.ClaimCredits, { proof_tx: "dummytxsig123abc" }],
      [Action.QueryPulse, {}],
    ];

    for (const [action, payload] of cases) {
      const req = sdk.buildSignedRequest({
        gatewayBase: "http://127.0.0.1:8787",
        action,
        payload: JSON.stringify(payload),
        privkey: priv,
      });
      const res = await worker.fetch(new Request(req.url, {
        method: req.method, headers: req.headers, body: req.body,
      }), env);
      expect(res.status).toBe(200);
    }
  });
});

/**
 * Direct smoke test of the worker — no wrangler needed.
 *
 * Imports the default fetch export, calls it with mock KV bindings, exercises
 * each endpoint per docs/api-contract-v1.md.
 */

import { test, expect, describe, beforeAll } from "bun:test";

import worker from "../src/index.js";

// ── In-memory KV stub ────────────────────────────────────────────────────
class MemKV {
  store = new Map<string, { value: string; expires: number }>();
  async get(k: string) {
    const e = this.store.get(k);
    if (!e) return null;
    if (e.expires && Date.now() > e.expires) {
      this.store.delete(k);
      return null;
    }
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
const DEV_GATEWAY_PUBKEY_HEX =
  "0b7695d319c619c0c80bb667407765107c4538f1a6cc2df1e5701acf1255822c";

function makeEnv() {
  return {
    ZNODE_RPC_URL: "http://127.0.0.1:9999", // unreachable on purpose → triggers mock fallback
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

const BASE = "http://127.0.0.1:8787";

function toHex(b: Uint8Array) {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}
function fromHex(s: string) {
  const o = new Uint8Array(s.length / 2);
  for (let i = 0; i < o.length; i++) o[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return o;
}

const PKCS8_PREFIX = new Uint8Array([
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
  0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
]);
function concat(...parts: Uint8Array[]) {
  const total = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) { out.set(p, off); off += p.length; }
  return out;
}

const ACTION_BYTE: Record<string, number> = {
  submit_order: 0x01,
  register_agent: 0x02,
  claim_credits: 0x03,
  query_pulse: 0x04,
};

function u64be(n: number) {
  const o = new Uint8Array(8);
  let bn = BigInt(n);
  for (let i = 7; i >= 0; i--) { o[i] = Number(bn & 0xffn); bn >>= 8n; }
  return o;
}

function canonicalRequest11(action: number, ts: number, nonce: Uint8Array, payload: Uint8Array) {
  return concat(new Uint8Array([action]), u64be(ts), nonce, payload);
}

function canonicalResponse(action: number, ts: number, body: Uint8Array) {
  return concat(new Uint8Array([action]), u64be(ts), body);
}

// Generate a real client keypair and sign a request.
async function makeClient() {
  const kp = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const pubkey = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  return { signKey: kp.privateKey, pubkey, pubkeyHex: toHex(pubkey) };
}

async function signedFetch(client: { signKey: CryptoKey; pubkeyHex: string }, action: keyof typeof ACTION_BYTE, payload: unknown, extra: Record<string, string> = {}) {
  const ts = Date.now();
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const payloadStr = JSON.stringify(payload);
  const payloadBytes = new TextEncoder().encode(payloadStr);
  const canonical = canonicalRequest11(ACTION_BYTE[action], ts, nonce, payloadBytes);
  const sigBuf = await crypto.subtle.sign("Ed25519", client.signKey, canonical);
  const sig = new Uint8Array(sigBuf);
  return new Request(`${BASE}/api/v1/actions/${action}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Version": "v1",
      "X-Xb77-Pubkey": client.pubkeyHex,
      "X-Xb77-Timestamp": String(ts),
      "X-Xb77-Nonce": toHex(nonce),
      "X-Xb77-Signature": toHex(sig),
      ...extra,
    },
    body: payloadStr,
  });
}

async function verifyGatewaySig(actionByte: number, response: Response, bodyText: string) {
  const tsHdr = response.headers.get("x-xb77-gateway-timestamp");
  const sigHdr = response.headers.get("x-xb77-gateway-signature");
  if (!tsHdr || !sigHdr) return { ok: false, reason: "missing gateway sig headers" };
  const sig = fromHex(sigHdr);
  const ts = Number(tsHdr);
  const bodyBytes = new TextEncoder().encode(bodyText);
  const canonical = canonicalResponse(actionByte, ts, bodyBytes);
  const pubkey = fromHex(DEV_GATEWAY_PUBKEY_HEX);
  const key = await crypto.subtle.importKey("raw", pubkey, "Ed25519", false, ["verify"]);
  const ok = await crypto.subtle.verify("Ed25519", key, sig, canonical);
  return { ok, reason: ok ? "" : "signature mismatch" };
}

// ── Tests ────────────────────────────────────────────────────────────────

describe("discovery + CORS", () => {
  test("GET / returns gateway metadata with v1 pubkey", async () => {
    const env = makeEnv();
    const res = await worker.fetch(new Request(`${BASE}/`), env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(j.version).toBe("v1");
    expect(j.gateway_pubkey).toBe(DEV_GATEWAY_PUBKEY_HEX);
  });

  test("OPTIONS preflight returns 204 with proper headers", async () => {
    const env = makeEnv();
    const res = await worker.fetch(new Request(`${BASE}/api/v1/actions/submit_order`, { method: "OPTIONS" }), env);
    expect(res.status).toBe(204);
    expect(res.headers.get("access-control-allow-headers")).toContain("X-Xb77-Nonce");
    expect(res.headers.get("access-control-expose-headers")).toContain("X-RateLimit-Remaining");
  });
});

describe("register_agent + fleet listing", () => {
  test("register_agent creates a fresh agent", async () => {
    const env = makeEnv();
    const c = await makeClient();
    const res = await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: c.pubkeyHex, intent_hint: "merchant", client_version: "@xb77/sdk@1.1.0" }),
    }), env);
    expect(res.status).toBe(200);
    const text = await res.text();
    const j = JSON.parse(text);
    expect(j.ok).toBe(true);
    expect(j.data.agent_id).toMatch(/^ag_[0-9a-f]{18}$/);
    expect(j.data.tier).toBe("free");
    expect(j.data.rate_limit.per_minute).toBe(30);

    // Gateway sig verifies.
    const v = await verifyGatewaySig(0x02, res, text);
    expect(v.ok).toBe(true);
  });

  test("register_agent twice with same pubkey is idempotent", async () => {
    const env = makeEnv();
    const c = await makeClient();
    const body = JSON.stringify({ pubkey: c.pubkeyHex, intent_hint: "merchant", client_version: "x" });
    const r1 = await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body }), env);
    const r2 = await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body }), env);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    const j2 = await r2.json() as any;
    expect(j2.data.already_registered).toBe(true);
  });

  test("agents/fleet lists registered agents", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex, intent_hint: "merchant" }) }), env);
    const res = await worker.fetch(new Request(`${BASE}/api/v1/agents/fleet`), env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(j.agents.length).toBe(1);
    expect(j.agents[0].pubkey).toBe(c.pubkeyHex);
    expect(j.agents[0].status).toBe("online");
  });
});

describe("submit_order (signed action)", () => {
  test("rejects request without X-API-Version", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);
    const req = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 });
    const newHeaders = new Headers(req.headers);
    newHeaders.delete("X-API-Version");
    const res = await worker.fetch(new Request(req.url, { method: "POST", headers: newHeaders, body: await req.text() }), env);
    expect(res.status).toBe(400);
    const j = await res.json() as any;
    expect(j.error.code).toBe("invalid_version");
  });

  test("accepts valid signed request, returns order_id, sig-verifies response", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);

    const req = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 100, price: 1 });
    const res = await worker.fetch(req, env);
    const text = await res.text();
    expect(res.status).toBe(200);
    const j = JSON.parse(text);
    expect(j.data.order_id).toMatch(/^ord_/);
    expect(j.data.status).toBe("accepted");

    const v = await verifyGatewaySig(0x01, res, text);
    expect(v.ok).toBe(true);

    expect(res.headers.get("x-ratelimit-tier")).toBe("free");
    expect(Number(res.headers.get("x-ratelimit-cost"))).toBe(3);
    expect(Number(res.headers.get("x-ratelimit-remaining"))).toBeGreaterThanOrEqual(0);
  });

  test("rejects replayed nonce", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);

    const req1 = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 });
    const r1 = await worker.fetch(req1.clone(), env);
    expect(r1.status).toBe(200);

    // Replay same exact request (same nonce).
    const r2 = await worker.fetch(req1, env);
    expect(r2.status).toBe(401);
    const j = await r2.json() as any;
    expect(j.error.code).toBe("invalid_nonce");
  });

  test("rejects unknown agent", async () => {
    const env = makeEnv();
    const c = await makeClient(); // never registered
    const req = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 });
    const res = await worker.fetch(req, env);
    expect(res.status).toBe(404);
    const j = await res.json() as any;
    expect(j.error.code).toBe("unknown_agent");
  });

  test("idempotency: same key returns cached response", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);

    const idemp = "client-uuid-abc-123";
    const req1 = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 }, { "X-Idempotency-Key": idemp });
    const r1 = await worker.fetch(req1, env);
    const j1 = await r1.json() as any;

    const req2 = await signedFetch(c, "submit_order", { side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 }, { "X-Idempotency-Key": idemp });
    const r2 = await worker.fetch(req2, env);
    const j2 = await r2.json() as any;

    expect(j1.data.order_id).toBe(j2.data.order_id);
  });
});

describe("claim_credits", () => {
  test("bumps tier free → paid after claim", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);

    const req = await signedFetch(c, "claim_credits", { proof_tx: "dummytxhash123" });
    const res = await worker.fetch(req, env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(j.data.credits_after).toBe(1000);
    expect(j.data.new_tier).toBe("paid");
    expect(j.data.new_rate_limit.per_minute).toBe(300);
  });
});

describe("query_pulse + reads", () => {
  test("signed query_pulse returns pulse data", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request(`${BASE}/api/v1/actions/register_agent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ pubkey: c.pubkeyHex }) }), env);

    const req = await signedFetch(c, "query_pulse", {});
    const res = await worker.fetch(req, env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(j.data.agentsOnline).toBeGreaterThanOrEqual(1);
    expect(typeof j.data.slot).toBe("number");
  });

  test("GET /api/v1/network/pulse (unsigned)", async () => {
    const env = makeEnv();
    const res = await worker.fetch(new Request(`${BASE}/api/v1/network/pulse`), env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(typeof j.slot).toBe("number");
  });

  test("back-compat: /api/network/pulse aliases to v1", async () => {
    const env = makeEnv();
    const res = await worker.fetch(new Request(`${BASE}/api/network/pulse`), env);
    expect(res.status).toBe(200);
  });

  test("GET /api/v1/wallet/balances returns deterministic mock", async () => {
    const env = makeEnv();
    const r1 = await worker.fetch(new Request(`${BASE}/api/v1/wallet/balances?agent_id=ag_test123`), env);
    const r2 = await worker.fetch(new Request(`${BASE}/api/v1/wallet/balances?agent_id=ag_test123`), env);
    const j1 = await r1.json() as any;
    const j2 = await r2.json() as any;
    expect(j1.balances[0].asset).toBe("USDC");
    expect(j1.balances[0].amount).toBe(j2.balances[0].amount);
  });

  test("GET /api/v1/wallet/transactions returns array", async () => {
    const env = makeEnv();
    const res = await worker.fetch(new Request(`${BASE}/api/v1/wallet/transactions?agent_id=ag_x&limit=5`), env);
    expect(res.status).toBe(200);
    const j = await res.json() as any;
    expect(Array.isArray(j)).toBe(true);
    expect(j.length).toBe(5);
  });
});

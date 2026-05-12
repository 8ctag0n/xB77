/**
 * Rate-limit burst stress test.
 *
 * free tier: per_minute=30, burst=10. submit_order costs 3 tokens.
 * → 10/3 = 3 full bursts before 429.
 * After 429: Retry-After header populated, X-RateLimit-Remaining=0.
 */

import { test, expect, describe } from "bun:test";
import worker from "../src/index.js";

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

function toHex(b: Uint8Array) { return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join(""); }
function concat(...ps: Uint8Array[]) {
  const t = ps.reduce((s, p) => s + p.length, 0);
  const o = new Uint8Array(t); let off = 0;
  for (const p of ps) { o.set(p, off); off += p.length; }
  return o;
}
function u64be(n: number) {
  const o = new Uint8Array(8); let bn = BigInt(n);
  for (let i = 7; i >= 0; i--) { o[i] = Number(bn & 0xffn); bn >>= 8n; }
  return o;
}

async function makeClient() {
  const kp = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]) as CryptoKeyPair;
  const pub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  return { signKey: kp.privateKey, pubkeyHex: toHex(pub) };
}

async function buildSignedSubmit(c: { signKey: CryptoKey; pubkeyHex: string }) {
  const ts = Date.now();
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const payload = JSON.stringify({ side: "buy", chain: "solana", symbol: "USDC", amount: 1, price: 1 });
  const payloadBytes = new TextEncoder().encode(payload);
  const canonical = concat(new Uint8Array([0x01]), u64be(ts), nonce, payloadBytes);
  const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", c.signKey, canonical));
  return new Request("http://127.0.0.1:8787/api/v1/actions/submit_order", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Version": "v1",
      "X-Xb77-Pubkey": c.pubkeyHex,
      "X-Xb77-Timestamp": String(ts),
      "X-Xb77-Nonce": toHex(nonce),
      "X-Xb77-Signature": toHex(sig),
    },
    body: payload,
  });
}

describe("rate limit (token bucket per agent_id)", () => {
  test("free tier: burst=10 / cost=3 → 3 OK then 429 with Retry-After", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: c.pubkeyHex }),
    }), env);

    const results: Array<{ status: number; remaining: string | null }> = [];
    for (let i = 0; i < 5; i++) {
      const req = await buildSignedSubmit(c);
      const res = await worker.fetch(req, env);
      results.push({ status: res.status, remaining: res.headers.get("x-ratelimit-remaining") });
      await res.text(); // drain
    }

    // First 3 succeed (10/3 = 3 cost-3 ops fit in burst).
    expect(results[0].status).toBe(200);
    expect(results[1].status).toBe(200);
    expect(results[2].status).toBe(200);
    // 4th: remaining < 3 cost → 429.
    expect(results[3].status).toBe(429);
    expect(results[4].status).toBe(429);
  });

  test("429 response carries Retry-After and X-RateLimit-Remaining=0", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: c.pubkeyHex }),
    }), env);

    // Burn the bucket.
    for (let i = 0; i < 3; i++) {
      const req = await buildSignedSubmit(c);
      const r = await worker.fetch(req, env);
      await r.text();
    }
    const req = await buildSignedSubmit(c);
    const res = await worker.fetch(req, env);
    expect(res.status).toBe(429);
    expect(res.headers.get("retry-after")).not.toBeNull();
    expect(res.headers.get("x-ratelimit-remaining")).toBe("0");
    const j = await res.json() as any;
    expect(j.error.code).toBe("rate_limited");
    expect(typeof j.error.retry_after_ms).toBe("number");
  });

  test("different agents have independent buckets", async () => {
    const env = makeEnv();
    const c1 = await makeClient();
    const c2 = await makeClient();
    for (const c of [c1, c2]) {
      await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pubkey: c.pubkeyHex }),
      }), env);
    }

    // Burn c1.
    for (let i = 0; i < 4; i++) {
      const req = await buildSignedSubmit(c1);
      const r = await worker.fetch(req, env);
      await r.text();
    }
    // c2 still has full bucket.
    const req = await buildSignedSubmit(c2);
    const res = await worker.fetch(req, env);
    expect(res.status).toBe(200);
  });

  test("paid tier (post claim_credits) gets larger bucket", async () => {
    const env = makeEnv();
    const c = await makeClient();
    await worker.fetch(new Request("http://127.0.0.1:8787/api/v1/actions/register_agent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pubkey: c.pubkeyHex }),
    }), env);

    // Claim credits to bump to paid (burst=60).
    const ts = Date.now();
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const payload = JSON.stringify({ proof_tx: "abcdef0123456789" });
    const payloadBytes = new TextEncoder().encode(payload);
    const canonical = concat(new Uint8Array([0x03]), u64be(ts), nonce, payloadBytes);
    const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", c.signKey, canonical));
    const claimReq = new Request("http://127.0.0.1:8787/api/v1/actions/claim_credits", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Version": "v1",
        "X-Xb77-Pubkey": c.pubkeyHex,
        "X-Xb77-Timestamp": String(ts),
        "X-Xb77-Nonce": toHex(nonce),
        "X-Xb77-Signature": toHex(sig),
      },
      body: payload,
    });
    const claimRes = await worker.fetch(claimReq, env);
    expect(claimRes.status).toBe(200);

    // Reset bucket KV (claim_credits already consumed 1 token; clear bucket so we start fresh on new tier).
    env.BUCKETS.store.clear();

    // Now we should be able to do many more submit_orders.
    let okCount = 0;
    for (let i = 0; i < 15; i++) {
      const req = await buildSignedSubmit(c);
      const r = await worker.fetch(req, env);
      if (r.status === 200) okCount++;
      await r.text();
    }
    // paid: burst=60, cost=3 → up to 20 fits. expect ≥15 OK.
    expect(okCount).toBeGreaterThanOrEqual(15);
  });
});

// Tests for apps/web/assets/src/lib/dapp-actions.js (wire schema 1.1).
//
// Asserts byte-identical canonical bytes vs the mock-gateway and a real
// signing path via XB77Keystore. Run from repo root:
//   bun test apps/web/test/dapp-actions.test.js

if (typeof globalThis.localStorage === "undefined") {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
    clear: () => store.clear(),
  };
}
if (typeof globalThis.window === "undefined") globalThis.window = globalThis;

import { test, expect, beforeAll, beforeEach } from "bun:test";
import "../assets/src/lib/keystore.js";
import "../assets/src/lib/dapp-actions.js";

const KS = () => globalThis.XB77Keystore;
const A  = () => globalThis.XB77Actions;
const I  = () => globalThis.XB77ActionsInternals;

const fromHex = (s) => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};

// Reference canonical formula (mirror of mock-gateway canonicalRequest).
function expectedCanonical(action, tsMs, nonce, payloadBytes) {
  const out = new Uint8Array(1 + 8 + 12 + payloadBytes.length);
  out[0] = action;
  const dv = new DataView(out.buffer);
  dv.setBigUint64(1, BigInt(tsMs), false);
  out.set(nonce, 9);
  out.set(payloadBytes, 21);
  return out;
}

beforeAll(() => {
  if (!A())  throw new Error("XB77Actions not loaded");
  if (!I())  throw new Error("XB77ActionsInternals not exposed — tests need internals");
});

beforeEach(async () => {
  KS().lock();
  await KS().generate("demo");
});

test("ACTION_BYTES matches the contract (submit_order=1, register_agent=2, claim_credits=3, query_pulse=4)", () => {
  expect(I().ACTION_BYTES).toEqual({
    submit_order: 0x01,
    register_agent: 0x02,
    claim_credits: 0x03,
    query_pulse: 0x04,
  });
});

test("canonicalBytes layout: action(1) || ts_be_u64(8) || nonce(12) || payload", () => {
  const nonce = fromHex("a1b2c3d4e5f607182" + "93a4b5c");
  const payload = new TextEncoder().encode('{"symbol":"SOL/USDC","amount":1000}');
  const got = I().canonicalBytes(0x01, 1_700_000_000_000, nonce, payload);
  const want = expectedCanonical(0x01, 1_700_000_000_000, nonce, payload);
  expect(Array.from(got)).toEqual(Array.from(want));
});

test("signEnvelope returns headers + raw-JSON body and a verifiable Ed25519 signature", async () => {
  const pubHex = KS().currentPubkey();
  const payload = JSON.stringify({ symbol: "SOL/USDC", amount: 1000 });
  const env = await I().signEnvelope("submit_order", payload);

  expect(env.body).toBe(payload);
  expect(env.headers["Content-Type"]).toBe("application/json");
  expect(env.headers["X-API-Version"]).toBe("v1");
  expect(env.headers["X-Xb77-Pubkey"]).toBe(pubHex);
  expect(env.headers["X-Xb77-Timestamp"]).toMatch(/^\d{13}$/);
  expect(env.headers["X-Xb77-Nonce"]).toMatch(/^[0-9a-f]{24}$/);
  expect(env.headers["X-Xb77-Signature"]).toMatch(/^[0-9a-f]{128}$/);

  const tsMs = Number(env.headers["X-Xb77-Timestamp"]);
  const nonce = fromHex(env.headers["X-Xb77-Nonce"]);
  const sig = fromHex(env.headers["X-Xb77-Signature"]);
  const canonical = expectedCanonical(0x01, tsMs, nonce, new TextEncoder().encode(payload));
  const pub = await crypto.subtle.importKey("raw", fromHex(pubHex), "Ed25519", false, ["verify"]);
  expect(await crypto.subtle.verify("Ed25519", pub, sig, canonical)).toBe(true);
});

test("signEnvelope payload is the raw JSON string the caller passed (no envelope wrapping)", async () => {
  const payload = JSON.stringify({ foo: "bar" });
  const env = await I().signEnvelope("query_pulse", payload);
  expect(env.body).toBe(payload);
  // body must NOT be wrapped in {payload:..., signature:..., agent_id:...}
  const parsed = JSON.parse(env.body);
  expect(parsed).toEqual({ foo: "bar" });
  expect(parsed).not.toHaveProperty("signature");
  expect(parsed).not.toHaveProperty("agent_id");
});

test("submitOrder() does NOT include agent_id in the outgoing payload", async () => {
  const captured = { url: null, init: null };
  globalThis.fetch = async (url, init) => {
    captured.url = url;
    captured.init = init;
    return new Response(JSON.stringify({ ok: true, data: { id: "p_test" } }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  };

  await A().submitOrder({ symbol: "SOL/USDC", amount: 1000, side: "buy", price: 250, idempotency_key: "k1" });

  const body = JSON.parse(captured.init.body);
  expect(body).not.toHaveProperty("agent_id");
  expect(body.symbol).toBe("SOL/USDC");
  expect(captured.init.headers["X-Xb77-Pubkey"]).toBe(KS().currentPubkey());
  expect(captured.init.headers["X-Idempotency-Key"]).toBe("k1");
});

test("registerAgent uses bootstrap path: pubkey in headers, no signature required", async () => {
  const captured = { url: null, init: null };
  globalThis.fetch = async (url, init) => {
    captured.url = url;
    captured.init = init;
    return new Response(JSON.stringify({ ok: true, data: { agent_id: "ag_xxx" } }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  };

  await A().registerAgent(KS().currentPubkey(), "merchant");

  expect(captured.url).toMatch(/\/api\/v1\/actions\/register_agent$/);
  expect(captured.init.headers["X-Xb77-Pubkey"]).toBe(KS().currentPubkey());
  const body = JSON.parse(captured.init.body);
  expect(body.intent_hint).toBe("merchant");
  // bootstrap may omit signature headers; pubkey is mandatory.
});

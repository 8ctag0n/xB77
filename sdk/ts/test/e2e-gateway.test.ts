/**
 * End-to-end test: SDK + real HTTP + a mock gateway running inside the test.
 *
 * The mock gateway is a tiny bun.serve() handler that:
 *   1. Parses the X-Xb77-* headers the SDK produced.
 *   2. Reconstructs the canonical bytes per addendum §A.1.
 *   3. Verifies the client signature with WebCrypto (independent of our WASM).
 *   4. Builds a response and signs it with WebCrypto Ed25519.
 *   5. Returns the response so the SDK can verify it back.
 *
 * This exercises the SDK exactly the way a production wrapper would:
 * fetch(req.url, { method: req.method, headers: req.headers, body: req.body }).
 *
 * Proves: HTTP transport works, headers survive, body is byte-identical
 * across the wire, gateway-side verification works in a vanilla TS stack
 * (i.e. anything implementing standard Ed25519 + the canonical-bytes spec
 * is interoperable with the SDK).
 */

import { test, expect, beforeAll, afterAll, describe } from "bun:test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { XB77, Action, Xb77Error, ErrorCode } from "../src/index.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");

let sdk: XB77;
let server: ReturnType<typeof Bun.serve>;
let gatewayPubkey: Uint8Array;
let gatewaySignKey: CryptoKey;

const PATH_TO_ACTION: Record<string, Action> = {
  "/submit_order": Action.SubmitOrder,
  "/register_agent": Action.RegisterAgent,
  "/claim_credits": Action.ClaimCredits,
  "/query_pulse": Action.QueryPulse,
};

function canonicalBytes(action: Action, ts: number, payload: Uint8Array): Uint8Array {
  const out = new Uint8Array(1 + 8 + payload.length);
  out[0] = action;
  const bts = BigInt(ts);
  for (let i = 0; i < 8; i++) out[1 + i] = Number((bts >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(payload, 9);
  return out;
}

function fromHex(s: string): Uint8Array {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function toHex(b: Uint8Array): string {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

beforeAll(async () => {
  const wasmBytes = new Uint8Array(await readFile(wasmPath));
  sdk = await XB77.load({ wasmBytes });

  // Gateway-side keys (lives in WebCrypto land — independent of our WASM).
  const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
  gatewayPubkey = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  gatewaySignKey = kp.privateKey;

  server = Bun.serve({
    port: 0, // random free port
    async fetch(req) {
      const url = new URL(req.url);
      const action = PATH_TO_ACTION[url.pathname];
      if (action === undefined) {
        return new Response("unknown action", { status: 404 });
      }

      const pkHex = req.headers.get("X-Xb77-Pubkey");
      const sigHex = req.headers.get("X-Xb77-Signature");
      const tsStr = req.headers.get("X-Xb77-Timestamp");
      if (!pkHex || !sigHex || !tsStr) {
        return new Response("missing auth headers", { status: 401 });
      }
      const body = new Uint8Array(await req.arrayBuffer());
      const ts = Number(tsStr);

      const clientPub = fromHex(pkHex);
      const sig = fromHex(sigHex);

      // Verify the client signature with WebCrypto (independent of WASM).
      const clientVerifyKey = await crypto.subtle.importKey(
        "raw", clientPub, "Ed25519", false, ["verify"],
      );
      const ok = await crypto.subtle.verify("Ed25519", clientVerifyKey, sig, canonicalBytes(action, ts, body));
      if (!ok) return new Response("bad signature", { status: 401 });

      // Build a response, sign it back with the gateway key.
      const echo = JSON.stringify({ status: "ok", echoed_action: action, echoed_body_len: body.length });
      const echoBytes = new TextEncoder().encode(echo);
      const responseTs = ts + 1;
      const responseSig = new Uint8Array(
        await crypto.subtle.sign("Ed25519", gatewaySignKey, canonicalBytes(action, responseTs, echoBytes)),
      );

      return new Response(echoBytes, {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "X-Xb77-Gateway-Timestamp": String(responseTs),
          "X-Xb77-Gateway-Signature": toHex(responseSig),
        },
      });
    },
  });
});

afterAll(() => {
  server.stop(true);
});

async function makeClientKeypair() {
  const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
  const rawPriv = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const rawPub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  const seed = rawPriv.slice(rawPriv.length - 32);
  const canonical = new Uint8Array(64);
  canonical.set(seed, 0);
  canonical.set(rawPub, 32);
  return canonical;
}

describe("e2e: SDK ↔ mock gateway over real HTTP", () => {
  test("full round-trip: build → POST → verify response", async () => {
    const priv = await makeClientKeypair();
    const ts = Math.floor(Date.now() / 1000);
    const payload = '{"symbol":"SOL/USDC","amount":1000000,"side":"buy"}';

    const req = sdk.buildSignedRequest({
      gatewayBase: server.url.origin,
      action: Action.SubmitOrder,
      payload,
      privkey: priv,
      timestampUnix: ts,
    });

    // The wrapper would normally do this for the user:
    const httpRes = await fetch(req.url, {
      method: req.method,
      headers: req.headers,
      body: req.body,
    });
    expect(httpRes.status).toBe(200);

    const responseBody = new Uint8Array(await httpRes.arrayBuffer());
    const responseTs = Number(httpRes.headers.get("X-Xb77-Gateway-Timestamp"));
    const responseSig = fromHex(httpRes.headers.get("X-Xb77-Gateway-Signature")!);

    // Verify the gateway's response with our WASM verifier — must not throw.
    expect(() =>
      sdk.verifyResponse({
        body: responseBody,
        expectedAction: Action.SubmitOrder,
        timestampUnix: responseTs,
        gatewayPubkey,
        signature: responseSig,
      }),
    ).not.toThrow();

    const parsed = JSON.parse(new TextDecoder().decode(responseBody));
    expect(parsed.status).toBe("ok");
    expect(parsed.echoed_action).toBe(Action.SubmitOrder);
  });

  test("gateway rejects request whose body was tampered after signing", async () => {
    const priv = await makeClientKeypair();
    const ts = Math.floor(Date.now() / 1000);
    const req = sdk.buildSignedRequest({
      gatewayBase: server.url.origin,
      action: Action.QueryPulse,
      payload: "{}",
      privkey: priv,
      timestampUnix: ts,
    });

    // Tamper the body in-flight — same length so headers don't lie about size.
    const httpRes = await fetch(req.url, {
      method: req.method,
      headers: req.headers,
      body: new TextEncoder().encode("XX"),
    });
    expect(httpRes.status).toBe(401);
  });

  test("a tampered gateway response is rejected by the client wrapper", async () => {
    const priv = await makeClientKeypair();
    const ts = Math.floor(Date.now() / 1000);
    const req = sdk.buildSignedRequest({
      gatewayBase: server.url.origin,
      action: Action.RegisterAgent,
      payload: '{"name":"alice"}',
      privkey: priv,
      timestampUnix: ts,
    });
    const httpRes = await fetch(req.url, { method: req.method, headers: req.headers, body: req.body });
    expect(httpRes.status).toBe(200);

    const responseBody = new Uint8Array(await httpRes.arrayBuffer());
    const responseTs = Number(httpRes.headers.get("X-Xb77-Gateway-Timestamp"));
    const goodSig = fromHex(httpRes.headers.get("X-Xb77-Gateway-Signature")!);

    // Flip the response body — same shape, different content.
    const tamperedBody = new TextEncoder().encode(
      new TextDecoder().decode(responseBody).replace("ok", "no"),
    );

    try {
      sdk.verifyResponse({
        body: tamperedBody,
        expectedAction: Action.RegisterAgent,
        timestampUnix: responseTs,
        gatewayPubkey,
        signature: goodSig,
      });
      throw new Error("verifyResponse should have rejected tampered body");
    } catch (e) {
      expect(e).toBeInstanceOf(Xb77Error);
      expect((e as Xb77Error).code).toBe(ErrorCode.InvalidSignature);
    }
  });
});

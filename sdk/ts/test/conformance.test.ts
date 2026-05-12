/**
 * Cross-stack conformance tests.
 *
 * The SDK has ONE crypto implementation (Zig core compiled to WASM), so
 * "TS vs Zig byte-identical" is tautological. The interesting question is:
 * does our canonical-bytes spec (addendum §A.1, schema 1.1) produce
 * signatures that the REST OF THE WORLD accepts as valid Ed25519?
 *
 * These tests answer that with WebCrypto's independent Ed25519 verifier:
 *
 *   1. Build a request with WASM → verify the signature with WebCrypto.
 *   2. Simulate a gateway response: sign with WebCrypto → verify with WASM.
 */

import { test, expect, beforeAll, describe } from "bun:test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { XB77, Action } from "../src/index.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");

let sdk: XB77;

beforeAll(async () => {
  const wasmBytes = new Uint8Array(await readFile(wasmPath));
  sdk = await XB77.load({ wasmBytes });
});

/** Build canonical bytes per addendum §A.1 schema 1.1:
 *  action(1) || ts_be_ms(8) || nonce(12) || payload */
function canonicalRequest(action: Action, timestampMs: number, nonce: Uint8Array, payload: Uint8Array): Uint8Array {
  const out = new Uint8Array(1 + 8 + 12 + payload.length);
  out[0] = action;
  const ts = BigInt(timestampMs);
  for (let i = 0; i < 8; i++) {
    out[1 + i] = Number((ts >> BigInt((7 - i) * 8)) & 0xffn);
  }
  out.set(nonce, 9);
  out.set(payload, 21);
  return out;
}

/** Response canonical: action(1) || ts_be_ms(8) || body (no nonce). */
function canonicalResponse(action: Action, timestampMs: number, body: Uint8Array): Uint8Array {
  const out = new Uint8Array(1 + 8 + body.length);
  out[0] = action;
  const ts = BigInt(timestampMs);
  for (let i = 0; i < 8; i++) {
    out[1 + i] = Number((ts >> BigInt((7 - i) * 8)) & 0xffn);
  }
  out.set(body, 9);
  return out;
}

function fromHex(s: string): Uint8Array {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function makeKeypair() {
  const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
  const rawPriv = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const rawPub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  const seed = rawPriv.slice(rawPriv.length - 32);
  const canonical = new Uint8Array(64);
  canonical.set(seed, 0);
  canonical.set(rawPub, 32);
  return {
    canonicalPriv: canonical,
    pub: rawPub,
    signKey: kp.privateKey,
    verifyKey: kp.publicKey,
  };
}

describe("conformance: WASM signature verifies under WebCrypto", () => {
  test.each([
    [Action.SubmitOrder, '{"symbol":"SOL/USDC","amount":1000}'],
    [Action.RegisterAgent, '{"name":"alice-agent","contact":"alice@xb77.dev"}'],
    [Action.ClaimCredits, '{"amount":500000}'],
    [Action.QueryPulse, "{}"],
  ])("action %i: WASM-signed request validates with WebCrypto Ed25519 verify", async (action, payloadStr) => {
    const kp = await makeKeypair();
    const timestampMs = 1_700_000_000_000;
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const payload = new TextEncoder().encode(payloadStr);

    const req = sdk.buildSignedRequest({
      gatewayBase: "https://gateway.xb77.dev",
      action,
      payload,
      privkey: kp.canonicalPriv,
      timestampMs,
      nonce,
    });

    const sigHex = req.headers["X-Xb77-Signature"];
    const pkHex = req.headers["X-Xb77-Pubkey"];
    const nonceHex = req.headers["X-Xb77-Nonce"];
    const sig = fromHex(sigHex);
    const pkFromHeader = fromHex(pkHex);
    const nonceFromHeader = fromHex(nonceHex);

    expect(pkFromHeader).toEqual(kp.pub);
    expect(nonceFromHeader).toEqual(nonce);

    const canonical = canonicalRequest(action, timestampMs, nonce, payload);
    const ok = await crypto.subtle.verify("Ed25519", kp.verifyKey, sig, canonical);
    expect(ok).toBe(true);
  });

  test("a single byte flip in the body invalidates the signature under WebCrypto", async () => {
    const kp = await makeKeypair();
    const ts = 1_700_000_500_000;
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const payload = new TextEncoder().encode('{"order":"buy"}');
    const req = sdk.buildSignedRequest({
      gatewayBase: "https://g",
      action: Action.SubmitOrder,
      payload,
      privkey: kp.canonicalPriv,
      timestampMs: ts,
      nonce,
    });
    const sig = fromHex(req.headers["X-Xb77-Signature"]);

    const tampered = new TextEncoder().encode('{"order":"sell"}');
    const canonical = canonicalRequest(Action.SubmitOrder, ts, nonce, tampered);
    const ok = await crypto.subtle.verify("Ed25519", kp.verifyKey, sig, canonical);
    expect(ok).toBe(false);
  });
});

describe("conformance: WebCrypto-signed response verifies through WASM verifyResponse", () => {
  test("a valid Ed25519 signature over canonical bytes is accepted by the WASM verifier", async () => {
    const gw = await makeKeypair();
    const responseBody = new TextEncoder().encode('{"status":"ok","order_id":"abc123"}');
    const ts = 1_700_001_000_000;
    const action = Action.SubmitOrder;

    const canonical = canonicalResponse(action, ts, responseBody);
    const sigBuf = await crypto.subtle.sign("Ed25519", gw.signKey, canonical);
    const signature = new Uint8Array(sigBuf);

    expect(() =>
      sdk.verifyResponse({
        body: responseBody,
        expectedAction: action,
        timestampMs: ts,
        gatewayPubkey: gw.pub,
        signature,
      }),
    ).not.toThrow();
  });

  test("a body tampered after signing is rejected by the WASM verifier", async () => {
    const gw = await makeKeypair();
    const originalBody = new TextEncoder().encode('{"status":"ok"}');
    const tamperedBody = new TextEncoder().encode('{"status":"!!"}');
    const ts = 1_700_001_111_000;
    const action = Action.ClaimCredits;

    const canonical = canonicalResponse(action, ts, originalBody);
    const sigBuf = await crypto.subtle.sign("Ed25519", gw.signKey, canonical);

    expect(() =>
      sdk.verifyResponse({
        body: tamperedBody,
        expectedAction: action,
        timestampMs: ts,
        gatewayPubkey: gw.pub,
        signature: new Uint8Array(sigBuf),
      }),
    ).toThrow();
  });

  test("wrong expected_action invalidates the verification", async () => {
    const gw = await makeKeypair();
    const body = new TextEncoder().encode('{"x":1}');
    const ts = 1_700_001_222_000;
    const canonical = canonicalResponse(Action.SubmitOrder, ts, body);
    const sigBuf = await crypto.subtle.sign("Ed25519", gw.signKey, canonical);

    expect(() =>
      sdk.verifyResponse({
        body,
        expectedAction: Action.QueryPulse,
        timestampMs: ts,
        gatewayPubkey: gw.pub,
        signature: new Uint8Array(sigBuf),
      }),
    ).toThrow();
  });
});

/**
 * Wrapper-level tests: exercise the public TypeScript API of @xb77/sdk
 * against the real xb77_core.wasm artifact.
 *
 * Run with: bun test
 */

import { test, expect, beforeAll, describe } from "bun:test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { XB77, Action, ErrorCode, Xb77Error } from "../src/index.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");

let sdk: XB77;
let wasmBytes: Uint8Array;

beforeAll(async () => {
  wasmBytes = new Uint8Array(await readFile(wasmPath));
  sdk = await XB77.load({ wasmBytes });
});

describe("XB77.load", () => {
  test("reports ABI version 1.x", () => {
    expect(sdk.abiVersion.major).toBe(1);
    expect(sdk.abiVersion.minor).toBeGreaterThanOrEqual(0);
  });
});

describe("keystore", () => {
  const enc = new TextEncoder();
  const dec = new TextDecoder();

  test("seal then unseal recovers the original plaintext", () => {
    const plain = enc.encode("the quick brown fox jumps over the lazy dog");
    const blob = sdk.keystore.seal(plain, "correct horse battery staple");

    expect(blob.length).toBe(plain.length + 44); // SEAL_OVERHEAD
    expect(blob).not.toEqual(plain); // ciphertext != plaintext

    const recovered = sdk.keystore.unseal(blob, "correct horse battery staple");
    expect(dec.decode(recovered)).toBe("the quick brown fox jumps over the lazy dog");
  });

  test("wrong password throws Xb77Error with InvalidPassword code", () => {
    const blob = sdk.keystore.seal(enc.encode("secret"), "right-pw");
    try {
      sdk.keystore.unseal(blob, "wrong-pw");
      throw new Error("should have thrown");
    } catch (e) {
      expect(e).toBeInstanceOf(Xb77Error);
      expect((e as Xb77Error).code).toBe(ErrorCode.InvalidPassword);
    }
  });

  test("two seals of the same plaintext produce different blobs (random salt/nonce)", () => {
    const plain = enc.encode("deterministic? no.");
    const a = sdk.keystore.seal(plain, "pw");
    const b = sdk.keystore.seal(plain, "pw");
    expect(a).not.toEqual(b);
  });

  test("pubkey extracts the trailing 32 bytes of the canonical secret key", () => {
    // Construct a fake canonical secret key: seed(32) || pubkey(32).
    const seed = new Uint8Array(32).fill(0xAA);
    const pk = new Uint8Array(32).fill(0xBB);
    const priv = new Uint8Array(64);
    priv.set(seed, 0);
    priv.set(pk, 32);
    expect(sdk.keystore.pubkey(priv)).toEqual(pk);
  });

  test("pubkey with wrong length throws InvalidInput", () => {
    expect(() => sdk.keystore.pubkey(new Uint8Array(32))).toThrow(Xb77Error);
  });
});

describe("buildSignedRequest", () => {
  // Generate a real Ed25519 keypair via the platform crypto API.
  // We need it in canonical std.crypto form: seed(32) || pubkey(32).
  async function makeKeypair(): Promise<{ priv: Uint8Array; pub: Uint8Array }> {
    // Bun + Node both support generateKey for Ed25519 via Web Crypto.
    const kp = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]) as CryptoKeyPair;
    const rawPriv = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
    const rawPub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
    // PKCS8 wraps the 32-byte seed at a known offset; for Ed25519 the seed
    // is the last 32 bytes of the PKCS8 blob (after the algo prefix).
    const seed = rawPriv.slice(rawPriv.length - 32);
    const priv = new Uint8Array(64);
    priv.set(seed, 0);
    priv.set(rawPub, 32);
    return { priv, pub: rawPub };
  }

  test("produces a POST request with the correct URL and headers", async () => {
    const { priv } = await makeKeypair();
    const nonce = new Uint8Array(12).fill(0xaa);
    const req = sdk.buildSignedRequest({
      gatewayBase: "https://gateway.xb77.dev",
      action: Action.SubmitOrder,
      payload: '{"symbol":"SOL/USDC","amount":1000}',
      privkey: priv,
      timestampMs: 1_700_000_000_000,
      nonce,
    });

    expect(req.method).toBe("POST");
    expect(req.url).toBe("https://gateway.xb77.dev/api/v1/actions/submit_order");
    expect(req.headers["Content-Type"]).toBe("application/json");
    expect(req.headers["X-API-Version"]).toBe("v1");
    expect(req.headers["X-Xb77-Timestamp"]).toBe("1700000000000");
    expect(req.headers["X-Xb77-Nonce"]).toMatch(/^[0-9a-f]{24}$/);
    expect(req.headers["X-Xb77-Pubkey"]).toMatch(/^[0-9a-f]{64}$/);
    expect(req.headers["X-Xb77-Signature"]).toMatch(/^[0-9a-f]{128}$/);
    expect(new TextDecoder().decode(req.body)).toBe('{"symbol":"SOL/USDC","amount":1000}');
  });

  test("URL maps each action to its canonical path", async () => {
    const { priv } = await makeKeypair();
    const nonce = new Uint8Array(12);
    const tests: Array<[Action, string]> = [
      [Action.SubmitOrder, "submit_order"],
      [Action.RegisterAgent, "register_agent"],
      [Action.ClaimCredits, "claim_credits"],
      [Action.QueryPulse, "query_pulse"],
    ];
    for (const [action, suffix] of tests) {
      const req = sdk.buildSignedRequest({
        gatewayBase: "https://g.xb77/",
        action,
        payload: "{}",
        privkey: priv,
        timestampMs: 1,
        nonce,
      });
      expect(req.url).toBe(`https://g.xb77/api/v1/actions/${suffix}`);
    }
  });

  test("rejects privkey of wrong length", async () => {
    expect(() =>
      sdk.buildSignedRequest({
        gatewayBase: "https://g",
        action: Action.QueryPulse,
        payload: "{}",
        privkey: new Uint8Array(32),
        timestampMs: 1,
        nonce: new Uint8Array(12),
      }),
    ).toThrow(Xb77Error);
  });

  test("rejects nonce of wrong length", async () => {
    const { priv } = await makeKeypair();
    expect(() =>
      sdk.buildSignedRequest({
        gatewayBase: "https://g",
        action: Action.QueryPulse,
        payload: "{}",
        privkey: priv,
        timestampMs: 1,
        nonce: new Uint8Array(8),
      }),
    ).toThrow(Xb77Error);
  });
});

describe("verifyResponse", () => {
  test("InvalidSignature when body is tampered", async () => {
    try {
      sdk.verifyResponse({
        body: new TextEncoder().encode('{"status":"ok"}'),
        expectedAction: Action.SubmitOrder,
        timestampMs: 1_700_000_000_000,
        gatewayPubkey: new Uint8Array(32).fill(0x11),
        signature: new Uint8Array(64).fill(0x22),
      });
      throw new Error("should have thrown");
    } catch (e) {
      expect(e).toBeInstanceOf(Xb77Error);
      expect((e as Xb77Error).code).toBe(ErrorCode.InvalidSignature);
    }
  });

  test("rejects gatewayPubkey of wrong length", () => {
    expect(() =>
      sdk.verifyResponse({
        body: new Uint8Array(0),
        expectedAction: Action.SubmitOrder,
        timestampMs: 1,
        gatewayPubkey: new Uint8Array(16),
        signature: new Uint8Array(64),
      }),
    ).toThrow(Xb77Error);
  });
});

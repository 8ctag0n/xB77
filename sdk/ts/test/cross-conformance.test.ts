/**
 * Cross-language byte-identical conformance test.
 *
 * Both wrappers (TS and Rust) consume the same xb77_core.wasm artifact, so
 * given identical inputs they MUST produce byte-identical signed requests.
 * This test makes that equality observable by:
 *
 *   1. Generating a real Ed25519 keypair (WebCrypto, exported to PKCS8/raw).
 *   2. Building a request in TypeScript via the WASM wrapper.
 *   3. Spawning the Rust example binary with the same inputs.
 *   4. Asserting the URL, headers, and body match byte-for-byte.
 *
 * Skipped automatically if cargo is unavailable in PATH.
 */

import { test, expect, beforeAll, describe } from "bun:test";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

import { XB77, Action } from "../src/index.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");
const rustCrateDir = path.resolve(here, "../../rs");

let sdk: XB77;
let cargoOk = false;

beforeAll(async () => {
  const wasmBytes = new Uint8Array(await readFile(wasmPath));
  sdk = await XB77.load({ wasmBytes });

  // Probe cargo availability quickly. If absent, the suite still loads
  // but the test below will skip with a clear message.
  const probe = spawnSync("cargo", ["--version"], { encoding: "utf8" });
  cargoOk = probe.status === 0;
});

function toHex(b: Uint8Array): string {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

async function realKeypair(): Promise<{ priv: Uint8Array; pub: Uint8Array }> {
  const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const pub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
  const seed = pkcs8.slice(pkcs8.length - 32);
  const priv = new Uint8Array(64);
  priv.set(seed, 0);
  priv.set(pub, 32);
  return { priv, pub };
}

describe("cross-conformance: TS ↔ Rust produce byte-identical signed requests", () => {
  test.each([
    [Action.SubmitOrder, '{"symbol":"SOL/USDC","amount":1000000,"side":"buy"}', 1_700_000_000_000],
    [Action.RegisterAgent, '{"name":"alice","contact":"alice@xb77.dev"}', 1_700_000_100_000],
    [Action.ClaimCredits, '{"amount":500000}', 1_700_000_200_000],
    [Action.QueryPulse, "{}", 1_700_000_300_000],
  ])("action %i: TS WASM output == Rust wasmtime output", async (action, payload, ts) => {
    if (!cargoOk) {
      console.warn("[cross-conformance] cargo not available, skipping");
      return;
    }

    const { priv } = await realKeypair();
    const gateway = "https://gateway.xb77.dev";
    const nonce = crypto.getRandomValues(new Uint8Array(12));

    // TS side
    const tsReq = sdk.buildSignedRequest({
      gatewayBase: gateway,
      action,
      payload,
      privkey: priv,
      timestampMs: ts,
      nonce,
    });

    // Rust side: spawn the example binary, feed inputs via env.
    const rustResult = spawnSync(
      "cargo",
      ["run", "--quiet", "--example", "cross_fixture"],
      {
        cwd: rustCrateDir,
        env: {
          ...process.env,
          XB77_PRIV_HEX: toHex(priv),
          XB77_PAYLOAD: payload,
          XB77_TIMESTAMP: String(ts),
          XB77_NONCE_HEX: toHex(nonce),
          XB77_ACTION: String(action),
          XB77_GATEWAY: gateway,
        },
        encoding: "utf8",
      },
    );
    if (rustResult.status !== 0) {
      throw new Error(
        `cargo run --example cross_fixture exited ${rustResult.status}: ${rustResult.stderr}`,
      );
    }
    const rustJson = JSON.parse(rustResult.stdout.trim());

    // URL & method identical.
    expect(rustJson.url).toBe(tsReq.url);
    expect(rustJson.method).toBe(tsReq.method);

    // Headers identical (same keys, same values, regardless of order).
    expect(rustJson.headers).toEqual(tsReq.headers);

    // Body byte-identical.
    expect(rustJson.body_hex).toBe(toHex(tsReq.body));
  }, 60_000); // cargo cold start can take a few seconds
});

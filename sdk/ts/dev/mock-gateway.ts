/**
 * Standalone mock gateway for local e2e.
 *
 * Mirrors the bun.serve() handler from `test/e2e-gateway.test.ts` but runs
 * as a long-lived process so the SDK + CLI can exercise it from real HTTP
 * calls. Used by `scripts/e2e_local.sh`.
 *
 * Boot:
 *   bun run sdk/ts/dev/mock-gateway.ts [--port PORT] [--pubkey-out PATH]
 *
 * The gateway generates a fresh Ed25519 keypair at boot and prints its
 * public key (hex) to stdout. If `--pubkey-out` is given, also writes
 * `pubkey_hex\n` to that file so shell orchestrators can capture it
 * deterministically.
 *
 * Endpoints (POST):
 *   /submit_order   /register_agent   /claim_credits   /query_pulse
 *
 * Each verifies the client's X-Xb77-Signature with WebCrypto (independent
 * of our WASM stack), then echoes a Ed25519-signed JSON response.
 */

import { writeFile } from "node:fs/promises";

const args = parseArgs(process.argv.slice(2));
const port = Number(args.port ?? process.env.XB77_GATEWAY_PORT ?? 8787);
const pubkeyOutPath: string | undefined = args["pubkey-out"];

const ACTION_PATHS: Record<string, number> = {
  "/submit_order": 0x01,
  "/register_agent": 0x02,
  "/claim_credits": 0x03,
  "/query_pulse": 0x04,
  "/api/v1/actions/submit_order": 0x01,
  "/api/v1/actions/register_agent": 0x02,
  "/api/v1/actions/claim_credits": 0x03,
  "/api/v1/actions/query_pulse": 0x04,
};

function canonicalRequest(action: number, ts_ms: number, nonce: Uint8Array, payload: Uint8Array): Uint8Array {
  // Schema 1.1: action(1) || ts_be_ms(8) || nonce(12) || payload
  const out = new Uint8Array(1 + 8 + 12 + payload.length);
  out[0] = action;
  const bts = BigInt(ts_ms);
  for (let i = 0; i < 8; i++) out[1 + i] = Number((bts >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(nonce, 9);
  out.set(payload, 21);
  return out;
}

function canonicalResponse(action: number, ts_ms: number, body: Uint8Array): Uint8Array {
  // Response canonical: action(1) || ts_be_ms(8) || body (no nonce on response side).
  const out = new Uint8Array(1 + 8 + body.length);
  out[0] = action;
  const bts = BigInt(ts_ms);
  for (let i = 0; i < 8; i++) out[1 + i] = Number((bts >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(body, 9);
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

const kp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
const gatewayPubkey = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
const gatewayPubkeyHex = toHex(gatewayPubkey);

const server = Bun.serve({
  port,
  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname === "/_pubkey") {
      return new Response(gatewayPubkeyHex + "\n", {
        headers: { "Content-Type": "text/plain" },
      });
    }
    const action = ACTION_PATHS[url.pathname];
    if (action === undefined) {
      return new Response("unknown action: " + url.pathname, { status: 404 });
    }

    const pkHex = req.headers.get("X-Xb77-Pubkey");
    const sigHex = req.headers.get("X-Xb77-Signature");
    const tsStr = req.headers.get("X-Xb77-Timestamp");
    const nonceHex = req.headers.get("X-Xb77-Nonce");
    if (!pkHex || !sigHex || !tsStr || !nonceHex) {
      return new Response("missing auth headers", { status: 401 });
    }

    const body = new Uint8Array(await req.arrayBuffer());
    const ts_ms = Number(tsStr);
    const clientPub = fromHex(pkHex);
    const sig = fromHex(sigHex);
    const nonce = fromHex(nonceHex);
    if (nonce.length !== 12) return new Response("bad nonce", { status: 401 });

    const clientVerifyKey = await crypto.subtle.importKey(
      "raw", clientPub, "Ed25519", false, ["verify"],
    );
    const ok = await crypto.subtle.verify(
      "Ed25519", clientVerifyKey, sig, canonicalRequest(action, ts_ms, nonce, body),
    );
    if (!ok) return new Response("bad signature", { status: 401 });

    // Build response, sign it back with our gateway key.
    const echo = JSON.stringify({
      status: "ok",
      action,
      client_pubkey: pkHex,
      echoed_body_len: body.length,
    });
    const echoBytes = new TextEncoder().encode(echo);
    const responseTs = ts_ms + 1;
    const responseSig = new Uint8Array(
      await crypto.subtle.sign("Ed25519", kp.privateKey, canonicalResponse(action, responseTs, echoBytes)),
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

console.log(`[mock-gateway] listening on ${server.url.toString()}`);
console.log(`[mock-gateway] gateway_pubkey_hex=${gatewayPubkeyHex}`);
if (pubkeyOutPath) {
  await writeFile(pubkeyOutPath, gatewayPubkeyHex + "\n");
  console.log(`[mock-gateway] pubkey written to ${pubkeyOutPath}`);
}
console.log(`[mock-gateway] actions: ${Object.keys(ACTION_PATHS).join(", ")}`);
console.log(`[mock-gateway] GET /_pubkey returns the gateway pubkey hex`);

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const eq = key.indexOf("=");
      if (eq >= 0) {
        out[key.slice(0, eq)] = key.slice(eq + 1);
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith("--")) {
        out[key] = argv[i + 1];
        i++;
      } else {
        out[key] = "true";
      }
    }
  }
  return out;
}

// Tests for apps/web/assets/src/lib/keystore.js
//
// Run from repo root:
//   bun test apps/web/test/keystore.test.js
//
// The keystore is a side-effect script that exposes globalThis.XB77Keystore.
// It must:
//   - generate(password) → real Ed25519 keypair, sealed blob via PBKDF2+AES-GCM
//   - import(blob, password) → reproduces the same pubkey, fails on wrong pw
//   - signCanonical(bytes) → 64-byte Ed25519 signature, verifiable by pubkey
//   - currentAgentId() → "ag_" + hex(sha256(pubkey)[:9])

// Minimal localStorage shim so the module loads under Bun.
if (typeof globalThis.localStorage === "undefined") {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
    clear: () => store.clear(),
  };
}

import { test, expect, beforeAll } from "bun:test";
import "../assets/src/lib/keystore.js";

const KS = () => globalThis.XB77Keystore;

const toHex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const fromHex = (s) => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};

beforeAll(() => {
  if (!KS()) throw new Error("XB77Keystore not loaded — keystore.js did not attach to globalThis");
});

test("module exposes the expected public API", () => {
  const k = KS();
  for (const m of ["generate", "import", "loadFromStorage", "signCanonical", "currentPubkey", "currentAgentId", "lock"]) {
    expect(typeof k[m]).toBe("function");
  }
});

test("generate() returns real Ed25519 pubkey (32B/64hex) and an ag_ agent_id", async () => {
  const k = KS();
  const r = await k.generate("demo");
  expect(r.pubkeyHex).toMatch(/^[0-9a-f]{64}$/);
  expect(r.agentId).toMatch(/^ag_[0-9a-f]{18}$/);
  expect(typeof r.sealedBlob).toBe("string");
  expect(r.sealedBlob.length).toBeGreaterThan(0);
  expect(r.sessionReady).toBe(true);
});

test("agentId is sha256(pubkey)[:9] hex prefixed with ag_", async () => {
  const k = KS();
  k.lock();
  const r = await k.generate("demo");
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", fromHex(r.pubkeyHex)));
  expect(r.agentId).toBe("ag_" + toHex(digest.slice(0, 9)));
  expect(k.currentAgentId()).toBe(r.agentId);
  expect(k.currentPubkey()).toBe(r.pubkeyHex);
});

test("signCanonical returns a 64-byte signature that verifies against the pubkey", async () => {
  const k = KS();
  k.lock();
  const r = await k.generate("demo");
  const msg = new TextEncoder().encode("xb77 canonical test message");
  const sig = await k.signCanonical(msg);
  expect(sig).toBeInstanceOf(Uint8Array);
  expect(sig.length).toBe(64);
  const pub = await crypto.subtle.importKey("raw", fromHex(r.pubkeyHex), "Ed25519", false, ["verify"]);
  const ok = await crypto.subtle.verify("Ed25519", pub, sig, msg);
  expect(ok).toBe(true);
});

test("import(blob, password) with correct password reproduces the same pubkey", async () => {
  const k = KS();
  k.lock();
  const a = await k.generate("hunter2");
  const sealed = a.sealedBlob;
  k.lock();
  expect(k.currentPubkey()).toBeNull();
  const b = await k.import(sealed, "hunter2");
  expect(b.pubkeyHex).toBe(a.pubkeyHex);
  expect(b.agentId).toBe(a.agentId);
  expect(k.currentPubkey()).toBe(a.pubkeyHex);

  // and signCanonical still works after re-import
  const msg = new TextEncoder().encode("after import");
  const sig = await k.signCanonical(msg);
  const pub = await crypto.subtle.importKey("raw", fromHex(a.pubkeyHex), "Ed25519", false, ["verify"]);
  expect(await crypto.subtle.verify("Ed25519", pub, sig, msg)).toBe(true);
});

test("import with wrong password rejects", async () => {
  const k = KS();
  k.lock();
  const a = await k.generate("right-pw");
  k.lock();
  await expect(k.import(a.sealedBlob, "wrong-pw")).rejects.toThrow();
});

test("lock() clears in-memory session and signCanonical fails afterwards", async () => {
  const k = KS();
  k.lock();
  await k.generate("demo");
  k.lock();
  expect(k.currentPubkey()).toBeNull();
  expect(k.currentAgentId()).toBeNull();
  await expect(k.signCanonical(new Uint8Array([1, 2, 3]))).rejects.toThrow();
});

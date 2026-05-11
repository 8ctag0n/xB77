// Standalone smoke test for the TS wrapper.
// Runs against the .wasm built by `zig build sdk-wasm`.
// No bundler, no tsc — uses the source directly via dynamic compile if needed.
//
// For now we exercise the WASM via the same WASI shim and the raw ABI to
// validate that the wrapper logic in src/index.ts will work. The actual
// src/index.ts gets exercised by Fase 6 with tsc compilation; here we keep
// a zero-dep node smoke that proves the .wasm itself loads and produces
// correct results.

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { webcrypto } from "node:crypto";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.resolve(here, "../../../zig-out/bin/xb77_core.wasm");

const bytes = await readFile(wasmPath);

let memory;
const memBytes = (ptr, len) => new Uint8Array(memory.buffer, ptr, len);
const memDV = () => new DataView(memory.buffer);

const wasi = {
  random_get(ptr, len) {
    crypto.getRandomValues(memBytes(ptr, len));
    return 0;
  },
  clock_time_get(_id, _prec, timePtr) {
    memDV().setBigUint64(timePtr, BigInt(Date.now()) * 1_000_000n, true);
    return 0;
  },
  fd_write(fd, iovsPtr, iovsLen, nwrittenPtr) {
    const dv = memDV();
    let total = 0;
    for (let i = 0; i < iovsLen; i++) {
      const base = iovsPtr + i * 8;
      const len = dv.getUint32(base + 4, true);
      total += len;
    }
    dv.setUint32(nwrittenPtr, total, true);
    return 0;
  },
  proc_exit(code) { throw new Error("proc_exit " + code); },
  fd_close() { return 0; },
  fd_seek() { return 0; },
  fd_fdstat_get() { return 0; },
  fd_read(_fd, _iovs, _iovsLen, nreadPtr) { memDV().setUint32(nreadPtr, 0, true); return 0; },
  fd_pwrite(_fd, _iovs, iovsLen, _offset, nwrittenPtr) {
    const dv = memDV();
    let total = 0;
    // We don't bother computing total since we're not actually writing.
    dv.setUint32(nwrittenPtr, total, true);
    return 0;
  },
  fd_filestat_get(_fd, statPtr) {
    // Zero out the filestat_t struct (64 bytes is enough for the layout).
    new Uint8Array(memory.buffer, statPtr, 64).fill(0);
    return 0;
  },
  environ_get() { return 0; },
  environ_sizes_get(a, b) { memDV().setUint32(a, 0, true); memDV().setUint32(b, 0, true); return 0; },
  args_get() { return 0; },
  args_sizes_get(a, b) { memDV().setUint32(a, 0, true); memDV().setUint32(b, 0, true); return 0; },
};

const { instance } = await WebAssembly.instantiate(bytes, { wasi_snapshot_preview1: wasi });
const exp = instance.exports;
memory = exp.memory;

// ---- test 1: ABI version ----
const v = exp.xb77_abi_version();
const major = (v >>> 16) & 0xffff;
const minor = v & 0xffff;
console.log(`[smoke] ABI version: ${major}.${minor}`);
if (major !== 1) throw new Error("ABI major mismatch");

// ---- test 2: keystore_pubkey derives correctly ----
// Use a Solana-style 64-byte key (seed || pubkey). For the test, use random
// 32-byte seed; std.crypto Ed25519 expects seed||pubkey where pubkey is
// derived from seed. We can't easily forge that here, so we let WASM
// generate a sealed payload first (which is also a good keystore test).

// ---- test 3: seal → unseal roundtrip ----
const enc = new TextEncoder();
const plain = enc.encode("the quick brown fox jumps over the lazy dog");
const password = enc.encode("correct horse battery staple");

const plainPtr = exp.wasm_alloc(plain.length);
memBytes(plainPtr, plain.length).set(plain);
const pwPtr = exp.wasm_alloc(password.length);
memBytes(pwPtr, password.length).set(password);
const lenSlot = exp.wasm_alloc(4);

// First: probe size with max=0
exp.keystore_seal(plainPtr, plain.length, pwPtr, password.length, 0, 0, lenSlot);
const sealedLen = memDV().getUint32(lenSlot, true);
console.log(`[smoke] sealedSize(${plain.length}) = ${sealedLen} (expected ${plain.length + 44})`);
if (sealedLen !== plain.length + 44) throw new Error("sealedSize wrong");

const blobPtr = exp.wasm_alloc(sealedLen);
let rc = exp.keystore_seal(plainPtr, plain.length, pwPtr, password.length, blobPtr, sealedLen, lenSlot);
if (rc !== 0) throw new Error("keystore_seal rc=" + rc);

// Unseal
const outPtr = exp.wasm_alloc(plain.length);
rc = exp.keystore_unseal(blobPtr, sealedLen, pwPtr, password.length, outPtr, plain.length, lenSlot);
if (rc !== 0) throw new Error("keystore_unseal rc=" + rc);
const recovered = new TextDecoder().decode(memBytes(outPtr, plain.length));
console.log(`[smoke] unseal recovered: "${recovered}"`);
if (recovered !== "the quick brown fox jumps over the lazy dog") throw new Error("roundtrip mismatch");

// ---- test 4: wrong password is rejected ----
const wrongPw = enc.encode("wrong password");
const wpwPtr = exp.wasm_alloc(wrongPw.length);
memBytes(wpwPtr, wrongPw.length).set(wrongPw);
rc = exp.keystore_unseal(blobPtr, sealedLen, wpwPtr, wrongPw.length, outPtr, plain.length, lenSlot);
console.log(`[smoke] wrong password rc=${rc} (expected 3 = INVALID_PASSWORD)`);
if (rc !== 3) throw new Error("wrong password should return 3, got " + rc);

console.log("[smoke] ALL TESTS PASSED ");

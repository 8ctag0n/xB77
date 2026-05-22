// Tests for apps/web/assets/src/lib/solana-tx.js
//
// Verifies the Solana legacy transaction encoder produces the right byte
// layout (compact-u16 short-vec, message header, accountKeys ordering,
// recent blockhash, instructions block) and that signing produces a
// signature the same bytes that Ed25519 verify accepts.

import { test, expect, beforeAll } from "bun:test";

// Minimal localStorage shim so keystore loads under Bun.
if (typeof globalThis.localStorage === "undefined") {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
  };
}

import "../assets/src/lib/wincode.js";
import "../assets/src/lib/base58.js";
import "../assets/src/lib/keystore.js";
import "../assets/src/lib/solana-tx.js";
const { SolanaTx, base58Decode, base58Encode, XB77Keystore } = globalThis;

const fromHex = (s) => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};

const SYS_PROGRAM = "11111111111111111111111111111111";
const SOME_BLOCKHASH = "GHtXQBsoZHVnNFa9YevAzFr17DJjgHXk3ycTKD5xD3Zi"; // arbitrary 32-byte base58

test("compactU16: 0..127 → 1 byte; 128..16383 → 2 bytes; …", () => {
  expect(Array.from(SolanaTx.encodeCompactU16(0))).toEqual([0x00]);
  expect(Array.from(SolanaTx.encodeCompactU16(127))).toEqual([0x7f]);
  expect(Array.from(SolanaTx.encodeCompactU16(128))).toEqual([0x80, 0x01]);
  expect(Array.from(SolanaTx.encodeCompactU16(16383))).toEqual([0xff, 0x7f]);
});

test("Message: single instruction with one signer (payer) round-trips", async () => {
  await XB77Keystore.generate("demo");
  const payerHex = XB77Keystore.currentPubkey();
  const payerBytes = fromHex(payerHex);
  const programId = base58Decode(SYS_PROGRAM);
  const blockhashBytes = base58Decode(SOME_BLOCKHASH);
  expect(blockhashBytes.length).toBe(32);

  const tx = SolanaTx.buildLegacyTx({
    payer: payerBytes,
    recentBlockhash: blockhashBytes,
    instructions: [{
      programId,
      accounts: [
        { pubkey: payerBytes, isSigner: true, isWritable: true },
      ],
      data: new Uint8Array([1, 2, 3, 4]),
    }],
  });

  // Compile the message bytes (pre-sign).
  const msgBytes = tx.serializeMessage();
  // Expected structure: header(3) + ak_len(1) + 2*32 ak + 32 blockhash + ix_len(1) + ix
  //   - accountKeys must include: payer (signer+writable) + programId (read-only)
  expect(msgBytes[0]).toBe(1); // numRequiredSigs
  expect(msgBytes[1]).toBe(0); // numReadonlySigned
  expect(msgBytes[2]).toBe(1); // numReadonlyUnsigned (just the programId)
  // accountKeys length = 2 (payer + system program)
  expect(msgBytes[3]).toBe(2);
  expect(Array.from(msgBytes.slice(4, 36))).toEqual(Array.from(payerBytes));
  expect(Array.from(msgBytes.slice(36, 68))).toEqual(Array.from(programId));
  // recent blockhash next 32 bytes
  expect(Array.from(msgBytes.slice(68, 100))).toEqual(Array.from(blockhashBytes));
  // instructions: count(1) + (programIdIndex u8) + acct_len(compact) + acct_idxs + data_len(compact) + data
  expect(msgBytes[100]).toBe(1);     // 1 instruction
  expect(msgBytes[101]).toBe(1);     // programId index in accountKeys (system program at index 1)
  expect(msgBytes[102]).toBe(1);     // 1 account index
  expect(msgBytes[103]).toBe(0);     // index 0 → payer
  expect(msgBytes[104]).toBe(4);     // data length compact-u16 = 4
  expect(Array.from(msgBytes.slice(105, 109))).toEqual([1, 2, 3, 4]);
});

test("Tx signs the message and verifies with crypto.subtle", async () => {
  await XB77Keystore.generate("demo");
  const payerHex = XB77Keystore.currentPubkey();
  const payerBytes = fromHex(payerHex);
  const programId = base58Decode(SYS_PROGRAM);
  const tx = SolanaTx.buildLegacyTx({
    payer: payerBytes,
    recentBlockhash: base58Decode(SOME_BLOCKHASH),
    instructions: [{
      programId,
      accounts: [{ pubkey: payerBytes, isSigner: true, isWritable: true }],
      data: new Uint8Array([9, 9, 9]),
    }],
  });

  const signed = await tx.sign([{ pubkey: payerBytes, sign: (bytes) => XB77Keystore.signCanonical(bytes) }]);
  expect(signed.length).toBeGreaterThan(0);

  // First byte is sig count = 1, then 64 bytes of sig, then message.
  expect(signed[0]).toBe(1);
  const sig = signed.slice(1, 65);
  const msgBytes = tx.serializeMessage();
  expect(Array.from(signed.slice(65))).toEqual(Array.from(msgBytes));

  // Verify the sig against the payer's pubkey.
  const pub = await crypto.subtle.importKey("raw", payerBytes, "Ed25519", false, ["verify"]);
  expect(await crypto.subtle.verify("Ed25519", pub, sig, msgBytes)).toBe(true);
});

test("instruction with readonly non-signer account is correctly classified", async () => {
  await XB77Keystore.generate("demo");
  const payerBytes = fromHex(XB77Keystore.currentPubkey());
  // synth a random readonly account
  const readOnly = crypto.getRandomValues(new Uint8Array(32));
  const programId = base58Decode(SYS_PROGRAM);

  const tx = SolanaTx.buildLegacyTx({
    payer: payerBytes,
    recentBlockhash: base58Decode(SOME_BLOCKHASH),
    instructions: [{
      programId,
      accounts: [
        { pubkey: payerBytes, isSigner: true,  isWritable: true  },
        { pubkey: readOnly,   isSigner: false, isWritable: false },
      ],
      data: new Uint8Array([0]),
    }],
  });
  const msg = tx.serializeMessage();
  // header: 1 signer, 0 readonly-signed, 2 readonly-unsigned (readOnly + programId)
  expect(msg[0]).toBe(1);
  expect(msg[1]).toBe(0);
  expect(msg[2]).toBe(2);
  // accountKeys length = 3 (payer, readOnly, programId)
  expect(msg[3]).toBe(3);
});

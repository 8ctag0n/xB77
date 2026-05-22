// Tests for apps/web/assets/src/lib/wincode.js
//
// Source of truth: tests/compression_e2e.zig (the production Zig client that
// the on-chain xb77.iopression program accepts) produces exactly 125 bytes
// for CompressionInstruction::VerifyTransition with a minimal payload.
//
// Layout (per tests/wincode_layout.rs + compression_e2e.zig):
//   disc        u32 LE          = 4
//   old_root    [u8; 32]        = 32
//   new_root    [u8; 32]        = 32
//   index       u64 LE          = 8
//   siblings    Vec<[u8; 32]>   = u64 LE len + N*32
//   amount      u64 LE          = 8
//   type        u8              = 1
//   tx_hash     [u8; 32]        = 32
//   total                       = 125  (with empty siblings)

import { test, expect } from "bun:test";
import "../assets/src/lib/wincode.js";
const { Wincode } = globalThis;

const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";

const fromHex = (s) => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};
const toHex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

test("module exports a Wincode namespace", () => {
  expect(typeof Wincode).toBe("object");
  for (const k of ["Writer", "Reader", "encode", "decode"]) expect(Wincode[k]).toBeDefined();
});

test("u8/u16/u32/u64 are little-endian", () => {
  const w = new Wincode.Writer();
  w.u8(0xab);
  w.u16(0x1234);
  w.u32(0xdeadbeef);
  w.u64(0x0123456789abcdefn);
  expect(toHex(w.bytes())).toBe(
    "ab" + "3412" + "efbeadde" + "efcdab8967452301"
  );
});

test("bool is 1 byte 0x00 / 0x01", () => {
  const w = new Wincode.Writer();
  w.bool(false); w.bool(true);
  expect(Array.from(w.bytes())).toEqual([0x00, 0x01]);
});

test("fixed-size byte arrays write inline (no length prefix)", () => {
  const w = new Wincode.Writer();
  w.fixed(new Uint8Array([1, 2, 3, 4]), 4);
  expect(Array.from(w.bytes())).toEqual([1, 2, 3, 4]);
});

test("fixed array length mismatch throws", () => {
  const w = new Wincode.Writer();
  expect(() => w.fixed(new Uint8Array([1, 2]), 4)).toThrow();
});

test("Vec<u8> is u64 LE length prefix + bytes", () => {
  const w = new Wincode.Writer();
  w.vecU8(new Uint8Array([0xaa, 0xbb, 0xcc]));
  expect(toHex(w.bytes())).toBe("0300000000000000" + "aabbcc");
});

test("empty Vec writes 8 zero bytes (u64 LE 0)", () => {
  const w = new Wincode.Writer();
  w.vecU8(new Uint8Array(0));
  expect(Array.from(w.bytes())).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
});

test("enum tag is u32 LE", () => {
  const w = new Wincode.Writer();
  w.enumTag(0);
  expect(Array.from(w.bytes())).toEqual([0, 0, 0, 0]);
  const w2 = new Wincode.Writer();
  w2.enumTag(3);
  expect(Array.from(w2.bytes())).toEqual([3, 0, 0, 0]);
});

test("Option<T>: None = 0x00, Some(x) = 0x01 || encode(x)", () => {
  const w = new Wincode.Writer();
  w.option(null, () => {});
  expect(Array.from(w.bytes())).toEqual([0x00]);
  const w2 = new Wincode.Writer();
  w2.option(42, (v) => w2.u32(v));
  expect(toHex(w2.bytes())).toBe("01" + "2a000000");
});

// ── End-to-end fixture: matches Zig client's 125-byte output ──
test("VerifyTransition fixture round-trips to the exact 125-byte payload", () => {
  const w = new Wincode.Writer();
  // disc = 0 (VerifyTransition variant)
  w.enumTag(0);
  // old_root [32] = zeros
  w.fixed(new Uint8Array(32), 32);
  // new_root [32]
  w.fixed(fromHex(NEW_ROOT_HEX), 32);
  // index u64 = 0
  w.u64(0n);
  // siblings: empty Vec → just u64 len = 0
  w.u64(0n);
  // amount u64 = 1
  w.u64(1n);
  // type u8 = 0
  w.u8(0);
  // tx_hash [32] = zeros
  w.fixed(new Uint8Array(32), 32);

  const out = w.bytes();
  expect(out.length).toBe(125);
  // Confirm the leading bytes match the known prefix.
  expect(Array.from(out.slice(0, 4))).toEqual([0, 0, 0, 0]); // disc u32 LE 0
  // After 4 + 32 + 32 = 68, index u64 LE 0 should be 8 zeros
  expect(Array.from(out.slice(68, 76))).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  // siblings len at 76..84, all zero
  expect(Array.from(out.slice(76, 84))).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  // amount=1 at 84..92
  expect(Array.from(out.slice(84, 92))).toEqual([1, 0, 0, 0, 0, 0, 0, 0]);
  // type=0 at 92
  expect(out[92]).toBe(0);
});

test("Reader inverse of Writer for primitive roundtrip", () => {
  const w = new Wincode.Writer();
  w.u8(0xab); w.u16(0xbeef); w.u32(0xdeadbeef); w.u64(0x1122334455667788n); w.bool(true);
  const r = new Wincode.Reader(w.bytes());
  expect(r.u8()).toBe(0xab);
  expect(r.u16()).toBe(0xbeef);
  expect(r.u32()).toBe(0xdeadbeef);
  expect(r.u64()).toBe(0x1122334455667788n);
  expect(r.bool()).toBe(true);
});

test("Reader Vec<u8> recovers the bytes", () => {
  const w = new Wincode.Writer();
  w.vecU8(new Uint8Array([10, 20, 30, 40, 50]));
  const r = new Wincode.Reader(w.bytes());
  expect(Array.from(r.vecU8())).toEqual([10, 20, 30, 40, 50]);
});

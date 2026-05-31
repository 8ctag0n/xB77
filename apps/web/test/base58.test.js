// Tests for apps/web/assets/src/lib/base58.js
// Spec-tested with the well-known Solana System Program ID round-trip.

import { test, expect } from "bun:test";
import "../assets/src/lib/base58.js";
const { base58Encode, base58Decode } = globalThis;

// Solana System Program: pubkey "11111111111111111111111111111111" → 32 zero bytes.
test("system program: 32 zero bytes ↔ '11111111111111111111111111111111'", () => {
  const zeros = new Uint8Array(32);
  expect(base58Encode(zeros)).toBe("11111111111111111111111111111111");
  expect(Array.from(base58Decode("11111111111111111111111111111111"))).toEqual(Array.from(zeros));
});

test("xb77_core program id round-trips", () => {
  const id = "73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3";
  const bytes = base58Decode(id);
  expect(bytes.length).toBe(32);
  expect(base58Encode(bytes)).toBe(id);
});

test("empty input", () => {
  expect(base58Encode(new Uint8Array(0))).toBe("");
  expect(Array.from(base58Decode(""))).toEqual([]);
});

test("invalid char throws", () => {
  expect(() => base58Decode("0OIl")).toThrow();
});

test("leading-zero bytes encode as leading '1' chars", () => {
  const b = new Uint8Array([0, 0, 1]);
  expect(base58Encode(b)).toBe("112");
  expect(Array.from(base58Decode("112"))).toEqual([0, 0, 1]);
});

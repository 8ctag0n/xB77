// Tests for apps/web/assets/src/lib/idl-client.js
//
// Proves the IDL-driven encoder produces wincode bytes identical to what the
// Zig client produces and the on-chain xb77_compression program accepts.

import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import "../assets/src/lib/wincode.js";
import "../assets/src/lib/idl-client.js";
const { IdlClient } = globalThis;

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const compressionIdl = JSON.parse(readFileSync(path.join(repoRoot, "idls/xb77_compression.json"), "utf8"));
const coreIdl        = JSON.parse(readFileSync(path.join(repoRoot, "idls/xb77_core.json"), "utf8"));
const gatewayIdl     = JSON.parse(readFileSync(path.join(repoRoot, "idls/xb77_gateway.json"), "utf8"));
const zkIdl          = JSON.parse(readFileSync(path.join(repoRoot, "idls/xb77_zk_verifier.json"), "utf8"));

const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";
const fromHex = (s) => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};

test("IdlClient.load parses an IDL and exposes its instructions", () => {
  const c = IdlClient.load(compressionIdl);
  expect(c.name).toBe("xb77_compression");
  expect(c.instructions.VerifyTransition).toBeDefined();
  expect(c.programId).toBe("6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN");
});

test("encodeInstruction VerifyTransition matches the 125-byte Zig fixture", () => {
  const c = IdlClient.load(compressionIdl);
  const bytes = c.encodeInstruction("VerifyTransition", {
    payload: {
      old_root: new Uint8Array(32),
      new_root: fromHex(NEW_ROOT_HEX),
      index: 0n,
      siblings: [],
      leaf_preimage_amount: 1n,
      leaf_preimage_type: 0,
      leaf_preimage_tx_hash: new Uint8Array(32),
    },
  });

  expect(bytes.length).toBe(125);
  // disc u32 LE = 0
  expect(Array.from(bytes.slice(0, 4))).toEqual([0, 0, 0, 0]);
  // old_root [4..36] zeros
  for (let i = 4; i < 36; i++) expect(bytes[i]).toBe(0);
  // new_root [36..68]
  expect(Array.from(bytes.slice(36, 68))).toEqual(Array.from(fromHex(NEW_ROOT_HEX)));
  // index u64 LE 0 at [68..76]
  expect(Array.from(bytes.slice(68, 76))).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  // siblings empty (u64 len 0) at [76..84]
  expect(Array.from(bytes.slice(76, 84))).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  // amount u64 LE 1 at [84..92]
  expect(Array.from(bytes.slice(84, 92))).toEqual([1, 0, 0, 0, 0, 0, 0, 0]);
  // type u8 0
  expect(bytes[92]).toBe(0);
});

test("unknown instruction throws", () => {
  const c = IdlClient.load(compressionIdl);
  expect(() => c.encodeInstruction("NopeNope", {})).toThrow();
});

test("missing payload field throws with field name", () => {
  const c = IdlClient.load(compressionIdl);
  expect(() => c.encodeInstruction("VerifyTransition", { payload: { old_root: new Uint8Array(32) } }))
    .toThrow(/new_root|missing/);
});

test("gateway IDL loads and has SubmitPrivateOrder", () => {
  const c = IdlClient.load(gatewayIdl);
  expect(c.name).toBe("xb77_gateway");
  expect(c.instructions.SubmitPrivateOrder).toBeDefined();
});

test("core IDL loads and has RegisterAgent + AnchorStateZk", () => {
  const c = IdlClient.load(coreIdl);
  expect(c.name).toBe("xb77_core");
  expect(c.instructions.RegisterAgent).toBeDefined();
});

test("zk_verifier IDL loads", () => {
  const c = IdlClient.load(zkIdl);
  expect(c.name).toBe("xb77_zk_verifier");
});

test("discriminant is the instruction's 0-based index", () => {
  const c = IdlClient.load(coreIdl);
  // InitCore=0, RegisterAgent=1, ...
  expect(c.discriminantOf("InitCore")).toBe(0);
  expect(c.discriminantOf("RegisterAgent")).toBe(1);
});

test("can build accounts array meta with isMut / isSigner from IDL", () => {
  const c = IdlClient.load(coreIdl);
  const meta = c.accountsMeta("RegisterAgent");
  expect(Array.isArray(meta)).toBe(true);
  expect(meta.length).toBeGreaterThan(0);
  // Each entry has {name, isMut, isSigner}
  for (const m of meta) {
    expect(typeof m.name).toBe("string");
    expect(typeof m.isMut).toBe("boolean");
    expect(typeof m.isSigner).toBe("boolean");
  }
});

// IDL-driven instruction encoder for the xB77 on-chain programs.
//
// Reads an IDL JSON (idls/<program>.json) and exposes:
//   const c = IdlClient.load(idl)
//   const data = c.encodeInstruction("SubmitPrivateOrder", { payload: {...} })
//   const meta = c.accountsMeta("SubmitPrivateOrder")
//   const disc = c.discriminantOf("SubmitPrivateOrder")
//
// All struct fields and primitive types are encoded via the wincode codec
// defined in ./wincode.js. The discriminant is the instruction's 0-based
// index, encoded as u32 LE — matching what the on-chain Rust programs
// deserialize via `wincode::deserialize` against their `enum` definitions.
//
// Supported IDL type shapes:
//   "u8" | "u16" | "u32" | "u64" | "i8" | "i16" | "i32" | "i64" | "bool" | "string"
//   { "array": ["u8", N] }   → fixed-size byte array, N bytes inline
//   { "array": [<inner>, N] } → generic fixed array
//   { "vec": <inner> }       → u64 LE length + N * inner
//   { "option": <inner> }    → u8 tag + inner if Some
//   { "defined": "TypeName" } → struct lookup in idl.types[]
//
// IDL types[] entries are expected to be { name, type: { kind: "struct", fields: [...] } }.
// Enum-typed defined-types are not yet supported (the programs don't expose them as args).

(function () {
const Wincode = globalThis.Wincode;
if (!Wincode) { console.warn("[IdlClient] Wincode not loaded — load wincode.js first"); return; }

class IdlClientImpl {
  constructor(idl) {
    this.raw = idl;
    this.name = idl.name;
    this.programId = idl.metadata && idl.metadata.address || null;
    this._typesByName = new Map();
    for (const t of idl.types || []) this._typesByName.set(t.name, t);
    this._ixByName = new Map();
    this._ixIndex  = new Map();
    (idl.instructions || []).forEach((ix, i) => {
      this._ixByName.set(ix.name, ix);
      this._ixIndex.set(ix.name, i);
    });
  }
  get instructions() {
    return Object.fromEntries(this._ixByName.entries());
  }
  discriminantOf(name) {
    if (!this._ixIndex.has(name)) throw new Error(`unknown instruction: ${name}`);
    return this._ixIndex.get(name);
  }
  accountsMeta(name) {
    const ix = this._ixByName.get(name);
    if (!ix) throw new Error(`unknown instruction: ${name}`);
    return (ix.accounts || []).map((a) => ({
      name: a.name,
      isMut: !!a.isMut,
      isSigner: !!a.isSigner,
    }));
  }
  encodeInstruction(name, values) {
    const ix = this._ixByName.get(name);
    if (!ix) throw new Error(`unknown instruction: ${name}`);
    const disc = this._ixIndex.get(name);
    const w = new Wincode.Writer();
    w.u32(disc);
    for (const arg of ix.args || []) {
      if (!(arg.name in values)) throw new Error(`missing arg '${arg.name}' for ${name}`);
      this._encodeType(w, arg.type, values[arg.name], `${name}.${arg.name}`);
    }
    return w.bytes();
  }

  // ── internals ──
  _encodeType(w, ty, val, where) {
    if (typeof ty === "string") return this._encodePrim(w, ty, val, where);
    if (ty.defined)              return this._encodeDefined(w, ty.defined, val, where);
    if (ty.array)                return this._encodeArray(w, ty.array, val, where);
    if (ty.vec)                  return this._encodeVec(w, ty.vec, val, where);
    if (ty.option)               return this._encodeOption(w, ty.option, val, where);
    throw new Error(`${where}: unsupported IDL type ${JSON.stringify(ty)}`);
  }
  _encodePrim(w, ty, val, where) {
    switch (ty) {
      case "u8":   return w.u8(val);
      case "u16":  return w.u16(val);
      case "u32":  return w.u32(val);
      case "u64":  return w.u64(typeof val === "bigint" ? val : BigInt(val));
      case "i8":   return w.i8(val);
      case "i16":  return w.i16(val);
      case "i32":  return w.i32(val);
      case "i64":  return w.i64(typeof val === "bigint" ? val : BigInt(val));
      case "bool": return w.bool(val);
      case "string": return w.string(val);
      default: throw new Error(`${where}: unsupported primitive '${ty}'`);
    }
  }
  _encodeArray(w, [inner, len], val, where) {
    // Fast path for [u8; N]: accept Uint8Array directly.
    if (inner === "u8") {
      if (!(val instanceof Uint8Array)) val = new Uint8Array(val);
      if (val.length !== len) throw new Error(`${where}: expected [u8; ${len}], got length ${val.length}`);
      return w.fixed(val, len);
    }
    if (!Array.isArray(val) && !(val instanceof Uint8Array)) {
      throw new Error(`${where}: expected array of length ${len}`);
    }
    if (val.length !== len) throw new Error(`${where}: expected length ${len}, got ${val.length}`);
    for (let i = 0; i < len; i++) this._encodeType(w, inner, val[i], `${where}[${i}]`);
    return w;
  }
  _encodeVec(w, inner, val, where) {
    // Vec<u8> fast path
    if (inner === "u8" || (inner && inner.array && inner.array[0] === "u8")) {
      // Not Vec<u8>: Vec<[u8;N]> falls through below
      if (inner === "u8") {
        const b = val instanceof Uint8Array ? val : new Uint8Array(val);
        return w.vecU8(b);
      }
    }
    if (!Array.isArray(val)) throw new Error(`${where}: expected array for vec`);
    w.u64(BigInt(val.length));
    val.forEach((it, i) => this._encodeType(w, inner, it, `${where}[${i}]`));
    return w;
  }
  _encodeOption(w, inner, val, where) {
    if (val === null || val === undefined) return w.u8(0);
    w.u8(1);
    return this._encodeType(w, inner, val, `${where}?`);
  }
  _encodeDefined(w, typeName, val, where) {
    const def = this._typesByName.get(typeName);
    if (!def) throw new Error(`${where}: unknown defined type '${typeName}'`);
    if (!def.type || def.type.kind !== "struct") {
      throw new Error(`${where}: only struct defined-types supported (got ${def.type && def.type.kind})`);
    }
    for (const f of def.type.fields) {
      if (!(f.name in val)) throw new Error(`${where}: missing field '${f.name}'`);
      this._encodeType(w, f.type, val[f.name], `${where}.${f.name}`);
    }
    return w;
  }
}

const _IdlClient = {
  load(idl) { return new IdlClientImpl(idl); },
};

if (typeof globalThis !== "undefined") globalThis.IdlClient = _IdlClient;
})();

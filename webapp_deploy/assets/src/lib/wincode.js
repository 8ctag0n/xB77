// Wincode (Solana-flavored bincode) codec for the browser.
//
// Source of truth: tests/wincode_layout.rs + tests/compression_e2e.zig.
// Matches what the on-chain programs in onchain/programs/* deserialize.
//
// Layout:
//   u8/i8 .. u64/i64 .. f32/f64 → little-endian fixed widths
//   bool                        → u8 (0 / 1)
//   [u8; N]                     → N bytes inline, no prefix
//   Vec<T> / String             → u64 LE length prefix + body
//   Option<T>                   → u8 tag (0 = None, 1 = Some) + body if Some
//   enum variant                → u32 LE discriminant + variant payload
//
// API:
//   const w = new Wincode.Writer()
//   w.u32(0).fixed(myBytes, 32).u64(1n)...
//   const out = w.bytes()
//
//   const r = new Wincode.Reader(out)
//   const a = r.u32(); const b = r.fixed(32); ...
//
//   Wincode.encode(schema, value)   ←  high-level (TBD by idl-client)
//   Wincode.decode(schema, bytes)
//
// Attached to globalThis.Wincode AND exported (ESM) so it works as a
// browser <script> and as a bun-test module.

const _Wincode = (() => {
  class Writer {
    constructor(initial = 256) {
      this._buf = new Uint8Array(initial);
      this._dv  = new DataView(this._buf.buffer);
      this._off = 0;
    }
    _grow(need) {
      if (this._off + need <= this._buf.length) return;
      let size = Math.max(this._buf.length * 2, this._off + need);
      const next = new Uint8Array(size);
      next.set(this._buf);
      this._buf = next;
      this._dv = new DataView(this._buf.buffer);
    }
    bytes() {
      return this._buf.slice(0, this._off);
    }
    // primitives
    u8(v)  { this._grow(1); this._dv.setUint8(this._off, Number(v));        this._off += 1; return this; }
    i8(v)  { this._grow(1); this._dv.setInt8(this._off,  Number(v));        this._off += 1; return this; }
    u16(v) { this._grow(2); this._dv.setUint16(this._off, Number(v), true); this._off += 2; return this; }
    i16(v) { this._grow(2); this._dv.setInt16(this._off,  Number(v), true); this._off += 2; return this; }
    u32(v) { this._grow(4); this._dv.setUint32(this._off, Number(v), true); this._off += 4; return this; }
    i32(v) { this._grow(4); this._dv.setInt32(this._off,  Number(v), true); this._off += 4; return this; }
    u64(v) { this._grow(8); this._dv.setBigUint64(this._off, BigInt(v), true); this._off += 8; return this; }
    i64(v) { this._grow(8); this._dv.setBigInt64(this._off,  BigInt(v), true); this._off += 8; return this; }
    f32(v) { this._grow(4); this._dv.setFloat32(this._off, Number(v), true); this._off += 4; return this; }
    f64(v) { this._grow(8); this._dv.setFloat64(this._off, Number(v), true); this._off += 8; return this; }
    bool(v) { return this.u8(v ? 1 : 0); }

    // composites
    fixed(buf, length) {
      const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
      if (b.length !== length) throw new Error(`wincode: fixed array length mismatch (want ${length}, got ${b.length})`);
      this._grow(length);
      this._buf.set(b, this._off);
      this._off += length;
      return this;
    }
    bytesRaw(buf) {
      const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
      this._grow(b.length);
      this._buf.set(b, this._off);
      this._off += b.length;
      return this;
    }
    vecU8(buf) {
      const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
      this.u64(BigInt(b.length));
      this._grow(b.length);
      this._buf.set(b, this._off);
      this._off += b.length;
      return this;
    }
    vec(items, encodeOne) {
      this.u64(BigInt(items.length));
      for (const it of items) encodeOne(this, it);
      return this;
    }
    string(s) {
      const bytes = new TextEncoder().encode(s);
      return this.vecU8(bytes);
    }
    option(v, encodeSome) {
      if (v === null || v === undefined) return this.u8(0);
      this.u8(1);
      encodeSome(v);
      return this;
    }
    enumTag(disc) {
      // wincode encodes enum variant tags as u32 LE (matches the on-chain
      // CompressionInstruction / GatewayInstruction / etc. deserialization).
      return this.u32(disc);
    }
  }

  class Reader {
    constructor(buf) {
      this._buf = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
      this._dv  = new DataView(this._buf.buffer, this._buf.byteOffset, this._buf.byteLength);
      this._off = 0;
    }
    _adv(n) {
      if (this._off + n > this._buf.length) throw new Error(`wincode: read past end (need ${n}, have ${this._buf.length - this._off})`);
      const at = this._off;
      this._off += n;
      return at;
    }
    remaining()  { return this._buf.length - this._off; }
    eof()        { return this._off >= this._buf.length; }

    u8()  { return this._dv.getUint8(this._adv(1)); }
    i8()  { return this._dv.getInt8(this._adv(1)); }
    u16() { return this._dv.getUint16(this._adv(2), true); }
    i16() { return this._dv.getInt16(this._adv(2), true); }
    u32() { return this._dv.getUint32(this._adv(4), true); }
    i32() { return this._dv.getInt32(this._adv(4), true); }
    u64() { return this._dv.getBigUint64(this._adv(8), true); }
    i64() { return this._dv.getBigInt64(this._adv(8), true); }
    f32() { return this._dv.getFloat32(this._adv(4), true); }
    f64() { return this._dv.getFloat64(this._adv(8), true); }
    bool(){ return this.u8() === 1; }

    fixed(length) {
      return this._buf.slice(this._adv(length), this._off);
    }
    vecU8() {
      const n = Number(this.u64());
      return this._buf.slice(this._adv(n), this._off);
    }
    vec(decodeOne) {
      const n = Number(this.u64());
      const out = new Array(n);
      for (let i = 0; i < n; i++) out[i] = decodeOne(this);
      return out;
    }
    string() {
      return new TextDecoder().decode(this.vecU8());
    }
    option(decodeSome) {
      return this.u8() === 1 ? decodeSome(this) : null;
    }
    enumTag() {
      return this.u32();
    }
  }

  // High-level codec: schema-driven encode/decode. The idl-client will fill
  // these in with per-program schemas; for now keep them as thin trampolines.
  function encode(schema, value) {
    if (typeof schema === "function") {
      const w = new Writer();
      schema(w, value);
      return w.bytes();
    }
    throw new Error("wincode.encode: pass an encoder function (w, v) for now");
  }
  function decode(schema, bytes) {
    if (typeof schema === "function") {
      const r = new Reader(bytes);
      return schema(r);
    }
    throw new Error("wincode.decode: pass a decoder function (r) for now");
  }

  return { Writer, Reader, encode, decode };
})();

if (typeof globalThis !== "undefined") globalThis.Wincode = _Wincode;

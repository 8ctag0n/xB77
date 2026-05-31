// Solana legacy transaction builder (browser-only, no @solana/web3.js dep).
//
// Wire format (legacy, message v0):
//   tx       = signatures || message
//   signatures = compact-u16 N || N × 64-byte Ed25519 sigs (msg-order)
//   message  = header(3) || accountKeys || recentBlockhash(32) || instructions
//     header = numRequiredSigs(u8) || numReadonlySigned(u8) || numReadonlyUnsigned(u8)
//     accountKeys  = compact-u16 N || N × 32-byte pubkeys
//     instructions = compact-u16 N || N × { programIdIndex(u8) || accounts(compact+N×u8) || data(compact+N×u8) }
//
// Compact-u16 (also called short-vec): 1–3 bytes, 7 bits per byte, MSB
// continuation. Used both for top-level counts and per-instruction lens.
//
// AccountKeys ordering rules (canonical):
//   1) Writable signers
//   2) Read-only signers
//   3) Writable non-signers
//   4) Read-only non-signers (program IDs always end up here)
// Payer is forced to index 0 (first writable signer).
(function () {
  function encodeCompactU16(n) {
    if (n < 0 || n > 0xffff) throw new Error("compact-u16: out of range " + n);
    const out = [];
    let rem = n;
    for (let i = 0; i < 3; i++) {
      const lo = rem & 0x7f;
      rem >>= 7;
      if (rem === 0) { out.push(lo); break; }
      out.push(lo | 0x80);
    }
    return new Uint8Array(out);
  }

  function decodeCompactU16(buf, off) {
    let n = 0, shift = 0, consumed = 0;
    for (let i = 0; i < 3; i++) {
      const b = buf[off + i];
      consumed++;
      n |= (b & 0x7f) << shift;
      if ((b & 0x80) === 0) break;
      shift += 7;
    }
    return { value: n, consumed };
  }

  function eq32(a, b) {
    if (a.length !== 32 || b.length !== 32) return false;
    for (let i = 0; i < 32; i++) if (a[i] !== b[i]) return false;
    return true;
  }
  function findKey(keys, pk) {
    for (let i = 0; i < keys.length; i++) if (eq32(keys[i], pk)) return i;
    return -1;
  }

  function classifyAccounts(payer, instructions) {
    // Track each unique pubkey with the strongest (signer, writable) it appears as.
    const meta = new Map(); // key = hex(pubkey) → { pk, isSigner, isWritable, isProgram }
    const hexOf = (pk) => Array.from(pk, (b) => b.toString(16).padStart(2, "0")).join("");

    // Payer is always signer + writable + first.
    meta.set(hexOf(payer), { pk: payer, isSigner: true, isWritable: true, isProgram: false });

    for (const ix of instructions) {
      // Program ID: read-only non-signer.
      const pk = ix.programId;
      const k = hexOf(pk);
      if (!meta.has(k)) meta.set(k, { pk, isSigner: false, isWritable: false, isProgram: true });
      // Note: a program could theoretically be referenced as an instruction account too,
      // but we keep its isProgram flag (it sorts to read-only-non-signer regardless).

      for (const a of ix.accounts) {
        const hk = hexOf(a.pubkey);
        const prior = meta.get(hk);
        if (!prior) {
          meta.set(hk, { pk: a.pubkey, isSigner: !!a.isSigner, isWritable: !!a.isWritable, isProgram: false });
        } else {
          // Upgrade flags if any role demands it.
          prior.isSigner   = prior.isSigner   || !!a.isSigner;
          prior.isWritable = prior.isWritable || !!a.isWritable;
        }
      }
    }

    // Sort: payer first, then by (signer desc, writable desc, isProgram asc).
    const payerHex = hexOf(payer);
    const all = Array.from(meta.values());
    all.sort((a, b) => {
      // payer always wins
      if (hexOf(a.pk) === payerHex) return -1;
      if (hexOf(b.pk) === payerHex) return  1;
      const sa = a.isSigner ? 0 : 1, sb = b.isSigner ? 0 : 1;
      if (sa !== sb) return sa - sb;
      const wa = a.isWritable ? 0 : 1, wb = b.isWritable ? 0 : 1;
      if (wa !== wb) return wa - wb;
      const pa = a.isProgram ? 1 : 0, pb = b.isProgram ? 1 : 0;
      return pa - pb;
    });

    let numRequiredSigs = 0, numReadonlySigned = 0, numReadonlyUnsigned = 0;
    for (const m of all) {
      if (m.isSigner) {
        numRequiredSigs++;
        if (!m.isWritable) numReadonlySigned++;
      } else if (!m.isWritable) {
        numReadonlyUnsigned++;
      }
    }
    return {
      header: { numRequiredSigs, numReadonlySigned, numReadonlyUnsigned },
      keys: all.map((m) => m.pk),
    };
  }

  function concat(parts) {
    let total = 0;
    for (const p of parts) total += p.length;
    const out = new Uint8Array(total);
    let off = 0;
    for (const p of parts) { out.set(p, off); off += p.length; }
    return out;
  }

  class LegacyTx {
    constructor({ header, keys, recentBlockhash, instructions }) {
      this.header = header;
      this.keys = keys;
      this.recentBlockhash = recentBlockhash;
      this.instructions = instructions;
      this._cachedMsg = null;
    }
    serializeMessage() {
      if (this._cachedMsg) return this._cachedMsg;
      const parts = [];
      parts.push(new Uint8Array([this.header.numRequiredSigs, this.header.numReadonlySigned, this.header.numReadonlyUnsigned]));
      parts.push(encodeCompactU16(this.keys.length));
      for (const k of this.keys) parts.push(k);
      parts.push(this.recentBlockhash);
      parts.push(encodeCompactU16(this.instructions.length));
      for (const ix of this.instructions) {
        parts.push(new Uint8Array([ix.programIdIndex]));
        parts.push(encodeCompactU16(ix.accountIndexes.length));
        parts.push(new Uint8Array(ix.accountIndexes));
        parts.push(encodeCompactU16(ix.data.length));
        parts.push(ix.data);
      }
      this._cachedMsg = concat(parts);
      return this._cachedMsg;
    }
    async sign(signers) {
      const msg = this.serializeMessage();
      const numRequired = this.header.numRequiredSigs;
      const sigs = new Array(numRequired).fill(null);
      for (const s of signers) {
        const idx = findKey(this.keys, s.pubkey);
        if (idx < 0)            throw new Error("signer not in accountKeys");
        if (idx >= numRequired) throw new Error("signer at position " + idx + " is not a required signer");
        sigs[idx] = await s.sign(msg);
      }
      for (let i = 0; i < numRequired; i++) {
        if (!sigs[i]) {
          // Pad with zeros — caller can chain another sign() later if needed.
          sigs[i] = new Uint8Array(64);
        }
      }
      const parts = [encodeCompactU16(numRequired)];
      for (const s of sigs) parts.push(s instanceof Uint8Array ? s : new Uint8Array(s));
      parts.push(msg);
      return concat(parts);
    }
  }

  function buildLegacyTx({ payer, recentBlockhash, instructions }) {
    if (!(payer instanceof Uint8Array) || payer.length !== 32) {
      throw new Error("payer must be 32-byte Uint8Array");
    }
    if (!(recentBlockhash instanceof Uint8Array) || recentBlockhash.length !== 32) {
      throw new Error("recentBlockhash must be 32 bytes");
    }
    if (!Array.isArray(instructions) || instructions.length === 0) {
      throw new Error("at least one instruction required");
    }

    const { header, keys } = classifyAccounts(payer, instructions);

    const compiled = instructions.map((ix) => {
      const programIdIndex = findKey(keys, ix.programId);
      if (programIdIndex < 0) throw new Error("programId missing from accountKeys (bug)");
      const accountIndexes = ix.accounts.map((a) => {
        const i = findKey(keys, a.pubkey);
        if (i < 0) throw new Error("instruction account missing from keys (bug)");
        return i;
      });
      return {
        programIdIndex,
        accountIndexes,
        data: ix.data instanceof Uint8Array ? ix.data : new Uint8Array(ix.data),
      };
    });

    return new LegacyTx({ header, keys, recentBlockhash, instructions: compiled });
  }

  const _SolanaTx = {
    buildLegacyTx,
    encodeCompactU16,
    decodeCompactU16,
    classifyAccounts,
    LegacyTx,
  };
  if (typeof globalThis !== "undefined") globalThis.SolanaTx = _SolanaTx;
})();

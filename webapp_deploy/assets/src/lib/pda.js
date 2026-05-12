// PDA (Program Derived Address) helpers — mirrors solana_program::pubkey::Pubkey
// API. The off-curve check is performed with native BigInt arithmetic, so this
// file has no external dependencies.
//
// Exposes (on globalThis):
//   XB77Pda.findProgramAddress(seeds: Uint8Array[], programId: Uint8Array)
//     → Promise<{address: Uint8Array, bump: number}>
//   XB77Pda.createProgramAddress(seeds: Uint8Array[], programId: Uint8Array)
//     → Promise<Uint8Array>   (throws if on-curve)
//
// Algorithm reference: solana-program crate `Pubkey::create_program_address` +
// `Pubkey::find_program_address`.
(function () {
  "use strict";
  const G = globalThis;
  if (!G.crypto || !G.crypto.subtle) {
    console.warn("[XB77Pda] crypto.subtle unavailable — module disabled");
    return;
  }

  const PDA_MARKER = new TextEncoder().encode("ProgramDerivedAddress");
  const MAX_SEED_LEN = 32;
  const MAX_SEEDS = 16;

  // Ed25519 curve constants (mod p = 2^255 - 19).
  const P = (1n << 255n) - 19n;
  // d = -121665 * inverse(121666) mod p   (precomputed from the spec).
  const D = 37095705934669439343138083508754565189542113879843219016388785533085940283555n;

  function mod(a) {
    const r = a % P;
    return r < 0n ? r + P : r;
  }

  // Fermat's little theorem: a^(p-2) ≡ a^(-1) (mod p).
  function powMod(base, exp, m) {
    let r = 1n;
    let b = base % m;
    let e = exp;
    while (e > 0n) {
      if (e & 1n) r = (r * b) % m;
      b = (b * b) % m;
      e >>= 1n;
    }
    return r;
  }

  // Decode 32 little-endian bytes into a BigInt (top bit is the sign of x; we
  // only use y so we mask it out before reducing mod p).
  function bytesToYLE(bytes) {
    let y = 0n;
    for (let i = 31; i >= 0; i--) y = (y << 8n) | BigInt(bytes[i]);
    return y & ((1n << 255n) - 1n);
  }

  // Returns true iff the 32-byte little-endian encoding corresponds to a point
  // on the Ed25519 curve. The check: recover the y coordinate, compute
  // x^2 = (y^2 - 1) * inverse(d*y^2 + 1) mod p, and verify that x^2 is a
  // quadratic residue mod p (Euler's criterion: x^((p-1)/2) ≡ ±1 mod p,
  // and we require ≡ 1 for QR).
  function isOnCurve(bytes) {
    const y = bytesToYLE(bytes);
    if (y >= P) return false; // not a canonical y
    const y2 = mod(y * y);
    const num = mod(y2 - 1n);
    const den = mod(D * y2 + 1n);
    if (den === 0n) return false;
    const denInv = powMod(den, P - 2n, P);
    const x2 = mod(num * denInv);
    // The y=1, x=0 case is the identity — counts as on-curve.
    if (x2 === 0n) return true;
    // Euler: x2 is a QR iff x2^((p-1)/2) ≡ 1.
    const legendre = powMod(x2, (P - 1n) / 2n, P);
    return legendre === 1n;
  }

  async function sha256(parts) {
    let total = 0;
    for (const p of parts) total += p.length;
    const buf = new Uint8Array(total);
    let o = 0;
    for (const p of parts) { buf.set(p, o); o += p.length; }
    const h = await G.crypto.subtle.digest("SHA-256", buf);
    return new Uint8Array(h);
  }

  async function createProgramAddress(seeds, programId) {
    if (seeds.length > MAX_SEEDS) throw new Error("too many seeds");
    for (const s of seeds) {
      if (s.length > MAX_SEED_LEN) throw new Error("seed > 32 bytes");
    }
    const parts = seeds.slice();
    parts.push(programId);
    parts.push(PDA_MARKER);
    const hash = await sha256(parts);
    if (isOnCurve(hash)) {
      const err = new Error("invalid_pda_on_curve");
      err.code = "INVALID_PDA";
      throw err;
    }
    return hash;
  }

  async function findProgramAddress(seeds, programId) {
    for (let bump = 255; bump >= 0; bump--) {
      const seedsWithBump = seeds.slice();
      seedsWithBump.push(new Uint8Array([bump]));
      try {
        const address = await createProgramAddress(seedsWithBump, programId);
        return { address, bump };
      } catch (e) {
        if (e.code === "INVALID_PDA") continue;
        throw e;
      }
    }
    throw new Error("no_valid_pda_found");
  }

  G.XB77Pda = { findProgramAddress, createProgramAddress, isOnCurve };
})();

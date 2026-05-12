// Minimal Base58 codec (Bitcoin / Solana alphabet).
// Pure JS, no deps. Encodes/decodes Uint8Array ↔ string.
// Spec match-tested with Solana program IDs and the system program.
//
// Algorithm: standard big-int division-by-58, with leading-zero preservation.

const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const ALPHABET_MAP = (() => {
  const m = new Int16Array(128).fill(-1);
  for (let i = 0; i < ALPHABET.length; i++) m[ALPHABET.charCodeAt(i)] = i;
  return m;
})();

(function () {
function base58Encode(bytes) {
  if (!(bytes instanceof Uint8Array)) bytes = new Uint8Array(bytes);
  if (bytes.length === 0) return "";

  let zeros = 0;
  while (zeros < bytes.length && bytes[zeros] === 0) zeros++;

  // Allocate enough — bytes.length * log(256)/log(58) ≈ 1.366
  const size = Math.ceil(bytes.length * 138 / 100) + 1;
  const b58 = new Uint8Array(size);

  let length = 0;
  for (let i = zeros; i < bytes.length; i++) {
    let carry = bytes[i];
    let j = 0;
    for (let k = size - 1; (carry !== 0 || j < length) && k >= 0; k--, j++) {
      carry += 256 * b58[k];
      b58[k] = carry % 58;
      carry = Math.floor(carry / 58);
    }
    length = j;
  }

  let it = size - length;
  while (it < size && b58[it] === 0) it++;

  let result = "1".repeat(zeros);
  for (; it < size; it++) result += ALPHABET[b58[it]];
  return result;
}

function base58Decode(str) {
  if (typeof str !== "string") throw new Error("base58Decode: expected string");
  if (str.length === 0) return new Uint8Array(0);

  let zeros = 0;
  while (zeros < str.length && str[zeros] === "1") zeros++;

  const size = Math.ceil(str.length * 733 / 1000) + 1;
  const b256 = new Uint8Array(size);

  let length = 0;
  for (let i = zeros; i < str.length; i++) {
    const c = str.charCodeAt(i);
    let carry = c < 128 ? ALPHABET_MAP[c] : -1;
    if (carry < 0) throw new Error(`base58Decode: invalid char '${str[i]}' at ${i}`);

    let j = 0;
    for (let k = size - 1; (carry !== 0 || j < length) && k >= 0; k--, j++) {
      carry += 58 * b256[k];
      b256[k] = carry & 0xff;
      carry >>= 8;
    }
    length = j;
  }

  let it = size - length;
  const out = new Uint8Array(zeros + (size - it));
  for (let i = 0; i < zeros; i++) out[i] = 0;
  for (let i = zeros; it < size; i++, it++) out[i] = b256[it];
  return out;
}

if (typeof globalThis !== "undefined") {
  globalThis.base58Encode = base58Encode;
  globalThis.base58Decode = base58Decode;
}
})();

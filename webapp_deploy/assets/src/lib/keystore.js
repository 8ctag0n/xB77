// xB77 keystore — Web Crypto Ed25519, AES-GCM at rest.
//
// Public API attached to globalThis.XB77Keystore:
//   generate(password)            → {pubkeyHex, agentId, sealedBlob, sessionReady}
//   import(sealedBlob, password)  → {pubkeyHex, agentId, sealedBlob, sessionReady}
//   loadFromStorage(password)     → same as import, reads localStorage.xb77_keystore
//   signCanonical(bytes)          → Uint8Array(64) Ed25519 signature
//   currentPubkey()               → hex string or null
//   currentAgentId()              → "ag_" + hex(sha256(pubkey)[:9]) or null
//   lock()                        → clears in-memory session key
//
// Sealed blob format (base64-encoded JSON):
//   { v:1, pubkey:<hex>, salt:<hex>, iv:<hex>, ct:<hex> }
//   ct = AES-GCM(PBKDF2(pw, salt, 100k, SHA-256), iv).encrypt(pkcs8_priv)
//
// The session private key is re-imported as non-extractable so it can only
// sign — the raw bytes never leave WebCrypto after unseal.
(function () {
  const SUBTLE = (globalThis.crypto && globalThis.crypto.subtle) || null;
  if (!SUBTLE) {
    console.warn("[XB77Keystore] crypto.subtle unavailable — module disabled");
    return;
  }

  const LS_KEY = "xb77_keystore";
  const PBKDF2_ITERS = 100_000;

  const toHex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
  const fromHex = (s) => {
    const out = new Uint8Array(s.length / 2);
    for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
    return out;
  };
  const b64enc = (s) => {
    if (typeof btoa === "function") return btoa(s);
    return Buffer.from(s, "binary").toString("base64");
  };
  const b64dec = (s) => {
    if (typeof atob === "function") return atob(s);
    return Buffer.from(s, "base64").toString("binary");
  };

  // Session state — cleared by lock().
  let session = null; // { signKey: CryptoKey, pubkeyHex: string, agentId: string }

  async function deriveAesKey(password, salt) {
    const pwBytes = new TextEncoder().encode(password);
    const baseKey = await SUBTLE.importKey("raw", pwBytes, "PBKDF2", false, ["deriveKey"]);
    return SUBTLE.deriveKey(
      { name: "PBKDF2", salt, iterations: PBKDF2_ITERS, hash: "SHA-256" },
      baseKey,
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"],
    );
  }

  async function deriveAgentId(pubkeyBytes) {
    const digest = new Uint8Array(await SUBTLE.digest("SHA-256", pubkeyBytes));
    return "ag_" + toHex(digest.slice(0, 9));
  }

  async function seal(pkcs8, pubkeyHex, password) {
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const aes = await deriveAesKey(password, salt);
    const ct = new Uint8Array(await SUBTLE.encrypt({ name: "AES-GCM", iv }, aes, pkcs8));
    const blob = { v: 1, pubkey: pubkeyHex, salt: toHex(salt), iv: toHex(iv), ct: toHex(ct) };
    return b64enc(JSON.stringify(blob));
  }

  async function unseal(sealedBlob, password) {
    let blob;
    try {
      blob = JSON.parse(b64dec(sealedBlob));
    } catch (e) {
      throw new Error("invalid_blob: malformed sealed blob");
    }
    if (blob.v !== 1) throw new Error("invalid_blob: unsupported version " + blob.v);
    const salt = fromHex(blob.salt);
    const iv = fromHex(blob.iv);
    const ct = fromHex(blob.ct);
    const aes = await deriveAesKey(password, salt);
    let pkcs8;
    try {
      pkcs8 = new Uint8Array(await SUBTLE.decrypt({ name: "AES-GCM", iv }, aes, ct));
    } catch (e) {
      throw new Error("invalid_password: AES-GCM decrypt failed");
    }
    return { pkcs8, pubkeyHex: blob.pubkey };
  }

  async function adoptSession(pkcs8, pubkeyHex) {
    // Re-import private key as non-extractable: it can only sign from here on.
    const signKey = await SUBTLE.importKey("pkcs8", pkcs8, "Ed25519", false, ["sign"]);
    const agentId = await deriveAgentId(fromHex(pubkeyHex));
    session = { signKey, pubkeyHex, agentId };
    return { pubkeyHex, agentId };
  }

  async function generate(password) {
    if (typeof password !== "string" || password.length === 0) {
      throw new Error("password required");
    }
    const kp = await SUBTLE.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
    const pubRaw = new Uint8Array(await SUBTLE.exportKey("raw", kp.publicKey));
    const pkcs8 = new Uint8Array(await SUBTLE.exportKey("pkcs8", kp.privateKey));
    const pubkeyHex = toHex(pubRaw);
    const sealedBlob = await seal(pkcs8, pubkeyHex, password);
    await adoptSession(pkcs8, pubkeyHex);
    return { pubkeyHex, agentId: session.agentId, sealedBlob, sessionReady: true };
  }

  async function importBlob(sealedBlob, password) {
    const { pkcs8, pubkeyHex } = await unseal(sealedBlob, password);
    await adoptSession(pkcs8, pubkeyHex);
    return { pubkeyHex, agentId: session.agentId, sealedBlob, sessionReady: true };
  }

  async function loadFromStorage(password) {
    const blob = (typeof localStorage !== "undefined") ? localStorage.getItem(LS_KEY) : null;
    if (!blob) throw new Error("no_keystore_in_storage");
    return importBlob(blob, password);
  }

  async function signCanonical(bytes) {
    if (!session) throw new Error("locked: no session key — call generate/import first");
    const sig = await SUBTLE.sign("Ed25519", session.signKey, bytes);
    return new Uint8Array(sig);
  }

  function currentPubkey() { return session ? session.pubkeyHex : null; }
  function currentAgentId() { return session ? session.agentId : null; }
  function lock() { session = null; }

  globalThis.XB77Keystore = {
    generate,
    import: importBlob,
    loadFromStorage,
    signCanonical,
    currentPubkey,
    currentAgentId,
    lock,
  };
})();

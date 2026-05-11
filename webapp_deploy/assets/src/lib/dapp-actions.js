// xB77 dApp action layer — wire schema 1.1 (header-bound signatures).
//
// Canonical bytes:  action(1) || ts_be_u64_ms(8) || nonce(12) || payload_bytes
// Signing key:      XB77Keystore.signCanonical(...)
// Headers (POSTs):  X-Xb77-Pubkey, -Timestamp, -Nonce, -Signature (all hex)
//                   register_agent is bootstrap: pubkey header but no signature.
// Body:             raw JSON string the caller passed (no envelope wrapper).
// Server derives agent_id from the verified pubkey; it MUST NOT appear in payloads.
(function () {
  const G = typeof globalThis !== "undefined" ? globalThis : window;
  if (!G.crypto || !G.crypto.subtle) {
    console.warn("[XB77Actions] crypto.subtle unavailable — module disabled");
    return;
  }

  const LS_KEYSTORE = "xb77_keystore";

  const ACTION_BYTES = Object.freeze({
    submit_order:   0x01,
    register_agent: 0x02,
    claim_credits:  0x03,
    query_pulse:    0x04,
  });

  const gateway = () => G.XB77_GATEWAY || "http://127.0.0.1:8787";

  const toHex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

  function canonicalBytes(actionByte, tsMs, nonce, payloadBytes) {
    const out = new Uint8Array(1 + 8 + 12 + payloadBytes.length);
    out[0] = actionByte;
    new DataView(out.buffer).setBigUint64(1, BigInt(tsMs), false); // big-endian
    out.set(nonce, 9);
    out.set(payloadBytes, 21);
    return out;
  }

  async function signEnvelope(action, payloadStr) {
    const actionByte = ACTION_BYTES[action];
    if (actionByte === undefined) throw new Error("unknown action: " + action);
    const KS = G.XB77Keystore;
    if (!KS || !KS.currentPubkey()) throw new Error("keystore locked — generate/import first");

    const tsMs = Date.now();
    const nonce = G.crypto.getRandomValues(new Uint8Array(12));
    const payloadBytes = new TextEncoder().encode(payloadStr);
    const canonical = canonicalBytes(actionByte, tsMs, nonce, payloadBytes);
    const sig = await KS.signCanonical(canonical);

    return {
      headers: {
        "Content-Type": "application/json",
        "X-API-Version": "v1",
        "X-Xb77-Pubkey": KS.currentPubkey(),
        "X-Xb77-Timestamp": String(tsMs),
        "X-Xb77-Nonce": toHex(nonce),
        "X-Xb77-Signature": toHex(sig),
      },
      body: payloadStr,
    };
  }

  // register_agent bootstrap — pubkey in header, no signature required.
  function bootstrapEnvelope(payloadObj) {
    const KS = G.XB77Keystore;
    const pubkeyHex = (payloadObj && payloadObj.pubkey) || (KS && KS.currentPubkey()) || null;
    const body = JSON.stringify({ intent_hint: payloadObj.intent_hint || "merchant", client_version: "webapp@0.1.0" });
    const headers = {
      "Content-Type": "application/json",
      "X-API-Version": "v1",
    };
    if (pubkeyHex) headers["X-Xb77-Pubkey"] = pubkeyHex;
    return { headers, body };
  }

  function maybeUpdateRateLimit(r) {
    if (!G.__xb77RateLimit || !r.headers) return;
    const rl = G.__xb77RateLimit;
    const tier = r.headers.get("X-RateLimit-Tier");
    if (tier) rl.tier = tier;
    const map = { "X-RateLimit-Limit": "limit", "X-RateLimit-Remaining": "remaining", "X-RateLimit-Reset": "reset", "X-RateLimit-Cost": "cost" };
    for (const k in map) { const v = r.headers.get(k); if (v != null) rl[map[k]] = Number(v); }
    rl.lastUpdatedAt = Date.now();
  }

  async function callAction(action, payloadObj, { idempotencyKey } = {}) {
    const env = (action === "register_agent")
      ? bootstrapEnvelope(payloadObj || {})
      : await signEnvelope(action, JSON.stringify(payloadObj || {}));

    const headers = { ...env.headers };
    if (idempotencyKey) headers["X-Idempotency-Key"] = idempotencyKey;

    const r = await fetch(`${gateway()}/api/v1/actions/${action}`, {
      method: "POST", mode: "cors", headers, body: env.body,
    });
    maybeUpdateRateLimit(r);

    if (r.status === 429) {
      const ra = r.headers && r.headers.get("Retry-After");
      const detail = { retryAfterMs: ra ? Number(ra) * 1000 : 5000, at: Date.now() };
      (G.dispatchEvent || (() => {})).call(G, new CustomEvent("xb77:rate-limited", { detail }));
      throw new Error("rate_limited");
    }
    const body = await r.json().catch(() => ({}));
    if (!r.ok || body.ok === false) {
      const err = (body && body.error) || { code: "http_" + r.status, message: r.statusText };
      const e = new Error(err.message || err.code);
      e.code = err.code;
      throw e;
    }
    return body.data || body;
  }

  const Actions = {
    keystore: {
      hasKeystore: () => typeof localStorage !== "undefined" && !!localStorage.getItem(LS_KEYSTORE),
      hasAgent: () => !!(G.XB77Keystore && G.XB77Keystore.currentAgentId()),
      get agentId() { return G.XB77Keystore ? G.XB77Keystore.currentAgentId() : null; },
      get pubkey()  { return G.XB77Keystore ? G.XB77Keystore.currentPubkey()  : null; },
      saveSealedBlob: (blob) => { if (typeof localStorage !== "undefined") localStorage.setItem(LS_KEYSTORE, blob); },
      clear: () => {
        if (typeof localStorage !== "undefined") localStorage.removeItem(LS_KEYSTORE);
        if (G.XB77Keystore) G.XB77Keystore.lock();
      },
    },
    registerAgent: (pubkey, intent_hint) => callAction("register_agent", { pubkey, intent_hint }),
    submitOrder: (payload) => {
      const { idempotency_key, agent_id, ...rest } = payload || {};
      return callAction("submit_order", rest, { idempotencyKey: idempotency_key });
    },
    claimCredits: (proof_tx) => callAction("claim_credits", { proof_tx }, { idempotencyKey: "claim-" + proof_tx }),
    queryPulse:  () => callAction("query_pulse", {}),
  };

  G.XB77Actions = Actions;
  // Exposed for tests; harmless in the browser.
  G.XB77ActionsInternals = { ACTION_BYTES, canonicalBytes, signEnvelope, bootstrapEnvelope };
})();

// xB77 dApp action layer — wraps signed POSTs to the gateway.
// signEnvelope() is a STUB: returns a deterministic placeholder so the
// mock-gateway accepts it. When the SDK is vendored, swap signEnvelope
// (and only signEnvelope) for the real ed25519 implementation.
(function () {
  if (typeof window === "undefined") return;

  const LS_KEYSTORE = "xb77_keystore";
  const LS_AGENT_ID = "xb77_agent_id";
  const LS_PUBKEY = "xb77_pubkey";

  const gateway = () => window.XB77_GATEWAY || "http://127.0.0.1:8787";

  const b64 = (s) => {
    try { return btoa(unescape(encodeURIComponent(s))); } catch { return ""; }
  };

  const newNonce = () => {
    const a = new Uint8Array(12);
    (crypto || window.crypto).getRandomValues(a);
    return Array.from(a, (n) => n.toString(16).padStart(2, "0")).join("");
  };

  // TODO[SDK]: replace stub with sdk.sign(privKey, canonicalBytes(...))
  function signEnvelope(action, payload) {
    const agent_id = localStorage.getItem(LS_AGENT_ID) || "ag_stub_unregistered";
    const env = { agent_id, ts: Date.now(), nonce: newNonce(), action, payload };
    env.signature = "ed25519:stub." + b64(`${agent_id}|${env.ts}|${env.nonce}|${action}`);
    return env;
  }

  async function callAction(action, payload, { idempotencyKey } = {}) {
    const envelope = action === "register_agent"
      ? { pubkey: payload.pubkey, intent_hint: payload.intent_hint || "merchant", client_version: "webapp@0.1.0-stub" }
      : signEnvelope(action, payload);
    const headers = { "Content-Type": "application/json", "X-API-Version": "v1" };
    if (idempotencyKey) headers["X-Idempotency-Key"] = idempotencyKey;
    const r = await fetch(`${gateway()}/api/v1/actions/${action}`, {
      method: "POST", mode: "cors", headers, body: JSON.stringify(envelope),
    });
    // Capture rate-limit headers via the same hook DataSource uses, if present.
    if (window.__xb77RateLimit && r.headers) {
      const rl = window.__xb77RateLimit;
      const tier = r.headers.get("X-RateLimit-Tier");
      if (tier) rl.tier = tier;
      const num = { "X-RateLimit-Limit": "limit", "X-RateLimit-Remaining": "remaining", "X-RateLimit-Reset": "reset", "X-RateLimit-Cost": "cost" };
      for (const k in num) { const v = r.headers.get(k); if (v != null) rl[num[k]] = Number(v); }
      rl.lastUpdatedAt = Date.now();
    }
    if (r.status === 429) {
      const ra = r.headers && r.headers.get("Retry-After");
      const detail = { retryAfterMs: ra ? Number(ra) * 1000 : 5000, at: Date.now() };
      window.dispatchEvent(new CustomEvent("xb77:rate-limited", { detail }));
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
      hasKeystore: () => !!localStorage.getItem(LS_KEYSTORE),
      hasAgent: () => !!localStorage.getItem(LS_AGENT_ID),
      get agentId() { return localStorage.getItem(LS_AGENT_ID); },
      get pubkey() { return localStorage.getItem(LS_PUBKEY); },
      saveSealedBlob: (blob) => localStorage.setItem(LS_KEYSTORE, blob),
      saveAgent: ({ agent_id, pubkey }) => {
        if (agent_id) localStorage.setItem(LS_AGENT_ID, agent_id);
        if (pubkey) localStorage.setItem(LS_PUBKEY, pubkey);
      },
      clear: () => [LS_KEYSTORE, LS_AGENT_ID, LS_PUBKEY].forEach((k) => localStorage.removeItem(k)),
    },
    registerAgent: (pubkey, intent_hint) => callAction("register_agent", { pubkey, intent_hint }),
    submitOrder: (payload) => callAction("submit_order", payload, { idempotencyKey: payload.idempotency_key }),
    claimCredits: (proof_tx) => callAction("claim_credits", { proof_tx }, { idempotencyKey: "claim-" + proof_tx }),
    queryPulse: () => callAction("query_pulse", {}),
  };

  window.XB77Actions = Actions;
})();

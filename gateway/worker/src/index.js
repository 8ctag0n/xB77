// xB77 Gateway — CF Worker implementation of docs/api-contract-v1.md.
//
// Wire schema 1.1 (default): header-signed requests with binary canonical
//   action(1) || ts_be_ms(8) || nonce(12) || payload
// Headers: X-API-Version, X-Xb77-{Pubkey,Timestamp,Nonce,Signature}
//
// Responses signed with X-Xb77-Gateway-{Timestamp,Signature} headers over
//   action(1) || response_ts_be_ms(8) || response_body
//
// KV namespaces: AGENTS, ORDERS, NONCES, BUCKETS, IDEMP (5min nonce TTL,
// 24h idempotency TTL, per-bucket TTL derived from tier refill rate).

// ────────────────────────── constants & tables ──────────────────────────

const ACTION_BYTE = {
  submit_order: 0x01,
  register_agent: 0x02,
  claim_credits: 0x03,
  query_pulse: 0x04,
  register_webhook: 0x10,
  delete_webhook: 0x11,
};

const TIER_POLICY = {
  unauth: { per_minute: 10, burst: 3 },
  free: { per_minute: 30, burst: 10 },
  paid: { per_minute: 300, burst: 60 },
  privileged: { per_minute: 3000, burst: 600 },
};

const ACTION_COST = {
  submit_order: 3,
  query_pulse: 1,
  claim_credits: 1,
  register_agent: 1,
};

const TS_SKEW_MS = 30_000;
const NONCE_TTL_S = 300;
const IDEMP_TTL_S = 86_400;
const RPC_TIMEOUT_MS = 1_500;

const EXPOSED_HEADERS = [
  "X-Xb77-Gateway-Timestamp",
  "X-Xb77-Gateway-Signature",
  "X-RateLimit-Tier",
  "X-RateLimit-Limit",
  "X-RateLimit-Remaining",
  "X-RateLimit-Reset",
  "X-RateLimit-Cost",
  "Retry-After",
].join(", ");

const ALLOWED_HEADERS = [
  "Content-Type",
  "X-API-Version",
  "X-Xb77-Pubkey",
  "X-Xb77-Timestamp",
  "X-Xb77-Nonce",
  "X-Xb77-Signature",
  "X-Idempotency-Key",
].join(", ");

// ────────────────────────── hex / bytes helpers ──────────────────────────

function fromHex(s) {
  if (!s || s.length % 2 !== 0) return null;
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) {
    const b = parseInt(s.slice(i * 2, i * 2 + 2), 16);
    if (Number.isNaN(b)) return null;
    out[i] = b;
  }
  return out;
}

function toHex(b) {
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

function concat(...parts) {
  const total = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    out.set(p, off);
    off += p.length;
  }
  return out;
}

function u64beBytes(n) {
  const out = new Uint8Array(8);
  let bn = BigInt(n);
  for (let i = 7; i >= 0; i--) {
    out[i] = Number(bn & 0xffn);
    bn >>= 8n;
  }
  return out;
}

// ────────────────────────── crypto: Ed25519 via WebCrypto ──────────────────────────

const PKCS8_ED25519_PREFIX = new Uint8Array([
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
  0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
]);

async function importGatewayPriv(privHex) {
  const bytes = fromHex(privHex);
  if (!bytes || bytes.length !== 64) {
    throw new Error("GATEWAY_PRIVKEY_HEX must be 128 hex chars (64 bytes: seed||pubkey)");
  }
  const seed = bytes.slice(0, 32);
  const pubkey = bytes.slice(32, 64);
  const pkcs8 = concat(PKCS8_ED25519_PREFIX, seed);
  const key = await crypto.subtle.importKey("pkcs8", pkcs8, "Ed25519", false, ["sign"]);
  return { signKey: key, pubkey };
}

async function importClientPub(pubkeyBytes) {
  return crypto.subtle.importKey("raw", pubkeyBytes, "Ed25519", false, ["verify"]);
}

async function sha256(bytes) {
  const buf = await crypto.subtle.digest("SHA-256", bytes);
  return new Uint8Array(buf);
}

async function deriveAgentId(pubkeyBytes) {
  const h = await sha256(pubkeyBytes);
  return "ag_" + toHex(h.slice(0, 9));
}

// ────────────────────────── canonical bytes ──────────────────────────

function canonicalRequest11(actionByte, tsMs, nonce, payload) {
  return concat(new Uint8Array([actionByte]), u64beBytes(tsMs), nonce, payload);
}

function canonicalRequest10(actionByte, tsSec, payload) {
  return concat(new Uint8Array([actionByte]), u64beBytes(tsSec), payload);
}

function canonicalResponse(actionByte, tsMs, body) {
  return concat(new Uint8Array([actionByte]), u64beBytes(tsMs), body);
}

// ────────────────────────── response helpers ──────────────────────────

function corsHeaders(env) {
  return {
    "access-control-allow-origin": env.ALLOWED_ORIGIN || "*",
    "access-control-allow-headers": ALLOWED_HEADERS,
    "access-control-expose-headers": EXPOSED_HEADERS,
    "access-control-max-age": "86400",
  };
}

function jsonResponse(body, { status = 200, env, extraHeaders = {} } = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders(env), ...extraHeaders },
  });
}

async function signedResponse(actionByte, data, { status = 200, env, gatewayKeys, extraHeaders = {} }) {
  const ok = status >= 200 && status < 300;
  const bodyObj = ok ? { ok: true, data } : { ok: false, error: data };
  const bodyBytes = new TextEncoder().encode(JSON.stringify(bodyObj));
  const respTs = Date.now();
  const canonical = canonicalResponse(actionByte, respTs, bodyBytes);
  const sigBuf = await crypto.subtle.sign("Ed25519", gatewayKeys.signKey, canonical);
  const sigHex = toHex(new Uint8Array(sigBuf));
  return new Response(bodyBytes, {
    status,
    headers: {
      "content-type": "application/json",
      "x-xb77-gateway-timestamp": String(respTs),
      "x-xb77-gateway-signature": sigHex,
      ...corsHeaders(env),
      ...extraHeaders,
    },
  });
}

function errorObj(code, message, retryAfterMs = null) {
  const o = { code, message };
  if (retryAfterMs !== null) o.retry_after_ms = retryAfterMs;
  return o;
}

// ────────────────────────── auth middleware ──────────────────────────

async function verifySigned(req, expectedAction, env) {
  const apiVer = req.headers.get("X-API-Version");
  if (apiVer !== "v1") {
    return { error: { code: "invalid_version", http: 400, message: "X-API-Version: v1 required" } };
  }

  const pkHex = req.headers.get("X-Xb77-Pubkey");
  const sigHex = req.headers.get("X-Xb77-Signature");
  const tsStr = req.headers.get("X-Xb77-Timestamp");
  const nonceHex = req.headers.get("X-Xb77-Nonce");

  if (!pkHex || !sigHex || !tsStr) {
    return { error: { code: "invalid_signature", http: 401, message: "missing auth headers" } };
  }

  const pubkey = fromHex(pkHex);
  const sig = fromHex(sigHex);
  if (!pubkey || pubkey.length !== 32 || !sig || sig.length !== 64) {
    return { error: { code: "invalid_signature", http: 401, message: "malformed pubkey or signature" } };
  }

  const tsNum = Number(tsStr);
  if (!Number.isFinite(tsNum)) {
    return { error: { code: "clock_skew", http: 401, message: "bad timestamp" } };
  }

  const payload = new Uint8Array(await req.arrayBuffer());
  const actionByte = ACTION_BYTE[expectedAction];

  let canonical, schema, nonce;
  if (nonceHex) {
    nonce = fromHex(nonceHex);
    if (!nonce || nonce.length !== 12) {
      return { error: { code: "invalid_nonce", http: 401, message: "nonce must be 12B hex" } };
    }
    if (Math.abs(Date.now() - tsNum) > TS_SKEW_MS) {
      return { error: { code: "clock_skew", http: 401, message: `ts outside ±${TS_SKEW_MS}ms window` } };
    }
    canonical = canonicalRequest11(actionByte, tsNum, nonce, payload);
    schema = "1.1";
  } else {
    if (env.ACCEPT_SCHEMA_1_0 !== "true") {
      return { error: { code: "invalid_signature", http: 401, message: "X-Xb77-Nonce required (schema 1.1)" } };
    }
    if (Math.abs(Date.now() / 1000 - tsNum) > 30) {
      return { error: { code: "clock_skew", http: 401, message: "ts outside ±30s window (schema 1.0)" } };
    }
    canonical = canonicalRequest10(actionByte, tsNum, payload);
    schema = "1.0";
  }

  let verifyKey;
  try { verifyKey = await importClientPub(pubkey); }
  catch { return { error: { code: "invalid_signature", http: 401, message: "bad pubkey" } }; }
  
  const ok = await crypto.subtle.verify("Ed25519", verifyKey, sig, canonical);
  if (!ok) return { error: { code: "invalid_signature", http: 401, message: "signature did not verify" } };

  const agent_id = await deriveAgentId(pubkey);

  if (schema === "1.1") {
    const nonceKey = `${agent_id}:${toHex(nonce)}`;
    const seen = await env.NONCES.get(nonceKey);
    if (seen) return { error: { code: "invalid_nonce", http: 401, message: "nonce reused" } };
    await env.NONCES.put(nonceKey, "1", { expirationTtl: NONCE_TTL_S });
  }

  return { agent_id, pubkey, pubkeyHex: pkHex, payload, schema };
}

// ────────────────────────── rate limit (token bucket) ──────────────────────────

async function checkRateLimit(env, bucketKey, tier, cost) {
  const policy = TIER_POLICY[tier];
  const now = Date.now();
  const refillPerMs = policy.per_minute / 60_000;

  const raw = await env.BUCKETS.get(bucketKey);
  let tokens, lastTs;
  if (raw) {
    try {
      const o = JSON.parse(raw);
      tokens = o.tokens;
      lastTs = o.ts;
    } catch {
      tokens = policy.burst;
      lastTs = now;
    }
  } else {
    tokens = policy.burst;
    lastTs = now;
  }

  const elapsed = Math.max(0, now - lastTs);
  tokens = Math.min(policy.burst, tokens + elapsed * refillPerMs);

  const headers = {
    "x-ratelimit-tier": tier,
    "x-ratelimit-limit": String(policy.per_minute),
    "x-ratelimit-cost": String(cost),
  };

  if (tokens < cost) {
    const deficit = cost - tokens;
    const retryMs = Math.ceil(deficit / refillPerMs);
    headers["x-ratelimit-remaining"] = "0";
    headers["x-ratelimit-reset"] = String(Math.ceil((now + retryMs) / 1000));
    headers["retry-after"] = String(Math.ceil(retryMs / 1000));
    return { ok: false, retryAfterMs: retryMs, headers };
  }

  tokens -= cost;
  headers["x-ratelimit-remaining"] = String(Math.floor(tokens));
  headers["x-ratelimit-reset"] = String(Math.ceil((now + (policy.burst - tokens) / refillPerMs) / 1000));

  const ttl = Math.ceil((policy.burst / refillPerMs / 1000) * 2);
  await env.BUCKETS.put(bucketKey, JSON.stringify({ tokens, ts: now }), { expirationTtl: Math.max(60, ttl) });

  return { ok: true, headers };
}

// ────────────────────────── idempotency cache ──────────────────────────

async function checkIdempotency(env, key, agent_id) {
  if (!key) return null;
  const fullKey = `idemp:${agent_id}:${key}`;
  const cached = await env.IDEMP.get(fullKey);
  if (cached) {
    try { return JSON.parse(cached); } catch { return null; }
  }
  return null;
}

async function storeIdempotency(env, key, agent_id, data) {
  if (!key) return;
  const fullKey = `idemp:${agent_id}:${key}`;
  await env.IDEMP.put(fullKey, JSON.stringify(data), { expirationTtl: IDEMP_TTL_S });
}

// ────────────────────────── solana RPC helper ──────────────────────────

async function rpc(url, method, params = []) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), RPC_TIMEOUT_MS);
  try {
    const r = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
      signal: ctl.signal,
    });
    if (!r.ok) return null;
    const j = await r.json();
    return j.result ?? null;
  } catch { return null; } finally { clearTimeout(t); }
}

// ────────────────────────── data helpers ──────────────────────────

async function getAgent(env, agent_id) {
  const raw = await env.AGENTS.get(agent_id);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

async function putAgent(env, agent) {
  await env.AGENTS.put(agent.agent_id, JSON.stringify(agent));
}

// ────────────────────────── Handlers ──────────────────────────

async function handleWebhookRegister(req, env, tenant_id, gatewayKeys, ctx) {
  const auth = await verifySigned(req, "register_webhook", env);
  if (auth.error) {
    return signedResponse(ACTION_BYTE.register_webhook, errorObj(auth.error.code, auth.error.message), { status: auth.error.http, env, gatewayKeys });
  }
  if (auth.agent_id !== tenant_id) {
    return signedResponse(ACTION_BYTE.register_webhook, errorObj("unauthorized", "tenant_id mismatch"), { status: 403, env, gatewayKeys });
  }

  let body;
  try { body = JSON.parse(new TextDecoder().decode(auth.payload)); }
  catch { return signedResponse(ACTION_BYTE.register_webhook, errorObj("invalid_payload", "body must be JSON"), { status: 400, env, gatewayKeys }); }

  const { url, secret, aliases } = body;
  if (!url || !secret) {
    return signedResponse(ACTION_BYTE.register_webhook, errorObj("invalid_payload", "url and secret required"), { status: 400, env, gatewayKeys });
  }

  const id = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO webhooks (id, tenant_id, url, secret, event_aliases, created_at) VALUES (?, ?, ?, ?, ?, ?)"
  ).bind(id, tenant_id, url, secret, JSON.stringify(aliases || {}), Date.now()).run();

  return signedResponse(ACTION_BYTE.register_webhook, { id, url, status: "active" }, { status: 201, env, gatewayKeys });
}

async function handleWebhookList(env, tenant_id) {
  const { results } = await env.DB.prepare("SELECT id, url, event_aliases, status FROM webhooks WHERE tenant_id = ?")
    .bind(tenant_id).all();
  
  return jsonResponse({ webhooks: results }, { env });
}

async function handleWebhookDelete(req, env, tenant_id, webhook_id, gatewayKeys, ctx) {
  const auth = await verifySigned(req, "delete_webhook", env);
  if (auth.error) {
    return signedResponse(ACTION_BYTE.delete_webhook, errorObj(auth.error.code, auth.error.message), { status: auth.error.http, env, gatewayKeys });
  }
  if (auth.agent_id !== tenant_id) {
    return signedResponse(ACTION_BYTE.delete_webhook, errorObj("unauthorized", "tenant_id mismatch"), { status: 403, env, gatewayKeys });
  }

  await env.DB.prepare("DELETE FROM webhooks WHERE id = ? AND tenant_id = ?").bind(webhook_id, tenant_id).run();
  return signedResponse(ACTION_BYTE.delete_webhook, { ok: true }, { env, gatewayKeys });
}

async function dispatchWebhook(env, tenant_id, event_type, payload) {
  const { results: hooks } = await env.DB.prepare("SELECT id, url, secret, event_aliases FROM webhooks WHERE tenant_id = ? AND status = 'active'")
    .bind(tenant_id).all();

  for (const hook of hooks) {
    const aliases = JSON.parse(hook.event_aliases || "{}");
    const final_type = aliases[event_type] || event_type;
    
    const delivery_id = crypto.randomUUID();
    const final_payload = JSON.stringify({
      id: delivery_id,
      type: final_type,
      tenant_id,
      timestamp: Date.now(),
      data: payload
    });

    await env.DB.prepare(
      "INSERT INTO webhook_deliveries (id, webhook_id, event_type, payload, next_attempt_at) VALUES (?, ?, ?, ?, ?)"
    ).bind(delivery_id, hook.id, final_type, final_payload, Date.now()).run();
  }
}

async function processWebhookQueue(env) {
  const now = Date.now();
  const { results: pending } = await env.DB.prepare(
    "SELECT * FROM webhook_deliveries WHERE next_attempt_at <= ? AND attempts < 5"
  ).bind(now).all();

  for (const delivery of pending) {
    const { results: hookArr } = await env.DB.prepare("SELECT url, secret FROM webhooks WHERE id = ?")
      .bind(delivery.webhook_id).all();
    
    if (hookArr.length === 0) continue;
    const hook = hookArr[0];

    try {
      const resp = await fetch(hook.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-xB77-Webhook-Secret": hook.secret,
          "User-Agent": "xB77-Webhook-Dispatcher/1.1"
        },
        body: delivery.payload,
      });

      if (resp.ok) {
        await env.DB.prepare("DELETE FROM webhook_deliveries WHERE id = ?").bind(delivery.id).run();
      } else {
        throw new Error(`HTTP ${resp.status}`);
      }
    } catch (err) {
      const nextAttempt = delivery.attempts + 1;
      const delay = 30 * Math.pow(2, nextAttempt) * 1000;
      await env.DB.prepare(
        "UPDATE webhook_deliveries SET attempts = ?, next_attempt_at = ?, last_status = ?, last_error = ? WHERE id = ?"
      ).bind(nextAttempt, now + delay, 0, err.message, delivery.id).run();
    }
  }
}

// ────────────────────────── Router ──────────────────────────

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const method = request.method;
    const path = url.pathname;

    // Discovery / Meta
    if ((path === "/" || path === "/_meta") && method === "GET") {
      return jsonResponse({
        name: "xb77-gateway",
        version: "v1",
        schema: "1.1",
        endpoints: {
          actions: ["register_agent", "submit_order", "claim_credits", "query_pulse"],
          tenants: ["POST /api/v1/tenants/:id/webhooks", "GET /api/v1/tenants/:id/webhooks", "DELETE /api/v1/tenants/:id/webhooks/:hook_id"],
        },
      }, { env });
    }

    // Router Logic
    let gatewayKeys;
    try {
      gatewayKeys = await importGatewayPriv(env.GATEWAY_PRIVKEY_HEX || env.GATEWAY_PRIVKEY_HEX_DEV);
    } catch (e) {
      return jsonResponse({ error: "internal", message: "gateway key misconfigured" }, { status: 500, env });
    }

    // Routing by method + path
    if (method === "POST") {
      switch (path) {
        case "/api/v1/actions/register_agent": return handleRegisterAgent(request, env, gatewayKeys);
        case "/api/v1/actions/submit_order":   return handleSubmitOrder(request, env, gatewayKeys);
        case "/api/v1/actions/claim_credits":  return handleClaimCredits(request, env, gatewayKeys, ctx);
        case "/api/v1/actions/query_pulse":    return handleQueryPulse(request, env, gatewayKeys);
        case "/api/v1/pipelines/ingest":       return handlePipelinesIngest(request, env);
        default:
          if (path.startsWith("/api/v1/tenants/") && path.endsWith("/webhooks")) {
            return handleWebhookRegister(request, env, path.split("/")[4], gatewayKeys, ctx);
          }
      }
    } else if (method === "GET") {
      switch (path) {
        case "/api/v1/network/pulse": return handleNetworkPulse(env);
        case "/api/v1/network/audit": return handleNetworkAudit(env, url);
        case "/api/v1/agents/fleet":  return handleAgentsFleet(env, url);
        case "/api/v1/sns/reverse":   return handleSnsReverse(env, url);
        default:
          if (path.startsWith("/api/v1/agents/")) return handleAgentDetail(env, path.slice(15));
          if (path.startsWith("/api/v1/tenants/") && path.endsWith("/webhooks")) {
            return handleWebhookList(env, path.split("/")[4]);
          }
      }
    } else if (method === "DELETE") {
      if (path.startsWith("/api/v1/tenants/") && path.includes("/webhooks/")) {
        const p = path.split("/");
        return handleWebhookDelete(request, env, p[4], p[6], gatewayKeys, ctx);
      }
    }

    return jsonResponse({ error: "not found" }, { status: 404, env });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(processWebhookQueue(env));
  },
};

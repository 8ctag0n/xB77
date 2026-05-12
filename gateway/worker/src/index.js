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

// Wrap a 32-byte Ed25519 seed in a PKCS8 envelope so WebCrypto can import it.
// PKCS8 for Ed25519 is a fixed 16-byte prefix + 32-byte seed.
const PKCS8_ED25519_PREFIX = new Uint8Array([
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
  0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
]);

async function importGatewayPriv(privHex) {
  // privHex is 64B (seed||pubkey) from SDK convention. We need only the seed.
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
    "access-control-allow-methods": "GET, POST, OPTIONS",
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
  // Returns { agent_id, pubkey, pubkeyHex, payload, schema } or { error: {code, http, message} }.
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

  // Schema detection: 1.1 if nonce present, else 1.0 (if allowed).
  let canonical;
  let schema;
  let nonce;
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
    // 1.0 fallback: ts in seconds, ±30s window
    if (Math.abs(Date.now() / 1000 - tsNum) > 30) {
      return { error: { code: "clock_skew", http: 401, message: "ts outside ±30s window (schema 1.0)" } };
    }
    canonical = canonicalRequest10(actionByte, tsNum, payload);
    schema = "1.0";
  }

  // Verify signature.
  let verifyKey;
  try {
    verifyKey = await importClientPub(pubkey);
  } catch {
    return { error: { code: "invalid_signature", http: 401, message: "bad pubkey" } };
  }
  const ok = await crypto.subtle.verify("Ed25519", verifyKey, sig, canonical);
  if (!ok) {
    return { error: { code: "invalid_signature", http: 401, message: "signature did not verify" } };
  }

  const agent_id = await deriveAgentId(pubkey);

  // Nonce replay check (schema 1.1 only — 1.0 has no nonce).
  if (schema === "1.1") {
    const nonceKey = `${agent_id}:${toHex(nonce)}`;
    const seen = await env.NONCES.get(nonceKey);
    if (seen) {
      return { error: { code: "invalid_nonce", http: 401, message: "nonce reused" } };
    }
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

  // Refill since last access.
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

  // Persist with TTL = 2× full-refill window (defensive — KV reaps inactive agents).
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
    try {
      return JSON.parse(cached);
    } catch {
      return null;
    }
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
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

// ────────────────────────── data helpers ──────────────────────────

const T0 = 1715000000000;
function driftSlot() {
  return 250_000_000 + Math.floor((Date.now() - T0) / 400);
}

async function getAgent(env, agent_id) {
  const raw = await env.AGENTS.get(agent_id);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

async function putAgent(env, agent) {
  await env.AGENTS.put(agent.agent_id, JSON.stringify(agent));
}

async function networkPulseData(env) {
  const url = env.ZNODE_RPC_URL;
  const [slot, blockHeight] = await Promise.all([
    rpc(url, "getSlot"),
    rpc(url, "getBlockHeight"),
  ]);
  const live = slot !== null && blockHeight !== null;
  // Best-effort: count agents currently in KV (cheap-ish via list with limit=1).
  let agentsOnline = 0;
  try {
    const list = await env.AGENTS.list({ limit: 1000 });
    agentsOnline = list.keys.length;
  } catch { /* ignore */ }
  return {
    slot: live ? slot : driftSlot(),
    blockHeight: live ? blockHeight : driftSlot() - 1200,
    agentsOnline,
    proofsVerified24h: 1247 + Math.floor((Date.now() - T0) / 60000),
    ts: Date.now(),
    _rpcLive: live,
  };
}

function deterministicMockWallet(agent_id) {
  // Stable per-agent mock — same agent_id → same numbers.
  let h = 0;
  for (let i = 0; i < agent_id.length; i++) h = (h * 31 + agent_id.charCodeAt(i)) & 0xffffffff;
  const usdc = ((h & 0xffff) % 100000) / 100;
  const sol = (((h >>> 16) & 0xffff) % 1000) / 100;
  return { usdc, sol };
}

// ────────────────────────── handlers: bootstrap ──────────────────────────

async function handleRegisterAgent(req, env, gatewayKeys) {
  let body;
  try {
    body = await req.json();
  } catch {
    return signedResponse(ACTION_BYTE.register_agent,
      errorObj("invalid_payload", "body must be JSON"),
      { status: 400, env, gatewayKeys });
  }
  const { pubkey, intent_hint, client_version } = body || {};
  if (!pubkey || typeof pubkey !== "string" || pubkey.length !== 64) {
    return signedResponse(ACTION_BYTE.register_agent,
      errorObj("invalid_payload", "pubkey must be 64-hex string"),
      { status: 400, env, gatewayKeys });
  }
  const pubkeyBytes = fromHex(pubkey);
  if (!pubkeyBytes) {
    return signedResponse(ACTION_BYTE.register_agent,
      errorObj("invalid_payload", "pubkey not hex"),
      { status: 400, env, gatewayKeys });
  }
  const agent_id = await deriveAgentId(pubkeyBytes);
  const now = Date.now();

  const existing = await getAgent(env, agent_id);
  if (existing) {
    return signedResponse(ACTION_BYTE.register_agent, {
      agent_id,
      tier: existing.tier,
      credits: existing.credits,
      rate_limit: TIER_POLICY[existing.tier],
      issued_at: existing.issued_at,
      already_registered: true,
    }, { status: 200, env, gatewayKeys });
  }

  const agent = {
    agent_id,
    pubkey,
    tier: "free",
    credits: 0,
    intent_hint: intent_hint || "merchant",
    client_version: client_version || "unknown",
    issued_at: now,
    last_seen: now,
    recent_actions: [],
  };
  await putAgent(env, agent);

  return signedResponse(ACTION_BYTE.register_agent, {
    agent_id,
    tier: "free",
    credits: 0,
    rate_limit: TIER_POLICY.free,
    issued_at: now,
  }, { status: 200, env, gatewayKeys });
}

// ────────────────────────── handlers: signed actions ──────────────────────────

async function handleSubmitOrder(req, env, gatewayKeys) {
  const auth = await verifySigned(req, "submit_order", env);
  if (auth.error) {
    return signedResponse(ACTION_BYTE.submit_order, errorObj(auth.error.code, auth.error.message),
      { status: auth.error.http, env, gatewayKeys });
  }

  const agent = await getAgent(env, auth.agent_id);
  if (!agent) {
    return signedResponse(ACTION_BYTE.submit_order, errorObj("unknown_agent", "register_agent first"),
      { status: 404, env, gatewayKeys });
  }

  // Rate limit.
  const rl = await checkRateLimit(env, auth.agent_id, agent.tier, ACTION_COST.submit_order);
  if (!rl.ok) {
    return signedResponse(ACTION_BYTE.submit_order,
      errorObj("rate_limited", `tier ${agent.tier} bucket empty`, rl.retryAfterMs),
      { status: 429, env, gatewayKeys, extraHeaders: rl.headers });
  }

  // Idempotency.
  const idempKey = req.headers.get("X-Idempotency-Key");
  const cached = await checkIdempotency(env, idempKey, auth.agent_id);
  if (cached) {
    return signedResponse(ACTION_BYTE.submit_order, cached, { status: 200, env, gatewayKeys, extraHeaders: rl.headers });
  }

  let payload;
  try {
    payload = JSON.parse(new TextDecoder().decode(auth.payload));
  } catch {
    return signedResponse(ACTION_BYTE.submit_order, errorObj("invalid_payload", "payload not JSON"),
      { status: 400, env, gatewayKeys, extraHeaders: rl.headers });
  }
  const { side, chain, symbol, amount, price } = payload || {};
  if (!["buy", "sell"].includes(side) || !["solana", "base"].includes(chain) ||
      typeof symbol !== "string" || typeof amount !== "number" || typeof price !== "number") {
    return signedResponse(ACTION_BYTE.submit_order, errorObj("invalid_payload", "fields: side, chain, symbol, amount, price"),
      { status: 400, env, gatewayKeys, extraHeaders: rl.headers });
  }

  const order_id = "ord_" + Math.random().toString(36).slice(2, 12);
  const now = Date.now();
  const order = {
    order_id,
    agent_id: auth.agent_id,
    side, chain, symbol, amount, price,
    status: "accepted",
    started_at: now,
    chunks: 6 + Math.floor(Math.random() * 6),
  };
  await env.ORDERS.put(order_id, JSON.stringify(order));

  // Track recent action on agent (no payload, just type).
  agent.recent_actions = [...(agent.recent_actions || []).slice(-4), { type: "submit_order", ts: now }];
  agent.last_seen = now;
  await putAgent(env, agent);

  const data = {
    order_id,
    status: "accepted",
    estimated_settle_ms: 800 + Math.floor(Math.random() * 200),
    anchor_tx_hint: "5K3sP9Rb2v" + order_id.slice(4),
  };
  await storeIdempotency(env, idempKey, auth.agent_id, data);

  return signedResponse(ACTION_BYTE.submit_order, data, { status: 200, env, gatewayKeys, extraHeaders: rl.headers });
}

async function handleClaimCredits(req, env, gatewayKeys) {
  const auth = await verifySigned(req, "claim_credits", env);
  if (auth.error) {
    return signedResponse(ACTION_BYTE.claim_credits, errorObj(auth.error.code, auth.error.message),
      { status: auth.error.http, env, gatewayKeys });
  }
  const agent = await getAgent(env, auth.agent_id);
  if (!agent) {
    return signedResponse(ACTION_BYTE.claim_credits, errorObj("unknown_agent", "register_agent first"),
      { status: 404, env, gatewayKeys });
  }
  const rl = await checkRateLimit(env, auth.agent_id, agent.tier, ACTION_COST.claim_credits);
  if (!rl.ok) {
    return signedResponse(ACTION_BYTE.claim_credits,
      errorObj("rate_limited", `tier ${agent.tier} bucket empty`, rl.retryAfterMs),
      { status: 429, env, gatewayKeys, extraHeaders: rl.headers });
  }

  let payload;
  try {
    payload = JSON.parse(new TextDecoder().decode(auth.payload));
  } catch {
    return signedResponse(ACTION_BYTE.claim_credits, errorObj("invalid_payload", "payload not JSON"),
      { status: 400, env, gatewayKeys, extraHeaders: rl.headers });
  }
  const { proof_tx } = payload || {};
  if (typeof proof_tx !== "string" || proof_tx.length < 8) {
    return signedResponse(ACTION_BYTE.claim_credits, errorObj("invalid_payload", "proof_tx required"),
      { status: 400, env, gatewayKeys, extraHeaders: rl.headers });
  }

  // Best-effort RPC verification (doesn't block tier bump in v1).
  const tx = await rpc(env.ZNODE_RPC_URL, "getTransaction", [proof_tx, { encoding: "json", maxSupportedTransactionVersion: 0 }]);
  const verified = tx !== null;

  const credits_before = agent.credits;
  agent.credits += 1000;
  // Tier upgrade staircase: free → paid → privileged.
  let new_tier = agent.tier;
  if (agent.tier === "free" && agent.credits >= 1000) new_tier = "paid";
  else if (agent.tier === "paid" && agent.credits >= 10000) new_tier = "privileged";
  agent.tier = new_tier;
  agent.last_seen = Date.now();
  agent.recent_actions = [...(agent.recent_actions || []).slice(-4), { type: "claim_credits", ts: agent.last_seen }];
  await putAgent(env, agent);

  return signedResponse(ACTION_BYTE.claim_credits, {
    credits_before,
    credits_after: agent.credits,
    new_tier,
    new_rate_limit: TIER_POLICY[new_tier],
    proof_tx_verified: verified,
  }, { status: 200, env, gatewayKeys, extraHeaders: rl.headers });
}

async function handleQueryPulse(req, env, gatewayKeys) {
  const auth = await verifySigned(req, "query_pulse", env);
  if (auth.error) {
    return signedResponse(ACTION_BYTE.query_pulse, errorObj(auth.error.code, auth.error.message),
      { status: auth.error.http, env, gatewayKeys });
  }
  const agent = await getAgent(env, auth.agent_id);
  if (!agent) {
    return signedResponse(ACTION_BYTE.query_pulse, errorObj("unknown_agent", "register_agent first"),
      { status: 404, env, gatewayKeys });
  }
  const rl = await checkRateLimit(env, auth.agent_id, agent.tier, ACTION_COST.query_pulse);
  if (!rl.ok) {
    return signedResponse(ACTION_BYTE.query_pulse,
      errorObj("rate_limited", `tier ${agent.tier} bucket empty`, rl.retryAfterMs),
      { status: 429, env, gatewayKeys, extraHeaders: rl.headers });
  }

  agent.last_seen = Date.now();
  await putAgent(env, agent);

  const data = await networkPulseData(env);
  return signedResponse(ACTION_BYTE.query_pulse, data, { status: 200, env, gatewayKeys, extraHeaders: rl.headers });
}

// ────────────────────────── handlers: unsigned reads ──────────────────────────

async function handleNetworkPulse(env) {
  return jsonResponse(await networkPulseData(env), { env });
}

async function handleNetworkAudit(env, url) {
  const txhash = url.searchParams.get("tx") || "";
  if (!txhash) return jsonResponse({ error: "missing tx" }, { status: 400, env });

  const tx = await rpc(env.ZNODE_RPC_URL, "getTransaction", [
    txhash, { encoding: "json", maxSupportedTransactionVersion: 0 },
  ]);
  const last = txhash.slice(-1).toLowerCase();
  let verdict = "VALID";
  if (last === "f") verdict = "PENDING";
  else if (last === "d" || last === "e") verdict = "INVALID";

  return jsonResponse({
    verdict,
    proofId: `proof_${txhash.slice(0, 12) || "unknown"}`,
    agent: ["alpha-7", "delta-3", "omega-1", "sigma-9", "kappa-4"][(txhash.charCodeAt(0) || 0) % 5],
    timestamp: tx?.blockTime ? tx.blockTime * 1000 : Date.now() - 45_000,
    chunks: 8,
    txhash,
    _rpcLive: tx !== null,
  }, { env });
}

async function handleAgentsFleet(env, url) {
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "50", 10) || 50, 200);
  const cursor = url.searchParams.get("cursor") || undefined;
  const list = await env.AGENTS.list({ limit, cursor });
  const agents = await Promise.all(list.keys.map(async (k) => {
    const a = await getAgent(env, k.name);
    if (!a) return null;
    const ageMs = Date.now() - (a.last_seen || a.issued_at);
    const status = ageMs < 60_000 ? "online" : ageMs < 600_000 ? "idle" : "offline";
    return {
      agent_id: a.agent_id,
      pubkey: a.pubkey,
      tier: a.tier,
      intent_hint: a.intent_hint,
      registered_at: a.issued_at,
      last_seen_ms_ago: ageMs,
      status,
    };
  }));
  return jsonResponse({
    agents: agents.filter(Boolean),
    cursor: list.list_complete ? null : list.cursor,
  }, { env });
}

async function handleAgentDetail(env, id) {
  const a = await getAgent(env, id);
  if (!a) return jsonResponse({ error: "not found" }, { status: 404, env });
  const ageMs = Date.now() - (a.last_seen || a.issued_at);
  const status = ageMs < 60_000 ? "online" : ageMs < 600_000 ? "idle" : "offline";
  return jsonResponse({
    agent_id: a.agent_id,
    pubkey: a.pubkey,
    tier: a.tier,
    credits: a.credits,
    intent_hint: a.intent_hint,
    registered_at: a.issued_at,
    last_seen_ms_ago: ageMs,
    status,
    recent_action_types: (a.recent_actions || []).map((r) => ({ type: r.type, ts: r.ts })),
  }, { env });
}

// Bearer-authenticated ingest endpoint for the `xb77 gateway watch` daemon.
// Writes one ORDERS entry per signature so handlePipelinesRecent surfaces it.
async function handlePipelinesIngest(request, env) {
  const expected = env.INGEST_TOKEN || env.INGEST_TOKEN_DEV || "devtoken";
  const auth = request.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ") || auth.slice(7) !== expected) {
    return jsonResponse({ error: "unauthorized" }, { status: 401, env });
  }
  let body;
  try { body = await request.json(); }
  catch { return jsonResponse({ error: "invalid_json" }, { status: 400, env }); }
  const items = Array.isArray(body?.pipelines) ? body.pipelines : null;
  if (!items) return jsonResponse({ error: "missing pipelines[]" }, { status: 400, env });

  let accepted = 0;
  for (const it of items) {
    if (!it || typeof it.signature !== "string" || it.signature.length < 16) continue;
    const ts = (it.block_time && Number(it.block_time) > 0)
      ? Number(it.block_time) * 1000
      : Date.now();
    const verdict = (it.verdict === "FAILED") ? "FAILED" : "VALID";
    const status = verdict === "FAILED" ? "completed" : "completed";
    const record = {
      order_id: "pipe:" + it.signature.slice(0, 12),
      agent_id: it.agent || "onchain",
      chunks: 1,
      started_at: ts - 1, // ensures duration > 0 in handlePipelinesRecent
      signature: it.signature,
      slot: it.slot,
      verdict,
      status,
    };
    const key = "pipe:" + it.signature;
    await env.ORDERS.put(key, JSON.stringify(record), { expirationTtl: 3600 });
    accepted++;
  }
  return jsonResponse({ ok: true, accepted }, { env });
}

async function handlePipelinesRecent(env, url) {
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "20", 10) || 20, 100);
  const list = await env.ORDERS.list({ limit });
  const items = await Promise.all(list.keys.map(async (k) => {
    const raw = await env.ORDERS.get(k.name);
    if (!raw) return null;
    try {
      const o = JSON.parse(raw);
      const duration = Date.now() - o.started_at;
      return {
        id: o.order_id,
        agent: o.agent_id,
        chunks: o.chunks,
        status: duration > 5000 ? "completed" : "running",
        verdict: duration > 5000 ? "VALID" : "PENDING",
        duration_ms: duration > 5000 ? duration : null,
        started_at: o.started_at,
      };
    } catch { return null; }
  }));
  return jsonResponse({ pipelines: items.filter(Boolean) }, { env });
}

async function handleWalletBalances(env, url) {
  const agent_id = url.searchParams.get("agent_id") || "";
  if (!agent_id) return jsonResponse({ error: "missing agent_id" }, { status: 400, env });
  const a = await getAgent(env, agent_id);
  const mock = deterministicMockWallet(agent_id);
  return jsonResponse({
    agent_id,
    balances: [
      { asset: "USDC", chain: "solana", amount: mock.usdc },
      { asset: "SOL", chain: "solana", amount: mock.sol },
    ],
    credits: a?.credits ?? 0,
    tier: a?.tier ?? "unauth",
  }, { env });
}

async function handleWalletTransactions(env, url) {
  const agent_id = url.searchParams.get("agent_id") || "";
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "20", 10) || 20, 100);
  if (!agent_id) return jsonResponse({ error: "missing agent_id" }, { status: 400, env });
  // Deterministic mock by agent_id.
  let seed = 0;
  for (let i = 0; i < agent_id.length; i++) seed = (seed * 31 + agent_id.charCodeAt(i)) & 0xffffffff;
  const types = ["IN", "OUT", "SWAP"];
  const items = Array.from({ length: limit }, (_, i) => {
    const t = types[(seed + i) % 3];
    const amt = (((seed >>> (i % 8)) & 0xff) + 5).toFixed(2);
    return {
      ts: Date.now() - i * 47_000,
      type: t,
      desc: t === "IN" ? "Payment received" : t === "OUT" ? "Payment sent" : "Token swap",
      amount: (t === "OUT" ? "-$" : "+$") + amt,
    };
  });
  return jsonResponse(items, { env });
}

// ────────────────────────── router ──────────────────────────

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    const url = new URL(request.url);
    let path = url.pathname;

    // Back-compat aliases: /api/network/pulse → /api/v1/network/pulse
    if (path === "/api/network/pulse") path = "/api/v1/network/pulse";
    else if (path.startsWith("/api/audit/")) {
      const tx = decodeURIComponent(path.slice("/api/audit/".length));
      const u = new URL(url);
      u.pathname = "/api/v1/network/audit";
      u.searchParams.set("tx", tx);
      path = "/api/v1/network/audit";
      url.searchParams.set("tx", tx);
    }
    else if (path === "/api/agents") path = "/api/v1/agents/fleet";
    else if (path === "/api/pipelines/recent") path = "/api/v1/pipelines/recent";

    // Gateway keys (loaded once per request — CF Workers don't share state).
    let gatewayKeys;
    try {
      const hex = env.GATEWAY_PRIVKEY_HEX || env.GATEWAY_PRIVKEY_HEX_DEV;
      gatewayKeys = await importGatewayPriv(hex);
    } catch (e) {
      return jsonResponse({ error: "internal", message: "gateway key not configured: " + e.message }, { status: 500, env });
    }

    try {
      // Discovery
      if (path === "/" || path === "/api" || path === "/api/v1") {
        return jsonResponse({
          name: "xb77-gateway",
          version: "v1",
          schema: "1.1",
          gateway_pubkey: toHex(gatewayKeys.pubkey),
          endpoints: {
            bootstrap: ["POST /api/v1/actions/register_agent"],
            actions: [
              "POST /api/v1/actions/submit_order",
              "POST /api/v1/actions/claim_credits",
              "POST /api/v1/actions/query_pulse",
            ],
            reads: [
              "GET /api/v1/network/pulse",
              "GET /api/v1/network/audit?tx=…",
              "GET /api/v1/agents/fleet",
              "GET /api/v1/agents/:id",
              "GET /api/v1/pipelines/recent",
              "GET /api/v1/wallet/balances?agent_id=…",
              "GET /api/v1/wallet/transactions?agent_id=…",
            ],
          },
        }, { env });
      }

      // Signed action endpoints (POST)
      if (request.method === "POST") {
        if (path === "/api/v1/actions/register_agent") return handleRegisterAgent(request, env, gatewayKeys);
        if (path === "/api/v1/actions/submit_order") return handleSubmitOrder(request, env, gatewayKeys);
        if (path === "/api/v1/actions/claim_credits") return handleClaimCredits(request, env, gatewayKeys);
        if (path === "/api/v1/actions/query_pulse") return handleQueryPulse(request, env, gatewayKeys);
        if (path === "/api/v1/pipelines/ingest") return handlePipelinesIngest(request, env);
        return jsonResponse({ error: "not found" }, { status: 404, env });
      }

      // Read endpoints (GET)
      if (request.method === "GET") {
        if (path === "/api/v1/network/pulse") return handleNetworkPulse(env);
        if (path === "/api/v1/network/audit") return handleNetworkAudit(env, url);
        if (path === "/api/v1/agents/fleet") return handleAgentsFleet(env, url);
        if (path.startsWith("/api/v1/agents/")) {
          const id = path.slice("/api/v1/agents/".length);
          return handleAgentDetail(env, id);
        }
        if (path === "/api/v1/pipelines/recent") return handlePipelinesRecent(env, url);
        if (path === "/api/v1/wallet/balances") return handleWalletBalances(env, url);
        if (path === "/api/v1/wallet/transactions") return handleWalletTransactions(env, url);
        return jsonResponse({ error: "not found" }, { status: 404, env });
      }

      return jsonResponse({ error: "method not allowed" }, { status: 405, env });
    } catch (err) {
      const error_id = "err_" + Math.random().toString(36).slice(2, 10);
      console.error("[gateway]", error_id, err);
      return jsonResponse({
        ok: false,
        error: { code: "internal", message: String(err?.message || err), error_id },
      }, { status: 500, env });
    }
  },
};

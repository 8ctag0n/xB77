/**
 * xB77 mock gateway — Contract v1 (docs/api-contract-v1.md, wire schema 1.1).
 *
 * Serves the webapp during local dev. Speaks the header-bound signature
 * protocol (X-Xb77-Pubkey / -Timestamp / -Nonce / -Signature) with binary
 * canonical bytes: action(1) || ts_be_u64_ms(8) || nonce(12) || payload_json.
 *
 * Endpoints
 *   POST /api/v1/actions/{register_agent|submit_order|claim_credits|query_pulse}
 *   GET  /api/v1/network/{pulse,audit}
 *   GET  /api/v1/agents/{fleet,:id}
 *   GET  /api/v1/pipelines/recent
 *   GET  /api/v1/wallet/{balances,transactions}
 *
 * Dev knobs
 *   XB77_VERIFY_SIGS=1   enforce Ed25519 verification on POSTs (real SDK)
 *                        default OFF so a stub-signing client still works
 *   ?force429=1          force a 429 on any read to test the toast
 *
 * In-memory state only; restarts wipe agents/orders.
 *
 * Boot:
 *   bun run sdk/ts/dev/mock-gateway.ts [--port PORT]
 */

const args = parseArgs(process.argv.slice(2));
const port = Number(args.port ?? process.env.XB77_GATEWAY_PORT ?? 8787);
const VERIFY_SIGS = process.env.XB77_VERIFY_SIGS === "1";

// ── In-memory state ──────────────────────────────────────────────────────
type Agent = { agent_id: string; pubkey: string; tier: string; intent_hint: string; registered_at: number; last_seen_ms_ago: number; status: string };
type Pipeline = { id: string; agent: string; chunks: number; status: string; verdict: string; duration_ms: number; started_at: number };

const agents = new Map<string, Agent>();
const orders: Pipeline[] = seedPipelines();
const idempotencyCache = new Map<string, unknown>();
const T0 = Date.now();
seedAgents();

// ── Wire-1.1 protocol helpers (mirror sdk/ts/src) ────────────────────────
const ACTION_PATHS: Record<string, number> = {
  "/api/v1/actions/submit_order":   0x01,
  "/api/v1/actions/register_agent": 0x02,
  "/api/v1/actions/claim_credits":  0x03,
  "/api/v1/actions/query_pulse":    0x04,
};

function canonicalRequest(action: number, ts_ms: number, nonce: Uint8Array, payload: Uint8Array): Uint8Array {
  const out = new Uint8Array(1 + 8 + 12 + payload.length);
  out[0] = action;
  const bts = BigInt(ts_ms);
  for (let i = 0; i < 8; i++) out[1 + i] = Number((bts >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(nonce, 9);
  out.set(payload, 21);
  return out;
}

function canonicalResponse(action: number, ts_ms: number, body: Uint8Array): Uint8Array {
  const out = new Uint8Array(1 + 8 + body.length);
  out[0] = action;
  const bts = BigInt(ts_ms);
  for (let i = 0; i < 8; i++) out[1 + i] = Number((bts >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(body, 9);
  return out;
}

const fromHex = (s: string): Uint8Array => {
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
};
const toHex = (b: Uint8Array): string => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

async function sha256Bytes(b: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", b));
}

async function agentIdFromPubkeyHex(pkHex: string): Promise<string> {
  const digest = await sha256Bytes(fromHex(pkHex));
  return "ag_" + toHex(digest.slice(0, 9));
}

// Gateway signing key for response signatures.
const gwKp = (await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])) as CryptoKeyPair;
const gwPubHex = toHex(new Uint8Array(await crypto.subtle.exportKey("raw", gwKp.publicKey)));

// ── CORS + rate-limit header helpers ─────────────────────────────────────
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Agent-Id, X-Idempotency-Key, X-API-Version, X-Xb77-Pubkey, X-Xb77-Timestamp, X-Xb77-Nonce, X-Xb77-Signature",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Expose-Headers": "X-RateLimit-Tier, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, X-RateLimit-Cost, Retry-After, X-Xb77-Gateway-Timestamp, X-Xb77-Gateway-Signature",
};

function rlHeaders(tier = "free", remaining = 28): Record<string, string> {
  const per = tier === "paid" ? 300 : tier === "privileged" ? 3000 : 30;
  return {
    "X-RateLimit-Tier": tier,
    "X-RateLimit-Limit": String(per),
    "X-RateLimit-Remaining": String(remaining),
    "X-RateLimit-Reset": String(Math.floor(Date.now() / 1000) + 60),
    "X-RateLimit-Cost": "1",
  };
}

const errBody = (code: string, message: string, extra: Record<string, unknown> = {}) =>
  ({ ok: false, error: { code, message, ...extra } });

async function signedJson(action: number, data: unknown, status = 200, extra: Record<string, string> = {}) {
  const body = JSON.stringify({ ok: true, data });
  const bodyBytes = new TextEncoder().encode(body);
  const ts = Date.now();
  const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", gwKp.privateKey, canonicalResponse(action, ts, bodyBytes)));
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "application/json",
      "X-Xb77-Gateway-Timestamp": String(ts),
      "X-Xb77-Gateway-Signature": toHex(sig),
      ...CORS, ...rlHeaders(), ...extra,
    },
  });
}

const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS, ...rlHeaders(), ...extra },
  });

// ── Action handlers (ctx-based: derived agent_id from pubkey) ────────────
type ActionCtx = { payload: any; agent_id: string | null; pubkey_hex: string | null };

async function registerAgent(ctx: ActionCtx) {
  // register_agent is the bootstrap: signature optional (no prior agent).
  // Pubkey is taken from the X-Xb77-Pubkey header when present, else from payload.
  const pubkey: string = ctx.pubkey_hex || ctx.payload?.pubkey || "";
  if (!pubkey) return json(errBody("invalid_payload", "missing pubkey"), 400);
  const agent_id = ctx.agent_id || await agentIdFromPubkeyHex(pubkey);
  if (!agents.has(agent_id)) {
    agents.set(agent_id, {
      agent_id, pubkey, tier: "free",
      intent_hint: ctx.payload?.intent_hint || "merchant",
      registered_at: Date.now(),
      last_seen_ms_ago: 0, status: "online",
    });
  }
  const a = agents.get(agent_id)!;
  return signedJson(0x02, {
    agent_id, tier: a.tier, credits: 0,
    rate_limit: { per_minute: 30, burst: 10 },
    issued_at: Date.now(),
  });
}

async function submitOrder(ctx: ActionCtx) {
  const order_id = "ord_" + Math.random().toString(36).slice(2, 12);
  orders.unshift({
    id: order_id, agent: ctx.agent_id || "ag_anon",
    chunks: 6 + Math.floor(Math.random() * 5),
    status: "running", verdict: "PENDING",
    duration_ms: 0, started_at: Date.now(),
  });
  return signedJson(0x01, {
    order_id, status: "accepted",
    estimated_settle_ms: 850,
    anchor_tx_hint: "5K3sP9Rb2v" + Math.random().toString(36).slice(2, 12),
  });
}

async function claimCredits(ctx: ActionCtx) {
  const a = ctx.agent_id ? agents.get(ctx.agent_id) : null;
  if (a) a.tier = "paid";
  return signedJson(0x03, {
    credits_before: 0, credits_after: 1000,
    new_tier: "paid",
    new_rate_limit: { per_minute: 300, burst: 60 },
  });
}

async function queryPulse() {
  return signedJson(0x04, pulse());
}

// ── Server ───────────────────────────────────────────────────────────────
const server = Bun.serve({
  port,
  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

    if (url.searchParams.get("force429") === "1") {
      return new Response(JSON.stringify(errBody("rate_limited", "forced via ?force429=1", { retry_after_ms: 5000 })), {
        status: 429,
        headers: { "Content-Type": "application/json", "Retry-After": "5", ...CORS, ...rlHeaders("free", 0) },
      });
    }

    const p = url.pathname;

    // Gateway metadata.
    if (req.method === "GET" && (p === "/" || p === "/_meta")) {
      return json({ name: "xb77-mock-gateway", contract: "v1", wire_schema: "1.1", verify_sigs: VERIFY_SIGS, gateway_pubkey_hex: gwPubHex });
    }

    // GET reads (unsigned).
    if (req.method === "GET") {
      if (p === "/api/v1/network/pulse" || p === "/api/network/pulse") return json(pulse());
      if (p === "/api/v1/network/audit") {
        const tx = url.searchParams.get("tx") || "";
        return json({ verdict: "VALID", proofId: "proof_" + tx.slice(0, 12), agent: "omega-1", timestamp: Date.now(), chunks: 8, txhash: tx });
      }
      if (p === "/api/v1/agents/fleet") {
        const limit = Math.min(50, Number(url.searchParams.get("limit") || 50));
        return json({ agents: Array.from(agents.values()).slice(0, limit), next_cursor: null });
      }
      if (p.startsWith("/api/v1/agents/")) {
        const id = p.slice("/api/v1/agents/".length);
        const a = agents.get(id);
        if (!a) return json(errBody("unknown_agent", "no such agent_id"), 404);
        return json({ ...a, recent_actions: ["submit_order", "claim_credits", "query_pulse"] });
      }
      if (p === "/api/v1/pipelines/recent") {
        const limit = Math.min(50, Number(url.searchParams.get("limit") || 20));
        return json({ pipelines: orders.slice(0, limit) });
      }
      if (p === "/api/v1/wallet/balances") {
        return json({
          agent_id: url.searchParams.get("agent_id"),
          balances: [
            { asset: "USDC", chain: "solana", amount: 1500.50 },
            { asset: "SOL",  chain: "solana", amount: 2.34 },
          ],
          credits: 1000, tier: "paid",
        });
      }
      if (p === "/api/v1/wallet/transactions") {
        return json([
          { ts: Date.now() - 5000, type: "IN", desc: "Payment from cafe-sovereign", amount: "+$45.20" },
        ]);
      }
    }

    // POST /api/v1/actions/* — wire schema 1.1.
    if (req.method === "POST" && p.startsWith("/api/v1/actions/")) {
      const action = ACTION_PATHS[p];
      if (action === undefined) return json(errBody("invalid_payload", "unknown action: " + p), 400);

      const bodyBytes = new Uint8Array(await req.arrayBuffer());
      const pkHex    = req.headers.get("X-Xb77-Pubkey");
      const sigHex   = req.headers.get("X-Xb77-Signature");
      const tsStr    = req.headers.get("X-Xb77-Timestamp");
      const nonceHex = req.headers.get("X-Xb77-Nonce");
      const actionName = p.slice("/api/v1/actions/".length);

      // register_agent is the bootstrap exception: signature optional.
      const isBootstrap = actionName === "register_agent";

      if (VERIFY_SIGS && !isBootstrap) {
        if (!pkHex || !sigHex || !tsStr || !nonceHex) {
          return json(errBody("invalid_signature", "missing auth headers"), 401);
        }
        const nonce = fromHex(nonceHex);
        if (nonce.length !== 12) return json(errBody("invalid_nonce", "nonce must be 12 bytes"), 401);
        const ts_ms = Number(tsStr);
        if (!Number.isFinite(ts_ms) || Math.abs(Date.now() - ts_ms) > 30_000) {
          return json(errBody("clock_skew", "ts outside ±30s window"), 401);
        }
        const clientPub = fromHex(pkHex);
        const sig = fromHex(sigHex);
        const clientKey = await crypto.subtle.importKey("raw", clientPub, "Ed25519", false, ["verify"]);
        const ok = await crypto.subtle.verify("Ed25519", clientKey, sig, canonicalRequest(action, ts_ms, nonce, bodyBytes));
        if (!ok) return json(errBody("invalid_signature", "signature did not verify"), 401);
      }

      // Idempotency replay.
      const idem = req.headers.get("X-Idempotency-Key");
      if (idem) {
        const cached = idempotencyCache.get(idem);
        if (cached) return json(cached);
      }

      // Parse payload JSON from raw body (per wire 1.1 — no envelope wrapper).
      let payload: any = {};
      if (bodyBytes.length > 0) {
        try { payload = JSON.parse(new TextDecoder().decode(bodyBytes)); }
        catch { return json(errBody("invalid_payload", "bad JSON body"), 400); }
      }

      const ctx: ActionCtx = {
        payload,
        agent_id: pkHex ? await agentIdFromPubkeyHex(pkHex) : null,
        pubkey_hex: pkHex,
      };

      let resp: Response;
      switch (actionName) {
        case "register_agent": resp = await registerAgent(ctx); break;
        case "submit_order":   resp = await submitOrder(ctx);   break;
        case "claim_credits":  resp = await claimCredits(ctx);  break;
        case "query_pulse":    resp = await queryPulse();        break;
        default: return json(errBody("invalid_payload", "unknown action: " + actionName), 400);
      }
      if (idem) idempotencyCache.set(idem, await resp.clone().json());
      return resp;
    }

    return new Response("not found: " + p, { status: 404, headers: CORS });
  },
});

console.log(`[mock-gateway v1] listening on ${server.url.toString()}`);
console.log(`[mock-gateway v1] contract: docs/api-contract-v1.md (wire schema 1.1)`);
console.log(`[mock-gateway v1] verify_sigs: ${VERIFY_SIGS}  (set XB77_VERIFY_SIGS=1 to enforce)`);
console.log(`[mock-gateway v1] gateway_pubkey_hex: ${gwPubHex}`);
console.log(`[mock-gateway v1] hint: append ?force429=1 to any read to trigger the 429 toast`);

// ── Data helpers ─────────────────────────────────────────────────────────
function pulse() {
  return {
    slot: 250_412_311 + Math.floor((Date.now() - T0) / 400),
    blockHeight: 250_411_104 + Math.floor((Date.now() - T0) / 400),
    agentsOnline: agents.size,
    proofsVerified24h: 1247 + Math.floor((Date.now() - T0) / 60_000),
    ts: Date.now(),
  };
}

function seedAgents() {
  const seed: Array<[string, string, string]> = [
    ["alpha-7", "ALPH...7zKq", "merchant"],
    ["delta-3", "DELT...3mN8", "trader"],
    ["omega-1", "OMEG...1pQ4", "treasury"],
  ];
  for (const [_, pubkey, intent] of seed) {
    // Lightweight deterministic id for seed (real handlers compute via sha256).
    let h = 0;
    for (let i = 0; i < pubkey.length; i++) h = ((h << 5) - h + pubkey.charCodeAt(i)) | 0;
    const id = "ag_" + (h >>> 0).toString(16).padStart(8, "0") + pubkey.slice(0, 10);
    agents.set(id, {
      agent_id: id, pubkey, tier: "free", intent_hint: intent,
      registered_at: Date.now() - 86_400_000, last_seen_ms_ago: 5_000, status: "online",
    });
  }
}

function seedPipelines(): Pipeline[] {
  return Array.from({ length: 5 }, (_, i) => ({
    id: "pl_seed" + i,
    agent: ["alpha-7", "delta-3", "omega-1"][i % 3],
    chunks: 6 + i,
    status: "completed",
    verdict: "VALID",
    duration_ms: 2400 + i * 117,
    started_at: Date.now() - (i + 1) * 47_000,
  }));
}

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const eq = key.indexOf("=");
      if (eq >= 0) { out[key.slice(0, eq)] = key.slice(eq + 1); }
      else if (i + 1 < argv.length && !argv[i + 1].startsWith("--")) { out[key] = argv[i + 1]; i++; }
      else { out[key] = "true"; }
    }
  }
  return out;
}

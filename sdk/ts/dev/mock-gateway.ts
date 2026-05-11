/**
 * xB77 mock gateway — Contract v1 (docs/api-contract-v1.md).
 *
 * Serves the webapp during local dev. Implements the JSON-envelope spec:
 *   POST /api/v1/actions/{register_agent|submit_order|claim_credits|query_pulse}
 *   GET  /api/v1/network/{pulse,audit}
 *   GET  /api/v1/agents/{fleet,:id}
 *   GET  /api/v1/pipelines/recent
 *   GET  /api/v1/wallet/{balances,transactions}
 *
 * Compromises for dev ergonomics:
 *   - Signature is NOT verified (the webapp ships a stub signer until the
 *     SDK is vendored). Real verification belongs in feat/gateway-realdata.
 *   - gateway_sig is a placeholder string.
 *   - Rate-limit headers are emitted but no real throttling: pass
 *     `?force429=1` on any read endpoint to simulate a 429 with Retry-After.
 *   - In-memory state only; restarts wipe agents/orders.
 *
 * Boot:
 *   bun run sdk/ts/dev/mock-gateway.ts [--port PORT]
 */

const args = parseArgs(process.argv.slice(2));
const port = Number(args.port ?? process.env.XB77_GATEWAY_PORT ?? 8787);

// ── In-memory state ──────────────────────────────────────────────────────
type Agent = { agent_id: string; pubkey: string; tier: string; intent_hint: string; registered_at: number; last_seen_ms_ago: number; status: string };
type Pipeline = { id: string; agent: string; chunks: number; status: string; verdict: string; duration_ms: number; started_at: number };

const agents = new Map<string, Agent>();
const orders: Pipeline[] = seedPipelines();
const idempotencyCache = new Map<string, unknown>();
const T0 = Date.now();

// Seed a couple of agents so /agents/fleet isn't empty on first load.
seedAgents();

// ── CORS + RL header helpers ─────────────────────────────────────────────
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Agent-Id, X-Idempotency-Key, X-API-Version",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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

const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS, ...rlHeaders(), ...extra },
  });

const errBody = (code: string, message: string, extra: Record<string, unknown> = {}) =>
  ({ ok: false, error: { code, message, ...extra } });

const dataBody = (data: unknown) =>
  ({ ok: true, data, gateway_sig: "ed25519:stub-gw." + Math.random().toString(36).slice(2, 10) });

// ── Action handlers ──────────────────────────────────────────────────────
async function registerAgent(body: any) {
  const pubkey: string = body.pubkey || "";
  if (!pubkey) return json(errBody("invalid_payload", "missing pubkey"), 400);
  const agent_id = "ag_" + sha18(pubkey);
  if (!agents.has(agent_id)) {
    agents.set(agent_id, {
      agent_id, pubkey, tier: "free",
      intent_hint: body.intent_hint || "merchant",
      registered_at: Date.now(),
      last_seen_ms_ago: 0, status: "online",
    });
  }
  const a = agents.get(agent_id)!;
  return json(dataBody({
    agent_id, tier: a.tier, credits: 0,
    rate_limit: { per_minute: 30, burst: 10 },
    issued_at: Date.now(),
  }));
}

async function submitOrder(env: any) {
  const order_id = "ord_" + Math.random().toString(36).slice(2, 12);
  const order: Pipeline = {
    id: order_id, agent: env.agent_id || "ag_anon",
    chunks: 6 + Math.floor(Math.random() * 5),
    status: "running", verdict: "PENDING",
    duration_ms: 0, started_at: Date.now(),
  };
  orders.unshift(order);
  return json(dataBody({
    order_id, status: "accepted",
    estimated_settle_ms: 850,
    anchor_tx_hint: "5K3sP9Rb2v" + Math.random().toString(36).slice(2, 12),
  }));
}

async function claimCredits(env: any) {
  const a = agents.get(env.agent_id);
  const before = 0;
  const after = before + 1000;
  if (a) a.tier = "paid";
  return json(dataBody({
    credits_before: before, credits_after: after,
    new_tier: "paid",
    new_rate_limit: { per_minute: 300, burst: 60 },
  }));
}

async function queryPulse() {
  return json(dataBody(pulse()));
}

// ── Routes ───────────────────────────────────────────────────────────────
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

    // POST actions (envelope, signature not verified in mock).
    if (req.method === "POST" && p.startsWith("/api/v1/actions/")) {
      let body: any;
      try { body = await req.json(); } catch { return json(errBody("invalid_payload", "bad JSON"), 400); }

      const idem = req.headers.get("X-Idempotency-Key");
      if (idem) {
        const cached = idempotencyCache.get(idem);
        if (cached) return json(cached);
      }

      const action = p.slice("/api/v1/actions/".length);
      let resp: Response;
      switch (action) {
        case "register_agent": resp = await registerAgent(body); break;
        case "submit_order":   resp = await submitOrder(body);   break;
        case "claim_credits":  resp = await claimCredits(body);  break;
        case "query_pulse":    resp = await queryPulse();        break;
        default: return json(errBody("invalid_payload", "unknown action: " + action), 400);
      }
      if (idem) idempotencyCache.set(idem, await resp.clone().json());
      return resp;
    }

    return new Response("not found: " + p, { status: 404, headers: CORS });
  },
});

console.log(`[mock-gateway v1] listening on ${server.url.toString()}`);
console.log(`[mock-gateway v1] contract: docs/api-contract-v1.md`);
console.log(`[mock-gateway v1] hint: append ?force429=1 to any read to trigger the 429 toast`);

// ── Helpers ──────────────────────────────────────────────────────────────
function sha18(s: string): string {
  // Lightweight deterministic id from input (not cryptographic — mock only).
  let h = 0;
  for (let i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
  const hex = (h >>> 0).toString(16).padStart(8, "0");
  return (hex + s.slice(0, 10)).slice(0, 18);
}

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
  for (const [name, pubkey, intent] of seed) {
    const id = "ag_" + sha18(pubkey);
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

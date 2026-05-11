# xB77 Gateway API — Contract v1

> Source of truth shared by the **frontend worktree** (`feat/dapp-public-split`) and the **backend worktree** (`feat/gateway-realdata`). Any change to this file requires updating both implementations in lockstep.

**Version:** v1
**Base URL (local):** `http://127.0.0.1:8787`
**Base URL (CF):** `https://gateway.xb77.io` (or whatever the wrangler config resolves to)
**All routes prefixed with:** `/api/v1` (the existing `/api/network/pulse` aliases to `/api/v1/network/pulse` for back-compat through v1.)

---

## 1. Wire conventions

### 1.1 Request format

All write endpoints (`POST`) take a **signed envelope**:

```json
{
  "agent_id": "ag_a3f1c8d2…",
  "ts": 1714532145123,
  "nonce": "b3f1c8d2e4a9",
  "action": "submit_order",
  "payload": { /* action-specific */ },
  "signature": "ed25519:base64(...)"
}
```

- `agent_id` — pubkey-derived identifier. Generated server-side on `register_agent`, owned by the keystore that signs it from then on.
- `ts` — unix milliseconds. Server rejects requests where `|now - ts| > 30000` (30s window).
- `nonce` — 12-byte hex. Server keeps a 5-minute rolling set per `agent_id` to reject replays.
- `signature` — Ed25519 over the canonical bytes of `{agent_id, ts, nonce, action, payload}` (see SDK spec addendum §A for canonical serialization).

### 1.2 Response format

Successful response:

```json
{
  "ok": true,
  "data": { /* endpoint-specific */ },
  "gateway_sig": "ed25519:base64(...)"
}
```

- `gateway_sig` — Ed25519 signature by the gateway over `data`. Lets the client verify the response wasn't tampered. Gateway pubkey is pinned in the SDK as `XB77_GATEWAY_PUBKEY`.

Error response:

```json
{
  "ok": false,
  "error": {
    "code": "rate_limited",
    "message": "Tier free allows 30 req/min; retry in 12s.",
    "retry_after_ms": 12000
  }
}
```

### 1.3 Error codes (string enum)

| Code | HTTP | Meaning |
|---|---|---|
| `invalid_signature` | 401 | Signature didn't verify against `agent_id`'s pubkey |
| `invalid_nonce` | 401 | Nonce reused within the 5-min window |
| `clock_skew` | 401 | `ts` outside the ±30s window |
| `unknown_agent` | 404 | `agent_id` not registered |
| `rate_limited` | 429 | Per-agent or global limit hit (see §4) |
| `invalid_payload` | 400 | Action-specific validation failed |
| `insufficient_credits` | 402 | Action priced and agent's credit balance is too low |
| `internal` | 500 | Server bug — body includes `error_id` for traceability |

### 1.4 CORS

All endpoints respond with `Access-Control-Allow-Origin: *` (gateway is read-mostly and write paths are signed, so origin restriction adds no security and breaks the SDK pattern). `Access-Control-Allow-Headers: Content-Type, X-Agent-Id, X-Idempotency-Key`. `OPTIONS` preflight returns 204.

---

## 2. Endpoints

### 2.1 Bootstrap (unauthenticated)

#### `POST /api/v1/actions/register_agent`

Create a new agent identity. **No signature required**, since the agent doesn't have one yet. Rate limited globally and per-IP (§4) to prevent fleet flooding.

**Request body:**
```json
{
  "pubkey": "base58(ed25519_pubkey)",
  "intent_hint": "merchant" | "treasury" | "trader" | "indexer",
  "client_version": "@xb77/sdk@1.0.0"
}
```

**Response data:**
```json
{
  "agent_id": "ag_a3f1c8d2e4a9b1c8d2",
  "tier": "free",
  "credits": 0,
  "rate_limit": { "per_minute": 30, "burst": 10 },
  "issued_at": 1714532145123
}
```

The gateway derives `agent_id` from `sha256(pubkey)[:18]`.

### 2.2 Signed actions

All require the §1.1 signed envelope. All return §1.2 signed response.

#### `POST /api/v1/actions/submit_order`

Submit a payment intent.

**Payload:**
```json
{
  "side": "buy" | "sell",
  "chain": "solana" | "base",
  "symbol": "USDC",
  "amount": 1000,
  "price": 10000,
  "idempotency_key": "optional-client-uuid"
}
```

**Response data:**
```json
{
  "order_id": "ord_1k3sP9Rb2v",
  "status": "accepted",
  "estimated_settle_ms": 850,
  "anchor_tx_hint": "5K3sP9Rb2vQfNm8jX1pT4hY7wL9aE6cZ0gA"
}
```

#### `POST /api/v1/actions/claim_credits`

Convert payment proof into platform credits (raises rate limit tier).

**Payload:**
```json
{
  "proof_tx": "5K3sP9Rb2v..."
}
```

**Response data:**
```json
{
  "credits_before": 0,
  "credits_after": 1000,
  "new_tier": "paid",
  "new_rate_limit": { "per_minute": 300, "burst": 60 }
}
```

#### `POST /api/v1/actions/query_pulse`

Signed variant of pulse for agents that want auditable telemetry.

**Payload:** `{}` (empty, signature attests the agent asked at `ts`)

**Response data:** see §2.3 `/api/v1/network/pulse` data shape.

### 2.3 Read endpoints (unsigned — cacheable / public)

These don't take a signed envelope. They return raw JSON without the `gateway_sig` envelope, because they're public-read and the data is observable onchain anyway. Each endpoint MAY apply a per-IP rate limit (§4).

#### `GET /api/v1/network/pulse`
Same as today. Returns `{slot, blockHeight, agentsOnline, proofsVerified24h, ts}`.

#### `GET /api/v1/network/audit?tx=<hash>`
Same as today. Returns audit verdict.

#### `GET /api/v1/agents/fleet?limit=50&cursor=...`
List agents. Pagination via opaque cursor. Each entry:
```json
{
  "agent_id": "ag_a3f1c8d2...",
  "pubkey": "base58...",
  "tier": "free" | "paid" | "privileged",
  "intent_hint": "merchant",
  "registered_at": 1714532145123,
  "last_seen_ms_ago": 5234,
  "status": "online" | "idle" | "offline"
}
```

#### `GET /api/v1/agents/:id`
Single-agent detail. Includes recent request count, last 5 actions (action type only, not payloads — no signed-data leak).

#### `GET /api/v1/pipelines/recent?limit=20`
Returns the last N orders that completed onchain. Each entry:
```json
{
  "id": "ord_1k3sP9Rb2v",
  "agent": "ag_a3f1c8d2...",
  "chunks": 8,
  "status": "completed" | "running" | "failed",
  "verdict": "VALID" | "INVALID" | "PENDING",
  "duration_ms": 1234,
  "started_at": 1714532145123
}
```

#### `GET /api/v1/wallet/balances?agent_id=<id>`
For the calling agent only — enforced via `X-Agent-Id` header matching a presented signed challenge cookie. (For v1 demo we keep this lax: agent_id in query, no auth, returns mock-but-real-shaped data.)
```json
{
  "agent_id": "ag_a3f1c8d2...",
  "balances": [
    { "asset": "USDC", "chain": "solana", "amount": 1500.50 },
    { "asset": "SOL",  "chain": "solana", "amount": 2.34 }
  ],
  "credits": 1000,
  "tier": "paid"
}
```

#### `GET /api/v1/wallet/transactions?agent_id=<id>&limit=20`
Last N transactions tied to the agent.
```json
[
  { "ts": 1714532145123, "type": "IN" | "OUT" | "SWAP", "desc": "Payment from cafe-sovereign", "amount": "+$45.20" }
]
```

---

## 3. Idempotency

`POST` endpoints accept an optional `X-Idempotency-Key` header OR an `idempotency_key` field in the payload. Within a 24h window, a repeat key returns the cached prior response with HTTP 200 (not 409) so retries are safe.

---

## 4. Rate limiting

### 4.1 Policy by tier

| Tier | Requests / min | Burst | Allowed actions |
|---|---|---|---|
| `unauth` (per-IP) | 10 | 3 | `register_agent`, GET /network/*, GET /agents/fleet (preview, 5 items max) |
| `free` | 30 | 10 | All actions; `submit_order` capped at 5/min |
| `paid` | 300 | 60 | All; no per-action cap |
| `privileged` | 3000 | 600 | All; can hit `query_pulse` at 1Hz |

Tier upgrade happens via `claim_credits`. Down-tier never happens automatically; credits depleted just means you can't claim further upgrades.

### 4.2 Algorithm

**Token bucket per `agent_id`** (or per-IP for unauth). Refill at `per_minute / 60` tokens/sec. Bucket capacity = `burst`. Each request consumes 1 token unless the endpoint reservation says otherwise.

Expensive endpoints can declare higher cost: `submit_order` costs 3 tokens, `query_pulse` costs 1, GETs cost 1.

### 4.3 Response headers (always present)

```
X-RateLimit-Tier: free
X-RateLimit-Limit: 30
X-RateLimit-Remaining: 27
X-RateLimit-Reset: 1714532205
X-RateLimit-Cost: 1
```

On 429:
```
Retry-After: 12
```

### 4.4 Server-side defense in depth

- **Global token bucket per gateway worker**: 1000 req/sec hard ceiling. Above that, all tiers get a 503 backpressure with `Retry-After: 1`.
- **Per-IP CAPTCHA gate** (post-v1): if an IP creates >5 unique `register_agent` calls in 10 minutes, gateway returns 429 with a CAPTCHA URL for the next bootstrap.
- **Agent quarantine**: if an `agent_id` triggers `invalid_signature` 10 times in a row, quarantine for 5 minutes (`429 quarantined`).

---

## 5. Agent lifecycle

```
unauth → register_agent → free
free → claim_credits(small) → paid
paid → claim_credits(large) → privileged
any → inactive (30 days no signed action) → soft-deletion at 90 days
```

Inactive agents:
- Still appear in `/agents/fleet` with `status: "offline"` for 30 days.
- Their rate limit bucket is reaped to free memory.
- They can be reactivated by a signed action — the gateway re-creates the bucket.

Soft-deleted agents:
- `unknown_agent` returned on action attempts.
- `agent_id` is reserved (never reissued) so existing data integrity holds.

---

## 6. Versioning

- This contract is **v1**. All endpoints under `/api/v1/`.
- Breaking changes go to `/api/v2/` and v1 keeps working for at least 90 days post-cutover.
- Non-breaking additions (new optional fields, new endpoints) are allowed in v1.
- The SDK pins `accept-version: v1` via `X-API-Version` header. Server rejects mismatches with 400.

---

## 7. What MUST be implemented in v1 (backend worktree)

Backend (in `feat/gateway-realdata`) ships these to satisfy this contract:

- [ ] `POST /api/v1/actions/register_agent` — generates agent_id, stores pubkey, returns tier free.
- [ ] `POST /api/v1/actions/submit_order` — verifies sig, applies rate limit, records to KV (or D1 / Durable Object), returns order_id.
- [ ] `POST /api/v1/actions/claim_credits` — verifies sig + verifies the `proof_tx` exists (best-effort RPC call), updates tier.
- [ ] `POST /api/v1/actions/query_pulse` — same as GET but with signed envelope.
- [ ] `GET /api/v1/network/pulse` — existing.
- [ ] `GET /api/v1/network/audit` — existing.
- [ ] `GET /api/v1/agents/fleet` — query KV / Durable Object for live agents.
- [ ] `GET /api/v1/agents/:id` — single agent detail.
- [ ] `GET /api/v1/pipelines/recent` — KV-cached recent orders.
- [ ] `GET /api/v1/wallet/balances` — for v1: returns deterministic-mock-from-real-agent-id shape.
- [ ] `GET /api/v1/wallet/transactions` — same: deterministic-mock-by-id shape.
- [ ] Rate limit middleware: token bucket + headers per §4.
- [ ] Idempotency cache (KV with 24h TTL).
- [ ] Nonce replay protection (KV with 5min TTL).
- [ ] CORS preflight for all routes.

Out of scope for v1 (backend): real onchain wallet queries (requires Helius RPC keys), real-time websocket fleet updates, CAPTCHA on bootstrap.

---

## 8. What MUST be implemented in v1 (frontend worktree)

Frontend (in `feat/dapp-public-split`) consumes the contract:

- [ ] Keystore generate/import flow with password modal.
- [ ] `register_agent` on first session (or import existing agent_id from localStorage).
- [ ] Wire `Wallet → Claim credits` to `POST /api/v1/actions/claim_credits`.
- [ ] Wire `Pipelines → Run pipeline` to `POST /api/v1/actions/submit_order`. On success, append to tx log (lift state).
- [ ] Wire `Agents → Deploy agent` to `POST /api/v1/actions/register_agent` (creates a *child* agent under the connected one).
- [ ] Replace `DataSource.networkPulse` mock branch with `GET /api/v1/network/pulse`.
- [ ] Replace `DataSource.agents` with `GET /api/v1/agents/fleet`.
- [ ] Replace `DataSource.pipelinesRecent` with `GET /api/v1/pipelines/recent`.
- [ ] Render rate limit headers in a debug strip (bottom-right, dev-only): show `Tier · Remaining · Reset`.
- [ ] Handle 429 with a toast: "Rate limited — retry in Xs".

---

## 9. Mock-first development order

Frontend can progress without backend ready by pointing `XB77_GATEWAY` at the existing `sdk/ts/dev/mock-gateway.ts` which the SDK already ships. Backend implements against the contract independently.

Final swap: change `window.XB77_GATEWAY` in `index.html` / `app.html` to the real CF URL (or `http://127.0.0.1:8787` for the local worker).

---

## 10. Open questions deferred to v1.1

- Per-merchant tenant isolation (multi-app on one gateway).
- WebSocket subscriptions instead of polling on `/network/pulse`.
- Server-side webhook callbacks for long-running orders.
- API key auth (in addition to per-request signing) for indexers.
- CAPTCHA gate for `register_agent`.
- Real onchain wallet queries (Helius RPC integration).

These ship after the hackathon clock dies.

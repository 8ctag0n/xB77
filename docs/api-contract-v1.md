# xB77 Gateway API — Contract v1

> Source of truth shared by the **frontend worktree** (`feat/dapp-public-split`) and the **backend worktree** (`feat/gateway-realdata`). Any change to this file requires updating both implementations in lockstep.

**Version:** v1 (wire schema 1.1 — see §1.5)
**Base URL (local):** `http://127.0.0.1:8787`
**Base URL (CF):** `https://gateway.xb77.io` (or whatever the wrangler config resolves to)
**All routes prefixed with:** `/api/v1` (the legacy `/api/network/pulse` aliases to `/api/v1/network/pulse` for back-compat through v1.)

---

## 1. Wire conventions

### 1.1 Signed request format (POST /api/v1/actions/*)

Authentication uses **header-bound signatures with binary canonical bytes** — chosen so that Zig, TS, and Rust clients produce byte-identical signatures without depending on JSON canonicalization (a notorious source of cross-language bugs).

**Headers** (required on every signed action):

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |
| `X-API-Version` | `v1` |
| `X-Xb77-Pubkey` | hex(32B) — Ed25519 client pubkey |
| `X-Xb77-Timestamp` | decimal unix milliseconds |
| `X-Xb77-Nonce` | hex(12B) — random per-request |
| `X-Xb77-Signature` | hex(64B) — Ed25519 over canonical bytes |
| `X-Idempotency-Key` | (optional) UUID/opaque string, 24h dedup window |

**Body:** raw `payload_json` (the action-specific payload, not wrapped).

**Canonical bytes signed:**

```
action_byte (1B)  ‖  ts_be_u64_ms (8B)  ‖  nonce_bytes (12B)  ‖  payload_json (Nbytes)
```

| Byte | Meaning |
|---|---|
| `action_byte` | `0x01` submit_order, `0x02` register_agent, `0x03` claim_credits, `0x04` query_pulse |
| `ts_be_u64_ms` | timestamp in ms, big-endian u64 — must match `X-Xb77-Timestamp` |
| `nonce_bytes` | 12 raw bytes — hex-decoded from `X-Xb77-Nonce` |
| `payload_json` | request body verbatim (no canonicalization, no whitespace normalization) |

Server-side identity derivation: `agent_id = "ag_" + hex(sha256(pubkey)[:9])` — the agent never sends `agent_id`; the server computes it from the verified pubkey.

### 1.2 Response format

Successful response to a signed action:

```json
{
  "ok": true,
  "data": { /* endpoint-specific */ }
}
```

**Response signing headers** (always present on action responses):

| Header | Value |
|---|---|
| `X-Xb77-Gateway-Timestamp` | response unix milliseconds |
| `X-Xb77-Gateway-Signature` | hex(64B) — Ed25519 by gateway over response canonical |

Response canonical bytes:

```
action_byte (1B)  ‖  response_ts_be_u64_ms (8B)  ‖  response_body (Nbytes)
```

The gateway's pubkey is pinned in the SDK as `XB77_GATEWAY_PUBKEY` (hex 32B). Clients verify both the body integrity and that the response came from the genuine gateway.

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

Errors are also signed (same canonical scheme) so a tampered 4xx can't trick clients into retrying improperly.

### 1.3 Error codes (string enum)

| Code | HTTP | Meaning |
|---|---|---|
| `invalid_signature` | 401 | Signature didn't verify against `X-Xb77-Pubkey` |
| `invalid_nonce` | 401 | Nonce reused within the 5-min window |
| `clock_skew` | 401 | `ts` outside the ±30s window |
| `invalid_version` | 400 | `X-API-Version` missing or unsupported |
| `unknown_agent` | 404 | derived `agent_id` not registered |
| `rate_limited` | 429 | Per-agent or global limit hit (see §4) |
| `invalid_payload` | 400 | Action-specific validation failed |
| `insufficient_credits` | 402 | Action priced and agent's credit balance is too low |
| `internal` | 500 | Server bug — body includes `error_id` for traceability |

### 1.4 CORS

All endpoints respond with `Access-Control-Allow-Origin: *` (gateway is read-mostly and write paths are signed, so origin restriction adds no security and breaks the SDK pattern).

`Access-Control-Allow-Headers: Content-Type, X-API-Version, X-Xb77-Pubkey, X-Xb77-Timestamp, X-Xb77-Nonce, X-Xb77-Signature, X-Idempotency-Key`.

`Access-Control-Expose-Headers: X-Xb77-Gateway-Timestamp, X-Xb77-Gateway-Signature, X-RateLimit-Tier, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, X-RateLimit-Cost, Retry-After`.

`OPTIONS` preflight returns 204.

### 1.5 Wire schema versioning

The `/api/v1/` URL prefix locks the major version. The wire schema inside v1 is **1.1**:
- 1.0 (deprecated, SDK ≤1.0.x): canonical was `action(1) ‖ ts_be_u64_s (8) ‖ payload` — seconds, no nonce.
- 1.1 (current, SDK ≥1.1.0): adds `nonce` field and bumps ts to ms.

Server-side, the auth middleware rejects unversioned requests. Clients must send `X-API-Version: v1`. Schema variations are gated by the presence of `X-Xb77-Nonce` (1.1 if present, 1.0 if absent — 1.0 acceptance is feature-flagged and OFF by default in production).

---

## 2. Endpoints

### 2.1 Bootstrap (unauthenticated)

#### `POST /api/v1/actions/register_agent`

Create a new agent identity. **No signature required**, since the agent doesn't have one yet. Rate limited globally and per-IP (§4) to prevent fleet flooding.

**Request body:**
```json
{
  "pubkey": "hex(32B)",
  "intent_hint": "merchant" | "treasury" | "trader" | "indexer",
  "client_version": "@xb77/sdk@1.1.0"
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

The gateway derives `agent_id = "ag_" + hex(sha256(pubkey)[:9])`.

### 2.2 Signed actions

All require the §1.1 header-signed envelope. All return §1.2 signed response.

#### `POST /api/v1/actions/submit_order`

Submit a payment intent.

**Payload:**
```json
{
  "side": "buy" | "sell",
  "chain": "solana" | "base",
  "symbol": "USDC",
  "amount": 1000,
  "price": 10000
}
```

(Idempotency via `X-Idempotency-Key` header.)

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

These don't take a signed envelope. They return raw JSON without the response-signing headers (since the data is observable onchain anyway). Each endpoint applies a per-IP rate limit (§4).

#### `GET /api/v1/network/pulse`
Returns `{slot, blockHeight, agentsOnline, proofsVerified24h, ts}`.

#### `GET /api/v1/network/audit?tx=<hash>`
Returns audit verdict for a transaction.

#### `GET /api/v1/agents/fleet?limit=50&cursor=...`
List agents. Pagination via opaque cursor. Each entry:
```json
{
  "agent_id": "ag_a3f1c8d2...",
  "pubkey": "hex(32B)",
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
For v1 demo we keep this lax: agent_id in query, no auth, returns deterministic-mock-but-real-shaped data keyed by agent_id.
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

`POST` action endpoints accept an optional `X-Idempotency-Key` header. Within a 24h window, a repeat key returns the cached prior response with HTTP 200 (not 409) so retries are safe.

The key is **not** part of canonical signed bytes (it's operational metadata, not auth) — clients re-signing a retry don't need to recompute the signature if the payload bytes are identical, but they SHOULD generate a fresh nonce + ts (idempotency cache hits before nonce check fires).

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
- **Agent quarantine**: if a derived `agent_id` triggers `invalid_signature` 10 times in a row, quarantine for 5 minutes (`429 quarantined`).

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
- Wire schema within v1 follows §1.5. Server may accept multiple schema versions transparently; clients always send `X-API-Version: v1`.

---

## 7. What MUST be implemented in v1 (backend worktree)

Backend (in `feat/gateway-realdata`) ships these to satisfy this contract:

- [ ] `POST /api/v1/actions/register_agent` — generates agent_id, stores pubkey, returns tier free.
- [ ] `POST /api/v1/actions/submit_order` — verifies sig, applies rate limit, records to KV, returns order_id.
- [ ] `POST /api/v1/actions/claim_credits` — verifies sig + verifies the `proof_tx` exists (best-effort RPC call), updates tier.
- [ ] `POST /api/v1/actions/query_pulse` — same as GET but with signed envelope.
- [ ] `GET /api/v1/network/pulse` — existing.
- [ ] `GET /api/v1/network/audit` — existing.
- [ ] `GET /api/v1/agents/fleet` — query KV for live agents.
- [ ] `GET /api/v1/agents/:id` — single agent detail.
- [ ] `GET /api/v1/pipelines/recent` — KV-cached recent orders.
- [ ] `GET /api/v1/wallet/balances` — for v1: returns deterministic-mock-from-real-agent-id shape.
- [ ] `GET /api/v1/wallet/transactions` — same: deterministic-mock-by-id shape.
- [ ] Auth middleware: header sig verify + ts skew check + nonce replay (KV 5min TTL).
- [ ] Rate limit middleware: token bucket + headers per §4.
- [ ] Idempotency cache (KV with 24h TTL).
- [ ] Response signing (Ed25519, gateway secret in wrangler).
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
- [ ] Verify `X-Xb77-Gateway-Signature` on every action response against pinned `XB77_GATEWAY_PUBKEY`.

---

## 9. Mock-first development order

Frontend can progress without backend ready by pointing `XB77_GATEWAY` at the existing `sdk/ts/dev/mock-gateway.ts` which the SDK already ships. Backend implements against the contract independently.

Final swap: change `window.XB77_GATEWAY` in `index.html` / `app.html` to the real CF URL (or `http://127.0.0.1:8787` for the local worker).

---

## 10. Open questions deferred to v1.1+

- Per-merchant tenant isolation (multi-app on one gateway).
- WebSocket subscriptions instead of polling on `/network/pulse`.
- Server-side webhook callbacks for long-running orders.
- API key auth (in addition to per-request signing) for indexers.
- CAPTCHA gate for `register_agent`.
- Real onchain wallet queries (Helius RPC integration).

These ship after the hackathon clock dies.

---

## Appendix A — Canonical bytes reference implementation

```ts
function canonicalBytes(
  action: number,         // 0x01..0x04
  ts_ms: bigint,          // unix ms
  nonce: Uint8Array,      // 12 bytes
  payload: Uint8Array,    // request body bytes
): Uint8Array {
  const out = new Uint8Array(1 + 8 + 12 + payload.length);
  out[0] = action;
  for (let i = 0; i < 8; i++) out[1 + i] = Number((ts_ms >> BigInt((7 - i) * 8)) & 0xffn);
  out.set(nonce, 9);
  out.set(payload, 21);
  return out;
}
```

Equivalent Zig:
```zig
canonical[0] = @intFromEnum(action);
std.mem.writeInt(u64, canonical[1..9], ts_ms, .big);
@memcpy(canonical[9..21], &nonce);
@memcpy(canonical[21..], payload);
```

Any client implementation MUST produce byte-identical output for the same inputs.

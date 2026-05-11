# Data Infrastructure

The data layer behind the xB77 public webapp: a Cloudflare Worker adapter
that fronts the znode RPC, plus a JS client (`window.DataSource`) that
degrades invisibly when the network is unreachable.

This is what makes the `/network` page tick — slot, audit verdicts, agent
fleet and live pipeline feed all flow through this pair.

## Architecture

```
 ┌──────────────────┐    fetch     ┌──────────────────┐    JSON-RPC    ┌──────────────┐
 │ webapp           │ ───────────▶ │ CF Worker        │ ─────────────▶ │ znode        │
 │ (DataSource.js)  │ ◀─────────── │ (xb77-adapter)   │ ◀───────────── │ (Solana RPC) │
 └──────────────────┘   JSON+CORS  └──────────────────┘                 └──────────────┘
        │                                  │
        │ fallback                          │ fallback
        ▼                                  ▼
 ┌──────────────────┐               ┌──────────────────┐
 │ localStorage     │               │ deterministic    │
 │ (30s TTL cache)  │               │ mock generator   │
 └──────────────────┘               └──────────────────┘
        │
        ▼
 ┌──────────────────┐
 │ frozen snapshot  │
 │ (bundled in JS)  │
 └──────────────────┘
```

Three fallback layers in the client, one in the adapter. The webapp never
sees an error. The judge never sees a loader.

## Endpoints

All endpoints are `GET` and CORS-open. The base URL is `window.XB77_GATEWAY`
in the browser (default `http://127.0.0.1:8787` during dev).

| Path | Returns |
|------|---------|
| `/api/network/pulse` | `{slot, blockHeight, agentsOnline, proofsVerified24h, ts, _rpcLive}` |
| `/api/audit/:txhash` | `{verdict, proofId, agent, timestamp, chunks, txhash, _rpcLive}` |
| `/api/agents` | `{agents: Agent[]}` |
| `/api/pipelines/recent?n=5` | `{pipelines: Pipeline[]}` |
| `/api` | endpoint index (self-documenting) |

### `_rpcLive` field

Every payload carries `_rpcLive: boolean`. `true` means the adapter reached
the real Solana RPC; `false` means the response is internal mock data. The
**client** layer adds a second meta-field (`_source`) that reflects which
of `live | cached | snapshot` answered, regardless of `_rpcLive`.

### Audit verdict

The adapter first calls `getTransaction` on the configured RPC. If the
transaction is real, the response carries the actual `blockTime`. The
verdict itself is deterministic from the hash's last hex char so the same
input always returns the same verdict across reloads:

| Last char | Verdict |
|-----------|---------|
| `0`–`c`   | `VALID` |
| `d`, `e`  | `INVALID` |
| `f`       | `PENDING` |

## DataSource client

```js
window.DataSource.networkPulse(): Promise<Pulse>
window.DataSource.auditTx(hash):  Promise<Audit>
window.DataSource.agents():       Promise<{agents: Agent[]}>
window.DataSource.pipelinesRecent(n=5): Promise<{pipelines: Pipeline[]}>
window.DataSource.subscribe(name, cb, intervalMs): () => void
```

### Response envelope

Every response carries two extra fields the consumer can render directly:

```ts
type Envelope<T> = T & {
  _source: 'live' | 'cached' | 'snapshot';
  _ageMs:  number;   // millis since the underlying data was produced
};
```

Map `_source` to UI state:

| `_source` | UI signal |
|-----------|-----------|
| `live`     | green/lime dot, glow, no animation |
| `cached`   | magenta dot, pulse animation, label `// CACHED ${s}s` |
| `snapshot` | muted gray dot, label `// SNAPSHOT` |

### Fallback chain

Each method runs this resolver before returning:

1. **Live fetch** — `fetch(window.XB77_GATEWAY + path)` with a 2s timeout.
   On 200, cache the body in `localStorage` and return with `_source: 'live'`.
2. **Cached** — if live failed, read `localStorage`. If present, return
   with `_source: 'cached'` and `_ageMs = now − storedAt`. The 30s TTL is
   advisory: stale cache is still preferred over snapshot.
3. **Snapshot** — last resort. Frozen payload bundled inside `data-source.js`.
   `_source: 'snapshot'`, `_ageMs` measured from a fixed origin.

The client **never throws**. The worst case is a snapshot, which the user
sees as a labeled gray dot. No loaders, no error states, no broken UI.

### `subscribe(name, cb, intervalMs)`

Polling helper. `name` must be one of `networkPulse`, `agents`,
`pipelinesRecent` (no `auditTx` — that one is request/response).

```js
const off = window.DataSource.subscribe('networkPulse', (p) => {
  console.log(p.slot, p._source);
}, 3000);

// later
off();
```

Returns an unsubscribe function. The first call fires immediately; subsequent
ticks are scheduled `intervalMs` after the previous one finishes (not strict
interval — this avoids stacking when the network is slow).

## Type catalog

```ts
type Pulse = {
  slot: number;
  blockHeight: number;
  agentsOnline: number;
  proofsVerified24h: number;
  ts: number;             // ms epoch of the payload
};

type Audit = {
  verdict: 'VALID' | 'INVALID' | 'PENDING';
  proofId: string;        // "proof_<12 chars of hash>"
  agent: string;          // e.g. "omega-1"
  timestamp: number;      // ms epoch
  chunks: number;         // 6-10 typically
  txhash: string;
};

type Agent = {
  id: string;             // "alpha-7"
  pubkey: string;         // short form "ALPH...7zKq"
  status: 'online' | 'idle' | 'offline';
  pipelines: number;
  uptime: number;         // 0..1
};

type Pipeline = {
  id: string;
  agent: string;
  chunks: number;
  status: 'running' | 'verified' | 'failed';
  verdict: 'VALID' | 'INVALID' | null;
  startedAt: number;
  duration: number | null; // ms; null while running
};
```

## Deploying the adapter

The Worker lives at `gateway/worker/` (separate from the Zig-wasm
`gateway/worker.js` that handles the Sovereign Gateway dumb-pipe).

```bash
# Local dev
cd gateway/worker
bunx wrangler@latest dev

# Prod deploy (requires CF account)
bunx wrangler@latest deploy
```

Two env vars:

- `ZNODE_RPC_URL` — Solana RPC endpoint. Dev default `http://127.0.0.1:8899`;
  prod target `https://znode.xb77.dev` once the on-chain merge lands.
- `ALLOWED_ORIGIN` — CORS origin. `*` for hackathon; tighten for prod.

## Trying it locally

```bash
# 1. spin up the validator (assumes podman setup exists)
podman ps | grep solana-test-validator

# 2. start the adapter
cd gateway/worker && bunx wrangler@latest dev
curl http://localhost:8787/api/network/pulse
# expected: real slot from the validator

# 3. serve the webapp
cd webapp_deploy && ./build.sh
bunx wrangler@latest pages dev . --port 8788
# open: http://127.0.0.1:8788/#network
```

In DevTools, on the `/network` page:

```js
// live
await window.DataSource.networkPulse();
// → { ..., _source: 'live', _ageMs: 0 }

// kill the adapter (ctrl+C in its terminal), then:
await window.DataSource.networkPulse();
// → { ..., _source: 'cached', _ageMs: ~3000 }
// the page itself stays running, dot turns magenta
```

## Design notes

**Why a separate adapter instead of hitting znode directly?**
Browser → Solana RPC is awkward (CORS, rate limits, no shaping). The adapter
gives one place to add caching, observability, and the deterministic mock
fallback that makes the demo bulletproof.

**Why three layers of fallback?**
- `live → cached` covers transient network blips (1–30s).
- `cached → snapshot` covers cold-start scenarios where there's nothing in
  `localStorage` yet (first visit, incognito, cleared storage).
- The deterministic mock inside the *adapter* covers the case where the
  adapter is up but the RPC is down — judges still see numbers move because
  the mock advances `slot` by `(now - t0) / 400` ms.

**Why a `_rpcLive` field?**
Lets the UI distinguish "we got real RPC data" from "the adapter mocked it"
without changing the contract. Today the UI doesn't render this, but it's
there for an eventual badge ("RPC: live" / "RPC: mock").

# W3 `data-infra` — Contratos exportados

> Lo que los otros worktrees (W1 tabs/explorer, W2 signatures) consumen
> de este worktree. Mientras W3 no mergea, los demás deben **stub-ear**
> `window.DataSource` con un objeto inline que devuelva los snapshots
> que están más abajo. Al mergear, sus stubs desaparecen.

---

## 1. `window.DataSource` (cliente JS)

Globalmente disponible una vez cargado `assets/js/lib/data-source.js`.
**Nunca throws**, nunca surfacea error al consumidor. Cada respuesta lleva
metadatos `_source` ∈ `'live' | 'cached' | 'snapshot'` y `_ageMs`.

### `networkPulse(): Promise<Pulse>`

```ts
type Pulse = {
  slot: number;
  blockHeight: number;
  agentsOnline: number;
  proofsVerified24h: number;
  ts: number;             // ms epoch del payload
  _source: 'live' | 'cached' | 'snapshot';
  _ageMs: number;
};
```

### `auditTx(hash: string): Promise<Audit>`

```ts
type Audit = {
  verdict: 'VALID' | 'INVALID' | 'PENDING';
  proofId: string;        // "proof_<12 chars hash>"
  agent: string;          // e.g. "omega-1"
  timestamp: number;      // ms epoch
  chunks: number;         // 6-10 típicamente
  txhash: string;
  _source: 'live' | 'cached' | 'snapshot';
  _ageMs: number;
};
```

Si `hash` es vacío, devuelve snapshot inmediatamente (no llama al gateway).

### `agents(): Promise<AgentsResp>`

```ts
type Agent = {
  id: string;             // "alpha-7"
  pubkey: string;         // short form "ALPH...7zKq"
  status: 'online' | 'idle' | 'offline';
  pipelines: number;
  uptime: number;         // 0..1
};
type AgentsResp = {
  agents: Agent[];
  _source: 'live' | 'cached' | 'snapshot';
  _ageMs: number;
};
```

### `pipelinesRecent(n?: number = 5): Promise<PipelinesResp>`

```ts
type Pipeline = {
  id: string;
  agent: string;
  chunks: number;
  status: 'running' | 'verified' | 'failed';
  verdict: 'VALID' | 'INVALID' | null;
  startedAt: number;      // ms epoch
  duration: number | null; // ms; null si status==='running'
};
type PipelinesResp = {
  pipelines: Pipeline[];
  _source: 'live' | 'cached' | 'snapshot';
  _ageMs: number;
};
```

Clampea `n` a `[1, 50]`.

### `subscribe(name, cb, intervalMs): () => void`

Polling helper. `name` debe ser uno de `'networkPulse'|'agents'|'pipelinesRecent'`
(no `'auditTx'` — ese se llama on-demand).

```js
const off = window.DataSource.subscribe('networkPulse', (p) => {
  console.log(p.slot, p._source);
}, 3000);
// más tarde: off();
```

---

## 2. Endpoints REST (gateway adapter)

Base URL: `window.XB77_GATEWAY` (default `http://127.0.0.1:8787` en dev).

| Método | Path                          | Respuesta                                      |
|--------|-------------------------------|------------------------------------------------|
| GET    | `/api/network/pulse`          | `{slot, blockHeight, agentsOnline, proofsVerified24h, ts, _rpcLive}` |
| GET    | `/api/audit/:txhash`          | `{verdict, proofId, agent, timestamp, chunks, txhash, _rpcLive}` |
| GET    | `/api/agents`                 | `{agents: Agent[]}`                            |
| GET    | `/api/pipelines/recent?n=5`   | `{pipelines: Pipeline[]}`                      |

Headers CORS: `access-control-allow-origin: *`, `access-control-allow-methods: GET, OPTIONS`.

Env vars del Worker:
- `ZNODE_RPC_URL` — RPC del znode (dev: `http://127.0.0.1:8899`, prod: `https://znode.xb77.dev`)
- `ALLOWED_ORIGIN` — origin CORS (`*` por defecto)

El Worker prueba el RPC real con timeout de 1500ms. Si falla, devuelve mock
determinístico (slot/blockHeight derivados de `Date.now()`). El campo
`_rpcLive` indica si la respuesta viene del RPC real o del mock interno.

---

## 3. Página `/network` (hash route)

Componente global `window.NetworkPage`. **El router (W1) debe agregar**
al mergear:

```js
// router.jsx — map
'#network': 'network',
// y en el switch:
case 'network': return <NetworkPage />;
```

Sin ese wiring, el componente sigue cargado y accesible vía
`window.NetworkPage` para integración manual, pero no se renderiza por
hash.

---

## 4. Stub recomendado para W1/W2 (pre-merge)

Mientras W3 no mergea, en los worktrees consumidores:

```js
// stub-data-source.js — borrar al mergear W3
window.DataSource = {
  networkPulse: () => Promise.resolve({
    slot: 250412311, blockHeight: 250411104,
    agentsOnline: 5, proofsVerified24h: 1247,
    ts: Date.now(), _source: 'snapshot', _ageMs: 0,
  }),
  auditTx: (h) => Promise.resolve({
    verdict: 'VALID', proofId: 'proof_' + (h || '').slice(0,12),
    agent: 'omega-1', timestamp: Date.now(), chunks: 8,
    txhash: h, _source: 'snapshot', _ageMs: 0,
  }),
  agents: () => Promise.resolve({
    agents: [/* mismos 5 IDs: alpha-7, delta-3, omega-1, sigma-9, kappa-4 */],
    _source: 'snapshot', _ageMs: 0,
  }),
  pipelinesRecent: (n=5) => Promise.resolve({
    pipelines: [/* mock */], _source: 'snapshot', _ageMs: 0,
  }),
  subscribe: (name, cb, ms) => {
    const t = setInterval(() => window.DataSource[name]().then(cb), ms);
    window.DataSource[name]().then(cb);
    return () => clearInterval(t);
  },
};
```

---

## 5. Cambios futuros (no break)

- `_source` / `_ageMs` siempre presentes — no se renombran.
- Si un endpoint agrega campos nuevos, los consumidores deben ignorar
  campos desconocidos (forward-compatible).
- El switch dev/prod del `ZNODE_RPC_URL` no afecta el contrato: el cliente
  no ve esa env var.

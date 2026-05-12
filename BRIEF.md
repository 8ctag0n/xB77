# 🔌 Worktree W3 — `data-infra`

> **Misión**: Levantar el adapter CF Worker que la webapp consume, el cliente JS con degradation invisible, y la página `/network` que muestra Pulse en vivo + Ghost Audit Portal. **Esto es lo que hace que un judge diga "ah, es real"**.

## Coordenadas

- **Branch**: `feat/data-infra`
- **Worktree path**: `/home/exp1/Desktop/xB77/worktree/data-infra`
- **Base**: `feat/docs-vitepress` (incluye spec commit `d0a11e6`)
- **Spec completo**: `docs/superpowers/specs/2026-05-11-plan-maestro-deluxe-design.md` (secciones 5, 12)

## Files owned (EXCLUSIVO)

- `gateway/worker/` (NUEVO directorio)
  - `wrangler.toml`, `package.json`, `src/index.js`
- `webapp_deploy/assets/src/lib/data-source.js` (NUEVO, JS plano)
- `webapp_deploy/assets/src/page-network.jsx` (NUEVO)
- `webapp_deploy/build.sh` (solo si necesitás extender para copiar `lib/`)
- `webapp_deploy/index.html` — UNA línea para cargar `data-source.js` y setear `window.XB77_GATEWAY` (coordinar con setup)

## Files PROHIBIDOS

- Cualquier `dapp-*`, `explorer-*`, `app-tabs.jsx`, `router.jsx` (W1)
- Cualquier `home-*`, `landing-*`, `signatures/*`, `page-why.jsx` (W2)

## Deliverables

### 1. CF Worker (`gateway/worker/`)

4 endpoints REST con CORS:
- `GET /api/network/pulse` → `{slot, blockHeight, agentsOnline, proofsVerified24h, ts}`
- `GET /api/audit/:txhash` → `{verdict, proofId, agent, timestamp, chunks}`
- `GET /api/agents` → `{agents: [...]}`
- `GET /api/pipelines/recent` → `{pipelines: [...]}`

Env var `ZNODE_RPC_URL` para switch dev (localhost:8899) / prod (znode.xb77.dev cuando merge-onchain mergee).

### 2. Cliente `data-source.js`

Global `window.DataSource` con:
- `networkPulse()`, `auditTx(h)`, `agents()`, `pipelinesRecent(n)`
- Fallback chain: **live fetch → localStorage cached (TTL 30s) → frozen SNAPSHOT hardcoded**
- Cada respuesta lleva `_source: 'live'|'cached'|'snapshot'` y `_ageMs`
- `subscribe(endpoint, cb, intervalMs)` helper para polling
- **NUNCA throws al consumidor**, NUNCA muestra error

### 3. Página `/network`

- **Network Pulse Section**: 4 big numbers (slot, blockHeight, agentsOnline, proofsVerified24h), subscribe cada 3s, dot status `// LIVE` (lime) / `// CACHED Xs` (magenta blink) / `// SNAPSHOT` (muted)
- **Ghost Audit Section**: input tx hash + botón AUDIT + result card con verdict (lime=VALID / magenta=INVALID / cyan=PENDING), proof ID, agent, timestamp, chunks

## Contratos

Lo que exportás está documentado en `CONTRACTS.md` (será creado en setup). Otros worktrees consumen:
- W2 architecture usa `window.DataSource.networkPulse()` para alimentar `<ZKPipelineVisualizer liveData>`
- W1 tabs eventualmente usan `window.DataSource.agents()` y `pipelinesRecent()`

**Importante**: mientras W3 no haya commiteado, los otros stub-ean el `DataSource` con un objeto que devuelve snapshot inline. Cuando hagas merge, sus stubs desaparecen.

## Cómo verificar

### Worker local

```bash
# Asegurar que el validador podman esté arriba
podman ps | grep solana-test-validator

# Levantar worker
cd /home/exp1/Desktop/xB77/worktree/data-infra/gateway/worker
bunx wrangler@latest dev

# En otra terminal
curl http://localhost:8787/api/network/pulse
# Expected: JSON con slot y blockHeight reales
```

### Cliente + degradation

```bash
cd /home/exp1/Desktop/xB77/worktree/data-infra/webapp_deploy
./build.sh
bunx wrangler@latest pages dev . --port 8788
```

DevTools console:
```js
await window.DataSource.networkPulse()      // _source: 'live'
// Matá el worker (Ctrl+C en su terminal)
await window.DataSource.networkPulse()      // _source: 'cached' o 'snapshot', NO throw
```

Visual: `#network` carga, números se ven, dot status cambia color según `_source`.

## Cómo commitear

```
feat(gateway): CF Worker adapter con 4 endpoints REST
feat(data): client data-source.js con fallback chain
feat(network): /network page con Pulse + Ghost Audit
```

## Handoff

Cuando termines, NO mergees — avisame y yo hago el merge ordenado desde `docs-v2`. **W3 mergea PRIMERO** (más independiente, menos chance de conflicto).

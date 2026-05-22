# 🎯 Worktree W1 — `app-deluxe`

> **Misión**: Fusionar las páginas `/dapp` (rota) y `/explorer` (deluxe) en una sola superficie `/app` con tabs coherentes, reutilizando los componentes ya bellos del Explorer.

## Coordenadas

- **Branch**: `feat/app-deluxe`
- **Worktree path**: `/home/exp1/Desktop/xB77/worktree/app-deluxe`
- **Base**: `feat/docs-vitepress` (incluye spec commit `d0a11e6`)
- **Spec completo**: `docs/superpowers/specs/2026-05-11-plan-maestro-deluxe-design.md` (secciones 3, 7)

## Files owned (EXCLUSIVO — solo tocás esto)

- `webapp_deploy/assets/src/dapp-*.jsx` (todos)
- `webapp_deploy/assets/src/explorer-*.jsx` (todos)
- `webapp_deploy/assets/src/app-tabs.jsx` (NUEVO)
- `webapp_deploy/assets/src/router.jsx` (solo el bloque que matchea `#app`/`#dapp`/`#explorer`)

## Files PROHIBIDOS (otros worktrees los tocan)

- `webapp_deploy/index.html` (tokens/keyframes los toca W2)
- `webapp_deploy/assets/src/home-*.jsx`, `landing-*.jsx`, `page-why.jsx`, `signatures/*` (W2)
- `gateway/worker/`, `webapp_deploy/assets/src/lib/`, `page-network.jsx` (W3)

## Deliverable

Página `/app` accesible como `#app/wallet`, `#app/agents`, `#app/pipelines`, `#app/mesh`, `#app/explorer`. Cada tab:

- Reusa componentes del Explorer (`StatCard`, `Row`, `Sparkline`, `MeshCanvas`, `Status`, `SearchBar`, `Tabs`, `Pager`, `FilterChip`) — **no inventes UI propia**
- Mantiene la misma jerarquía/density/contraste que el Explorer actual
- Cada tab exporta `window.<Nombre>Tab` que el shell consume

## Contratos a respetar

Lee `webapp_deploy/assets/src/CONTRACTS.md` apenas el worktree de setup haya commiteado eso. Mientras tanto, **stub local** lo que necesites de W2/W3:

```js
// stubs si CONTRACTS.md aún no existe
window.AgentBadge = window.AgentBadge || (({pubkey}) => <span style={{fontFamily:'var(--mono)'}}>{pubkey?.slice(0,4)}…{pubkey?.slice(-4)}</span>);
window.DataSource = window.DataSource || { agents: async () => ({ agents: [], _source:'snapshot' }) };
```

## Cómo verificar (smoke test)

```bash
cd /home/exp1/Desktop/xB77/worktree/app-deluxe/webapp_deploy
./build.sh
bunx wrangler@latest pages dev . --port 8788
# Visitar #app/wallet, #app/agents, #app/pipelines, #app/mesh, #app/explorer
```

Cada tab debe cargar sin errores en consola y verse coherente con el Explorer original.

## Cómo commitear

Commits granulares por tab (uno por refactor de cada `dapp-*.jsx`), commit final del shell `app-tabs.jsx` + router. Mensaje final tipo:

```
feat(app): fusiona /dapp + /explorer en /app con tabs coherentes
```

## Handoff

Cuando termines, NO mergees — avisame y yo hago el merge ordenado (W3 → W2 → W1) desde `docs-v2`.

## Tareas paso-a-paso

Ver Fase 1A del plan completo si lo tenés (puede vivir untracked en `docs-v2/docs/superpowers/plans/`). Resumen:

1. **W1.1** Crear shell `app-tabs.jsx` con 5 tabs + hash routing `#app/<tab>`
2. **W1.2** Auditar Explorer reusables → refactorizar cada `dapp-*.jsx` para que reuse + exporte `window.<Nombre>Tab`
3. **W1.3** Extraer `ExplorerTab` de `explorer-sections.jsx`
4. **W1.4** Actualizar `router.jsx` para que `#app` y `#app/*` rendericen `window._AppView`
5. **W1.5** Smoke test + commit

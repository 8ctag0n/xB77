# BRIEF W3 — Multichain (worktrees) ‖ Sui Deluxe

> Handoff para dos sesiones en paralelo. Fecha: 2026-05-22 · Base: `agora-arc`.
> Red de seguridad: tag `pre-refactor-2026-05-22` (revierte TODO el refactor de repo).

---

## 0. Estado actual (base `agora-arc`, todo verificado)

- **Refactor de repo completo** (Fases 0–3): `apps/` = ejecutables (cli, znode, gateway,
  mcp, services, web, sui-bridge) · `onchain/` = por cadena (solana/evm/sui/stylus/…) ·
  `sdk/` = rs/ts/wasm/zig. Verificado: `zig build`, `forge build` verdes.
- **Docs multichain** (Rama A, ya mergeada): núcleo chain-agnostic + adaptadores de
  settlement; `docs/roadmap.md` nuevo; metas/nav actualizados. `vitepress build` verde.
- **Webapp reparado:** `page-network.jsx` (build roto por duplicación) arreglado +
  **`SuiPulseSection` scaffold** que lee `window.DataSource.subscribe('suiPulse', …)`.
- **Statusline deluxe** (`~/.claude/statusline.sh`): modelo · proyecto · rama · contexto
  (1M/200k auto) · líneas.
- **Pendiente:** Rama B (webapp multichain) y Rama C (README honestidad). Planes en
  `notes/plans/branch-{B,C}-*.md` y `notes/MULTICHAIN-DOCS-PLAN.md`.

---

## 1. Track 1 — NUEVA sesión · worktrees multichain

Objetivo: terminar el reframe multichain en webapp + README, en worktrees aislados.

```bash
# desde el repo, base agora-arc
git worktree add ../xB77-webapp -b feat/webapp-multichain agora-arc
git worktree add ../xB77-readme -b feat/readme-honesty   agora-arc
```

- **Rama B — webapp** (`feat/webapp-multichain`) → plan: `notes/plans/branch-B-webapp-multichain.md`
  - Edita `apps/web/assets/src/page-*.jsx` + `apps/web/index.html` (4 metas).
  - ⚠️ Workflow: editar `.jsx`, correr `cd apps/web && ./build.sh`, commitear src + js.
  - Verif: `./build.sh` exit 0 · `grep "on Solana" index.html page-*.jsx` → 0.
- **Rama C — README** (`feat/readme-honesty`) → plan: `notes/plans/branch-C-readme-honesty.md`
  - `README.md` tagline/badges multichain + pasada de honestidad.
  - OJO: las editions ya viven en `docs/editions/{arc,sui}.md` (los links del README ya apuntan ahí).

Mergear B y C a `agora-arc` (ff o PR) cuando estén verdes.

---

## 2. Track 2 — sesión activa · Sui Deluxe

Objetivo: pulir TODO Sui para que quede deluxe. Áreas:

- `onchain/sui/` — package Move `sovereign` (Treasury/Policy/Receipt). `Move.toml` sin
  paths locales; `Pub.localnet.toml` es efímero (gitignored).
- `apps/sui-bridge/` — bridge con PTBs reales (@mysten/sui 1.45, tsx).
- `services/` si aplica al flujo Sui.
- **Alimentar el feed `suiPulse`** para que `SuiPulseSection` (en `apps/web`) muestre datos
  reales: campos esperados `objectsTotal`, `treasuryBalance`, `ptbCount`, `lastDigest`.

Memorias relevantes: [[sui-port-9100]] (Sui en :9100), [[sui-deluxe-bridge]] (package +
PTBs), [[zk-verifier-localnet]].

---

## 3. ⚠️ Frontera de propiedad (para NO colisionar)

`apps/web/` lo tocan AMBOS tracks → acuerdo explícito:

| Zona | Dueño | Regla |
|---|---|---|
| `apps/web/assets/src/page-*.jsx` (copy/mensaje) | **Track 1 / Rama B** | reframe multichain de texto |
| `SuiPulseSection` internals + `lib/data-source.js` + `explorer-mock-data*` (feed `suiPulse`) | **Track 2 / Sui** | datos reales del pulse |
| `page-network.jsx` | compartido | B **no** toca `SuiPulseSection`; Sui **no** toca el copy de otras secciones |
| `docs/`, `README.md` | **Track 1** | — |
| `onchain/sui/`, `apps/sui-bridge/` | **Track 2** | — |

Si ambos necesitan `page-network.jsx`, coordinar por commits chicos y rebase frecuente
sobre `agora-arc`.

---

## 4. Verificación (por área)

```bash
zig build && zig build wasm && zig build test     # core/cli/znode/gateway/sdk
( cd onchain/evm && forge build )                 # EVM
( cd onchain/sui && sui move build )              # Sui (necesita red)
( cd docs && bun run docs:build )                 # VitePress
( cd apps/web && ./build.sh )                     # webapp (esbuild)
```

## 5. Red de seguridad

```bash
git checkout pre-refactor-2026-05-22       # inspeccionar estado pre-refactor
git reset --hard pre-refactor-2026-05-22   # revertir TODO el refactor (destructivo)
```

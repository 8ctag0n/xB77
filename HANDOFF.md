# Handoff — Docs v2 con VitePress

> **Quién leas esto**: estás en el worktree `docs-v2` (branch `feat/docs-vitepress`).
> El otro worktree (`fix-onchain-battle`) está laburando en infra (deploy a Fly,
> Cloudflare Workers, programas a devnet) en paralelo. **No tocar nada de
> `.github/workflows/`, `infra/`, `fly.toml`, `wrangler.toml` desde acá** — esos
> los maneja el otro branch.

---

## Objetivo

Armar un sitio de documentación técnica con **VitePress** que viva en `docs-site/`
(o el nombre que se acuerde), separado de `docs/index.html` (que sigue siendo la
landing cyberpunk hand-crafted).

**URL final esperada**: `docs.xb77.io` o `xb77.io/docs/` (subpath del worker o
Pages aparte).

---

## Decisiones de diseño previas

* **Landing** (`docs/index.html`) **NO se toca**. Estética cyberpunk, hand-crafted,
  es identidad de marca. Sigue desplegándose vía `.github/workflows/deploy-docs.yml`.
* **Docs v2** es un sitio nuevo, separado, en su propia carpeta.
* **VitePress** elegido porque: dark mode out-of-box, búsqueda local con Shiki,
  sidebar autogenerado de markdown, deploy a Pages en una línea, MD + Vue
  components cuando hace falta interactividad.
* Estética: por confirmar con el user (dos opciones a discutir):
  - **A)** Coherente con landing — accent `#c8ff2e`, bg `#08080a`, mono JetBrains.
  - **B)** Tema "docs clásico" — claro/legible, blanco predominante (mejor para
    referencias largas).

---

## Material a ingestar (markdowns existentes en el repo)

Ya en `main` (commit `d332304`):

* `DEPLOY.md` — walkthrough end-to-end (wallet → programs → worker → fly)
* `BRIEF_2026-05-10.md` — estado del pipeline ZK
* `docs/DEMO_FRONTIER.md` — script de demo
* `docs/SESSION_BRIEF.md` — brief operativo
* `docs/planning/FRONTIER_SPRINT.md`
* `docs/planning/HACKATHON_STRATEGY.md`
* `docs/planning/WEEK_PLAN_S7.md`
* `docs/planning/WEEK_PLAN_S8.md`
* `docs/planning/ZDK_REWIRE.md`
* `docs/superpowers/specs/2026-05-01-xb77-product-ready-design.md`
* `README.md` (raíz)

---

## Estructura propuesta para `docs-site/`

```
docs-site/
├─ .vitepress/
│  ├─ config.ts             # nav, sidebar, theme overrides
│  └─ theme/
│     ├─ index.ts
│     └─ custom.css         # accent color, fonts si vamos opción A
├─ index.md                 # home del sitio docs (no la landing)
├─ guide/
│  ├─ deploy.md             # adaptación de DEPLOY.md
│  ├─ wallet.md             # spin-off del paso 2 de DEPLOY
│  ├─ programs.md           # paso 3
│  ├─ worker.md             # paso 4
│  └─ agent.md              # paso 5
├─ reference/
│  ├─ programs.md           # IDs onchain + interfaces
│  ├─ rpc.md                # endpoints, request/response examples
│  └─ events.md             # eventos que znode emite
├─ plans/
│  └─ ...                   # docs/planning/* movidos acá
└─ public/                  # assets estáticos (logos, diagramas)
```

## Pasos sugeridos (orden)

1. **Init VitePress** dentro de `docs-site/` con bun:
   ```bash
   mkdir docs-site && cd docs-site
   bun init -y
   bun add -D vitepress
   bunx vitepress init .   # responde: docs-site/, root: ., theme: default
   ```

2. **Configurar `.vitepress/config.ts`**: title, description, nav, sidebar
   estructurado por las secciones (Guide / Reference / Plans).

3. **Migrar markdowns** uno por uno desde la lista de "material a ingestar".
   Adaptar paths internos (links a archivos del repo) → links absolutos a GitHub
   o eliminar referencias internas.

4. **Custom theme** (decidir A vs B con el user antes):
   - Opción A: override CSS variables `--vp-c-brand-*` con `#c8ff2e` y `#08080a`,
     sumar JetBrains Mono como `--vp-font-family-mono`.
   - Opción B: dejar default + un toque de marca en el navbar.

5. **Build local**: `bunx vitepress build` → produce `docs-site/.vitepress/dist/`.

6. **Deploy**: tres opciones (decidir con el user):
   - **Cloudflare Pages**: project nuevo, root dir `docs-site`, build
     `bunx vitepress build`, output `docs-site/.vitepress/dist`.
   - **GitHub Pages**: workflow nuevo `.github/workflows/deploy-docs-v2.yml`
     (no tocar el existente `deploy-docs.yml`, sigue sirviendo la landing).
   - **Subpath del Worker**: complicado, evitar.

---

## No-goals (esta tanda)

* No modificar la landing (`docs/index.html`).
* No tocar workflows existentes (`build.yml`, `release.yml`, `deploy-worker.yml`,
  `deploy-docs.yml`, `infra-images.yml`).
* No mergear a `main` hasta que el user apruebe la estética y el contenido.

---

## Coordinación con el otro worktree

* El otro está en `fix-onchain-battle` (branch `fix/ci-libcurl-rustup`).
* Cuando el user pushee `v0.2.3-deluxe`, esos commits aterrizan en `main`.
* Si necesitás los archivos nuevos (`DEPLOY.md`, `wrangler.toml`, etc.) acá:
  ```bash
  git fetch origin main
  git rebase origin/main      # o merge, decidir con el user
  ```
* Conflictos esperables: 0. El otro worktree no toca nada bajo `docs-site/`.

---

## Preguntas para el user al arrancar

1. **Estética A vs B** (cyberpunk coherente con landing vs docs clásico legible).
2. **Nombre del sitio** ("xB77 Docs" / "xB77 Manual" / etc.).
3. **Dominio final** (`docs.xb77.io`, `xb77.io/docs/`, o solo `*.pages.dev`).
4. **Ingestar todo el material o filtrar**: ¿los `WEEK_PLAN_S*` y `HACKATHON_STRATEGY`
   son docs públicos o internos? Si internos, no van.

---

_Generado en sesión paralela del worktree `fix-onchain-battle`. El otro worktree
ya tiene las cosas de infra arregladas; este es para concentrarse en docs._

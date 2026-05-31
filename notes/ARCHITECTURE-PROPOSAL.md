# Propuesta de Arquitectura del Repo — xB77

> Estado: **borrador / diagnóstico** · Fecha: 2026-05-22 · No mueve ningún archivo.
> Objetivo: que la estructura del repo comunique el modelo mental del sistema, sin
> reescribir código. Solo reubicación + consolidación, por fases reversibles.
>
> **Decisiones tomadas:**
> - `___legacy/` **se queda intacto** (no se borra). Sigue tracked; solo ocupa una línea en el árbol.
> - **No ejecutar todavía**: hay trabajo en paralelo. Mover archivos ahora generaría conflictos de
>   merge y rompería paths/imports. Este doc es el plan a aplicar cuando se libere el momento.

---

## 1. Mapa actual (lo que hay hoy)

xB77 es un **monorepo políglota**. Lenguajes y dónde viven:

| Lenguaje | Rol | Ubicación actual |
|----------|-----|------------------|
| **Zig** | Kernel / OS / CLI / node | `core/` (68 .zig en 14 módulos), `cli/` (19), `znode/`, `mcp/`, `sdk/*.zig` |
| **Rust** | Programas Solana + ZK judge | `onchain/programs/*` (Anchor), `sdk/rs/`, `circuits/*/verifier_program/` |
| **Solidity** | Contratos EVM (Arc/Base) | `apps/contracts/arc/` |
| **Move** | Contratos Sui | `apps/move-packages/sovereign/` |
| **Noir** | Circuitos ZK | `circuits/*/src/*.nr` |
| **TypeScript** | Bridges / services / gateway / SDK | `sdk/ts/`, `services/`, `gateway/worker/`, `apps/sui-bridge/` |
| **Web** | Sitio desplegado | `webapp_deploy/`, `docs/` (VitePress) |

Build orquestado por **tres** sistemas a la vez: `build.zig` (steps: `run`, `wasm`,
`sdk-wasm`, `merchant-wasm`, `trident-smoke`, `test`), `Makefile` (localnet/deploy/demo)
y `Makefile.native`.

---

## 2. Diagnóstico — por qué se siente caótico

El problema **no es el tamaño**, es que la jerarquía no refleja el modelo mental.
Cuatro fricciones concretas:

### F1 — `apps/` no contiene las apps
Hoy `apps/` solo tiene contratos de cadena (`contracts/arc`, `move-packages`, `sui-bridge`).
Las apps reales (`cli/`, `gateway/`, `znode/`, `services/`, `webapp_deploy/`, `mcp/`)
cuelgan de la raíz. Un dev nuevo abre `apps/` y no encuentra ninguna app.

### F2 — El código de cadena está disperso en 4+ sitios
- `onchain/programs/` → Solana (xb77_core, _gateway, _registry, _compression, _zk_verifier, _test_utils)
- `apps/contracts/arc/` → EVM/Solidity
- `apps/move-packages/sovereign/` → Sui Move
- `onchain/stylus_constitution/` → Arbitrum Stylus
- `core/onchain/` (5 .zig) + `core/chain/` (8 .zig) → lógica de cadena en el kernel

No hay un único "acá vive todo lo onchain, organizado por cadena".

### F3 — El SDK está fragmentado y sin canónico claro
Conviven: `sdk/rs/`, `sdk/ts/`, `sdk/wasm/`, **y además** `sdk/src/` (TS suelto:
`awp.ts`, `client.ts`) y `sdk/*.zig` (`merchant_sdk.zig`, `xb77_sdk.zig`) directamente
en la raíz de `sdk/`. No se distingue cuál es el punto de entrada oficial.

### F4 — Ruido en la raíz
- ~15 markdown sueltos: `BRIEF.md`, `BRIEF.W1.md`, `BRIEF-W2-signatures.md`, `DEMO.md`,
  `DEMO-MEGA.md`, `DEPLOY.md`, `CONTRACTS.md`, `QUICKSTART.md`, `HANDOFF-NEXT-SESSION.md`,
  `AGORA_APPLICATION_TEXT.md`, `DOCS-LOCAL-DEV.md` + **3 READMEs** (`README.md`,
  `README-ARC.md`, `README-SUI.md`).
- `___legacy/` (22M) — marcado en `.gitignore` como "tracked a propósito".
  **Decisión: se deja como está**, no se borra en esta reorg.
- Scratch dirs en working tree: `.xb77`, `.xb77_client`, `.xb77_provider`.

> **No es problema:** los 4.4G de `.localnet-ledger`, `zig-out` (300M), `.zig-cache`
> (288M), `dist/`, `.wrangler/` ya están gitignored. Solo ensucian tu working tree
> local, no el repo.

---

## 3. Estructura objetivo

Principio: **una carpeta = un concepto**, agrupado por dominio (no por lenguaje cuando
el dominio es claro). Tres capas: `apps/` (lo que se ejecuta), `onchain/` (lo que se
despliega en cadena), `core/` + `sdk/` (las librerías).

```
xB77/
├── apps/                  # TODO lo que es un binario/servicio ejecutable
│   ├── cli/               # (ex cli/)        Zig
│   ├── znode/             # (ex znode/)      Zig node
│   ├── gateway/           # (ex gateway/)    TS/WASM Cloudflare Worker
│   ├── mcp/               # (ex mcp/)        Zig MCP server
│   ├── services/          # (ex services/)   magicblock, qvac_brain, sns (TS)
│   ├── sui-bridge/        # (ex apps/sui-bridge/) — ya está bien
│   └── web/               # (ex webapp_deploy/) sitio desplegado
│
├── onchain/               # TODO lo que se despliega en cadena, por cadena
│   ├── solana/            # (ex onchain/programs/) programas Anchor
│   ├── evm/               # (ex apps/contracts/arc/)
│   ├── sui/               # (ex apps/move-packages/sovereign/)
│   ├── stylus/            # (ex onchain/stylus_constitution/)
│   ├── circuits/          # (ex circuits/) Noir + verifier programs
│   ├── idls/              # (ex idls/)
│   └── clients/           # (ex onchain/clients/)
│
├── core/                  # Kernel Zig (sin cambios internos; ver nota F2)
│
├── sdk/                   # UN punto de entrada por target
│   ├── rs/                # Rust SDK
│   ├── ts/                # TS SDK (absorbe sdk/src/*.ts)
│   ├── wasm/              # WASM exports
│   └── zig/               # (ex sdk/*.zig sueltos)
│
├── docs/                  # TODA la documentación
│   ├── briefs/            # BRIEF*.md, HANDOFF*.md
│   ├── demo/              # DEMO*.md
│   ├── deploy/            # DEPLOY.md, CONTRACTS.md
│   └── ...                # (lo que ya existe: guide, reference, specs, v1)
│
├── infra/                 # (ex infra/) + Makefiles de orquestación
├── scripts/               # (sin cambios)
├── deps/                  # submódulos / vendored
│
├── README.md              # único, apunta a docs/ para lo demás
├── build.zig              # un solo entrypoint de build (ver Fase 4)
└── Makefile               # orquestador raíz que llama a cada toolchain
```

`___legacy/` → **se mantiene intacto** en la raíz (decisión tomada; no se borra).

---

## 4. Plan de migración por fases (cada fase = 1 PR reversible)

> ⚠️ **Congelado por ahora.** Hay trabajo en paralelo en el repo; ejecutar cualquier
> fase con `git mv` ahora generaría conflictos de merge. Aplicar cuando se libere
> una ventana sin otros cambios en vuelo.

### Fase 0 — Limpieza sin riesgo `[~30 min, 0 cambios de código]`
- Mover los ~15 `.md` de raíz a `docs/{briefs,demo,deploy}/`.
- Consolidar `README-ARC.md` y `README-SUI.md` como secciones o links desde `README.md`.
- Sacar scratch dirs (`.xb77*`) del working tree (ya gitignored, solo limpieza local).
- **Resultado:** la raíz pasa de ~25 ítems a ~14 (`___legacy/` se queda). Cero riesgo de romper builds.

### Fase 1 — Consolidar onchain `[paths + imports]`
- `git mv` de los 4 sitios de cadena bajo `onchain/{solana,evm,sui,stylus,circuits}/`.
- Actualizar paths en `Makefile` (targets `localnet-*`, `deploy-app`), `foundry.toml`,
  `Move.toml`, `wrangler.toml`.
- Revisar `.gitmodules` (el submódulo openzeppelin cambia de path).
- **Verificar:** `forge build`, `sui move build`, `anchor build`, `make localnet-setup`.

### Fase 2 — Consolidar apps `[paths]`
- `git mv` de `cli`, `znode`, `gateway`, `mcp`, `services`, `webapp_deploy` bajo `apps/`.
- Actualizar `build.zig` (rutas de los steps `run`/`wasm`/`merchant-wasm`) y `fly.toml`/`wrangler.toml`.
- **Verificar:** `zig build`, `zig build wasm`, `zig build test`.

### Fase 3 — Unificar SDK `[paths]`
- Absorber `sdk/src/*.ts` dentro de `sdk/ts/src/`.
- Mover `sdk/*.zig` sueltos a `sdk/zig/`.
- Documentar en `sdk/README.md` cuál es el entrypoint canónico por lenguaje.

### Fase 4 — Build unificado `(opcional, mayor esfuerzo)`
- `Makefile` raíz como único entrypoint que delega: `zig build` / `cargo` (workspace) /
  `forge build` / `sui move build` / `pnpm -r`.
- Eliminar `Makefile.native` o documentarlo como variante.
- Un `make all` que construya todo el monorepo de punta a punta.

---

## 5. Decisión pendiente: `core/chain` y `core/onchain`

Estos dos módulos Zig (13 .zig) son lógica de cadena **dentro del kernel**. Dos lecturas:
- **(a)** Son cliente/abstracción de cadena consumida por el kernel → se quedan en `core/`.
- **(b)** Son lógica onchain mal ubicada → migran a `onchain/` o `sdk/`.

Recomendación: dejarlos en `core/` (Fase 1 no los toca) y revisar caso por caso después,
porque tocar el kernel tiene más riesgo que mover contratos.

---

## 6. Qué NO cambiar

- La organización interna de `core/` (14 módulos por dominio) — es granular pero coherente.
- Los nombres de los programas Solana (`xb77_*`) — son IDs de despliegue.
- `deps/` y submódulos — fuera de alcance.
- Cualquier cosa gitignored (artefactos de build).

---

## 7. Resumen ejecutivo

| Fase | Esfuerzo | Riesgo | Impacto en claridad |
|------|----------|--------|---------------------|
| 0 — Limpieza | Bajo | Nulo | Alto (60% del ruido visual) |
| 1 — onchain/ | Medio | Medio | Alto |
| 2 — apps/ | Medio | Medio | Alto |
| 3 — sdk/ | Bajo | Bajo | Medio |
| 4 — build | Alto | Medio | Medio (DX nuevos devs) |

Recomendación: empezar por **Fase 0** (ganancia inmediata, cero riesgo) y validar el
enfoque antes de las fases con `git mv`.

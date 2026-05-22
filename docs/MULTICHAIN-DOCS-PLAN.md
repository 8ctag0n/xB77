# Plan de Docs — Reframe Multichain (Núcleo Agnóstico)

> Estado: **plan / no aplicado** · Fecha: 2026-05-22
> Decisiones: enfoque **núcleo chain-agnostic** (cadenas = adaptadores de settlement) ·
> **no editar todavía** (hay laburo en paralelo; este doc lista los cambios archivo por archivo).
> Relacionado: [ARCHITECTURE-PROPOSAL.md](./ARCHITECTURE-PROPOSAL.md).

---

## ★ Ejecución en 3 ramas paralelas (archivos disjuntos → sin conflictos)

Este doc es el **maestro**. La ejecución se parte en 3 ramas con sets de archivos
**mutuamente exclusivos**, por lo que pueden correr a la vez y mergear sin conflictos.
La pasada de honestidad va dentro de cada rama (sobre sus propios archivos).

| Rama | Plan | Archivos exclusivos |
|---|---|---|
| **A** `feat/docs-narrative-multichain` | [plans/branch-A-docs-narrative.md](./plans/branch-A-docs-narrative.md) | `docs/{index,whitepaper,architecture,why}.md`, `docs/.vitepress/config.ts`, `docs/roadmap.md` (nuevo) |
| **B** `feat/webapp-multichain` | [plans/branch-B-webapp-multichain.md](./plans/branch-B-webapp-multichain.md) | `webapp_deploy/index.html`, `assets/src/page-*.jsx`, `landing-pipeline-demo.jsx` (+ build) |
| **C** `feat/readme-honesty` | [plans/branch-C-readme-honesty.md](./plans/branch-C-readme-honesty.md) | `README.md` (+ refs a README-ARC/SUI) |

**Fuera del alcance de hoy:** los `git mv` de la reorg de repo ([ARCHITECTURE-PROPOSAL.md](./ARCHITECTURE-PROPOSAL.md)
Fase 1+) y la dapp funcional (`dapp-*.jsx`, `lib/solana-*`, IDLs). Mover archivos mientras
3 ramas editan contenido = el caos que estamos evitando. Esa reorg + el wiring van en su
propia ventana (la otra sesión), después de mergear A/B/C.

---

## 0. La tesis del reframe

Hoy los docs tratan a **Solana como la base del stack**. La verdad arquitectónica es que
el núcleo es **portable**: agent OS (Zig), ZK engine (Noir), AWP mesh, QVAC brain y el
motor 2.011% **no dependen de la cadena**. Las cadenas son **backends de settlement
intercambiables**.

| | Mensaje viejo | Mensaje nuevo |
|---|---|---|
| Posicionamiento | "capa de comercio soberano **sobre Solana**" | "OS soberano para agentes, portable, con **adaptadores de settlement** por cadena" |
| Multichain | feature / apéndice ("también soportamos…") | **propiedad de la arquitectura** (settlement pluggable) |
| Solana | la base | el **primer adaptador** (el más maduro) |
| Arc / Sui | editions separadas | adaptadores adicionales sobre el mismo núcleo |

**Regla de oro:** el núcleo se describe sin nombrar cadena. La cadena solo aparece en la
**capa de settlement** y en la tabla de adaptadores. Así "multichain" no se dice: se ve.

---

## 1. Inventario de superficies a cambiar

### 1.a — Docs site (VitePress)

| Archivo | Estado | Acción |
|---|---|---|
| `README.md` | parcial (editions OK, tagline no) | Ajustar tagline + badges |
| `docs/.vitepress/config.ts` | Solana-singular | description + meta OG/Twitter |
| `docs/index.md` | Solana-singular | hero tagline + features |
| `docs/whitepaper.md` | Solana-singular | §1, §2 diagrama, §8 roadmap |
| `docs/architecture.md` | Solana-singular | intro + Settlement Layer |
| `docs/why.md` | Solana-singular | diagramas + matriz |
| `docs/manifesto.md` | ✅ ya agnóstico | sin cambios |
| `docs/roadmap.md` | **no existe** | **crear** + agregar al nav/sidebar |

### 1.b — Worker app (`webapp_deploy/`) — el gap más grande (live demo)

> ⚠️ **Workflow de build:** el contenido vive en `assets/src/*.jsx` y se compila con
> `esbuild` (`./build.sh`) a `assets/js/*.js`. **Editar los `.jsx`, NUNCA los `.js`**
> (son derivados; `build.sh` los borra y regenera en cada corrida). Tras editar, correr
> `./build.sh` y commitear **ambos** (src + js compilado, porque el deploy sirve los `.js`).

Hoy: **cero** menciones de Arc/Sui/multichain en todo el contenido público (9 páginas
hablan solo de Solana). La dapp funcional (`dapp-*.jsx`, `solana-rpc/tx`, IDLs) es
Solana-real a nivel código → **fuera de alcance** (esto es mensaje, no recableado).

| Archivo (`webapp_deploy/`) | Estado | Acción |
|---|---|---|
| `index.html` (meta: title/og/twitter) | Solana-singular | 4 metas → agnóstico (igual que config.ts) |
| `assets/src/page-why.jsx` | Solana-singular | Reframe núcleo agnóstico + nodo settlement genérico |
| `assets/src/page-architecture.jsx` | Solana-singular | Settlement layer pluggable + adaptadores |
| `assets/src/page-whitepaper.jsx` | Solana-singular | §1/§2 alineado con docs/whitepaper.md |
| `assets/src/page-pitch.jsx` | revisar | Mensaje multichain en el pitch |
| `assets/src/landing-pipeline-demo.jsx` | revisar | Hero/landing copy |
| `assets/src/page-changelog.jsx` | revisar | Sumar entrada v2.1 multichain |
| dapp (`dapp-*.jsx`, `lib/solana-*`) | Solana-real | **NO tocar** (fuera de alcance) |

---

## 2. Cambios archivo por archivo (antes → después)

### 2.1 `README.md`

**Tagline (líneas ~8-9):**
- Antes: `Shielded payments · ZK-compressed receipts · autonomous agents on Solana.`
- Después: `Shielded payments · ZK-compressed receipts · sovereign agents across Solana, Arc & Sui.`

**Badges:** el badge `Settlement: Solana` pasa a `Settlement: Solana · Arc · Sui`
(o tres badges de cadena). El de Zig/Rust queda igual.

**Frase final:** ya dice "Built for Solana Frontier, Agora Arc, and Sui Overflow" → OK.

---

### 2.2 `docs/.vitepress/config.ts`

Reemplazar las **4 ocurrencias** de la descripción Solana-singular:
- `description` (config raíz)
- `meta og:description`
- `meta og:image:alt`
- `meta twitter:description`

- Antes: `…ZK-compressed receipts, autonomous agents on Solana.`
- Después: `…ZK-compressed receipts, sovereign agents across any chain.`

> Nota: `titleTemplate` ("Autonomous Financial Infrastructure") ya es agnóstico → OK.

---

### 2.3 `docs/index.md` (hero)

**`tagline`:**
- Antes: `High-fidelity payments rail for autonomous agents on Solana — ZK-batched, shielded, mathematically auditable.`
- Después: `High-fidelity payments rail for autonomous agents — ZK-batched, shielded, mathematically auditable, settling on Solana, Arc & Sui.`

**`features`:** la feature `0x02 // BLINK DELUXE` menciona "Solana Actions". Mantenerla
(es real en Solana) pero agregar una 4ª feature `0x04 // MULTI-CHAIN SETTLEMENT`:
> "Un mismo núcleo soberano liquidando en Solana (MagicBlock), Arc (USDC/USYC) y Sui (PTB). El adaptador cambia; el agente no."

---

### 2.4 `docs/whitepaper.md`

**§1 Introduction:**
- Antes: `xB77 is a sovereign commerce layer purpose-built for autonomous agents on Solana.`
- Después: `xB77 is a sovereign commerce layer purpose-built for autonomous agents. Its core — agent runtime, ZK engine, and coordination mesh — is chain-agnostic; settlement is delegated to per-chain adapters (Solana, Arc, Sui).`

**§2 System Overview (diagrama mermaid):** el subgraph `solana["Solana Programs"]`
se generaliza a `settlement["Settlement Adapters"]` con una nota de que Solana es el
adaptador de referencia. Opción mínima: renombrar el subgraph a
`settlement["Settlement Layer — Solana adapter shown"]` y dejar el resto.

**§8 Roadmap:** hoy es solo "stub → full verifier" (eje ZK). **Agregar un segundo eje**
de expansión de cadenas, o mover ese contenido a la nueva `roadmap.md` y dejar §8 como
"Roadmap: Verifier Maturity" enlazando a la página de roadmap de producto.

---

### 2.5 `docs/architecture.md`

**Intro (línea 3):**
- Antes: `…a ZK proof engine in the middle, and Solana settlement at the base.`
- Después: `…a ZK proof engine in the middle, and a pluggable settlement layer at the base. Solana is the reference adapter; Arc and Sui implement the same interface.`

**Diagrama "System Layers":** el subgraph `SE["// SETTLEMENT LAYER — Solana"]` se
generaliza a `SE["// SETTLEMENT LAYER — pluggable adapters"]` y se añade una nota o un
nodo `ADAPT["Adapter Interface\n(Solana · Arc · Sui)"]` por encima de los nodos Solana.

> Considerar una sección nueva **"Settlement Adapters"** que muestre la interfaz común
> y cómo cada cadena la implementa (programa Anchor / contrato Yul / módulo Move).

---

### 2.6 `docs/why.md`

Los diagramas usan "Solana" como nodo concreto. Cambio mínimo: en el modelo xB77
(`graph LR` del segundo diagrama), el nodo `CHAIN2["Solana\n(proof hash only)"]` pasa a
`CHAIN2["Settlement Chain\n(proof hash only)"]`. La matriz competitiva no necesita tocar
(compara tech de privacidad, no cadenas).

---

### 2.7 `docs/roadmap.md` — **NUEVO**

Página de **roadmap de versiones** (no confundir con el verifier roadmap del whitepaper).
Estructura propuesta — eje temporal donde multichain es un hito explícito de producto:

```
v1.0 (Apr 2026) — Solana Frontier
  Agent OS + ZK receipts en Solana. Validación del modelo en una cadena.

v2.0 (May 2026) — Sovereign Core  [CURRENT]
  ZK engine propio (sin Light/ShadowWire). Núcleo desacoplado de la cadena.
  → este desacople es lo que habilita lo multichain.

v2.1 — Multi-Chain Settlement
  Arc Edition (USDC/USYC, contratos Yul) + Sui Edition (PTB, Move).
  Misma interfaz de adaptador; el agente no cambia.

v3+ — Full Cryptographic Verification + más adaptadores
  Honk/Groth16 verifier on-chain (ver Whitepaper §8) + nuevas cadenas
  sobre la misma interfaz de settlement.
```

Formato sugerido: tabla o mermaid `timeline` / `gitGraph` (ya hay precedente del
"git-graph roadmap" en el pitch). Agregar al `nav` y `sidebar` de `config.ts` bajo
"Resources".

---

## 3. Orden de aplicación sugerido (cuando se libere la ventana)

Ordenado por impacto/riesgo (lo de arriba: máximo impacto visible, mínimo riesgo):

1. **Meta/SEO** — `config.ts` + `README.md` + `webapp_deploy/index.html` (4 metas c/u).
   Es lo que aparece en links compartidos. Riesgo cero.
2. **Roadmap de versiones** — crear `docs/roadmap.md` + enlazar en nav/sidebar. No choca con nada.
3. **Landing pública de la webapp** — `page-why.jsx`, `page-architecture.jsx`,
   `landing-pipeline-demo.jsx`, `page-pitch.jsx`. **Máximo impacto** (es el live demo).
   → editar `.jsx`, correr `./build.sh`, commitear src + js.
4. **Docs site** — `index.md` hero → `whitepaper.md` + `architecture.md` → `why.md`.
5. **Sync webapp↔docs** — `page-whitepaper.jsx` / `page-changelog.jsx` alineados con los .md.

Cada paso es un commit chico e independiente. Nada de esto toca la dapp funcional ni
paths de build de código (Zig/Rust/contratos).

---

## 4. Checklist de consistencia (post-edición)

- [ ] Buscar residuales en docs: `grep -rin "on Solana" docs/ README.md` (excluir `v1/`).
- [ ] Buscar residuales en webapp: `grep -rin "on Solana" webapp_deploy/index.html webapp_deploy/assets/src/page-*.jsx`.
- [ ] El núcleo (OS/ZK/AWP/QVAC/2.011%) se describe **sin** nombrar cadena.
- [ ] Solana aparece solo en: settlement layer, tabla de adaptadores, y como "adaptador de referencia".
- [ ] `roadmap.md` enlazado desde nav y sidebar.
- [ ] Webapp: `.jsx` editados → `./build.sh` corrido → `.js` compilados commiteados.
- [ ] Arc/Sui mencionados con respaldo real (Arc: USDC/USYC/Yul · Sui: package `sovereign` + PTBs publicado).
- [ ] La dapp funcional y `v1/` **no se tocan** (Solana-real / archivo histórico).

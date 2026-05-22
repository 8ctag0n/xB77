# Rama A — `feat/docs-narrative-multichain`

> Plan ejecutable · no aplicado · enfoque **núcleo chain-agnostic** ·
> Maestro: [../MULTICHAIN-DOCS-PLAN.md](../MULTICHAIN-DOCS-PLAN.md) · [../ARCHITECTURE-PROPOSAL.md](../ARCHITECTURE-PROPOSAL.md)

## Archivos que esta rama posee (exclusivos — no los tocan B ni C)
- `docs/index.md`
- `docs/whitepaper.md`
- `docs/architecture.md`
- `docs/why.md`
- `docs/.vitepress/config.ts`
- `docs/roadmap.md` **(nuevo)**

> ⚠️ No tocar `README.md` (rama C) ni nada bajo `webapp_deploy/` (rama B). No tocar `docs/v1/` (archivo histórico).

## Tesis
El núcleo (agent OS Zig, ZK engine Noir, AWP mesh, QVAC brain, motor 2.011%) es **portable**.
Las cadenas son **adaptadores de settlement**. Regla: el núcleo se describe **sin nombrar cadena**;
Solana solo aparece como "adaptador de referencia" en la capa de settlement.

## Cambios

### `docs/.vitepress/config.ts`
1. **Meta (4 ocurrencias):** `description`, `og:description`, `og:image:alt`, `twitter:description`
   - `…autonomous agents on Solana.` → `…sovereign agents across any chain.`
2. **Nav:** agregar `{ text: 'Roadmap', link: '/roadmap' }` (después de Whitepaper, antes de Changelog).
3. **Sidebar `/`:** en la sección "Resources", agregar `{ text: 'Roadmap', link: '/roadmap' }`.

### `docs/index.md` (hero)
- `tagline`: quitar "on Solana", agregar cierre multichain:
  `…mathematically auditable, settling on Solana, Arc & Sui.`
- Agregar 4ª feature `0x04 // MULTI-CHAIN SETTLEMENT`:
  "Un mismo núcleo soberano liquidando en Solana (MagicBlock), Arc (USDC/USYC) y Sui (PTB). El adaptador cambia; el agente no."

### `docs/whitepaper.md`
- **§1:** "purpose-built for autonomous agents on Solana" → "...for autonomous agents. Its core —
  agent runtime, ZK engine, coordination mesh— is chain-agnostic; settlement is delegated to
  per-chain adapters (Solana, Arc, Sui)."
- **§2 diagrama:** subgraph `solana["Solana Programs"]` → `settlement["Settlement Adapters — Solana shown"]`.
- **§8 Roadmap:** renombrar a "Roadmap: Verifier Maturity"; al final, link a `/roadmap` para el roadmap de producto/cadenas.
- **HONESTIDAD:** donde diga "verified on-chain" / "the verifier confirms", aclarar el estado real
  (verifier = structural stub hoy; verificación criptográfica completa = roadmap §8). Ya hay base honesta en §8 — propagar ese tono al resto.

### `docs/architecture.md`
- **Intro (l.3):** "...and Solana settlement at the base." → "...and a pluggable settlement layer
  at the base. Solana is the reference adapter; Arc and Sui implement the same interface."
- **Diagrama "System Layers":** `SE["// SETTLEMENT LAYER — Solana"]` → `SE["// SETTLEMENT LAYER — pluggable adapters"]`;
  agregar nodo `ADAPT["Adapter Interface\n(Solana · Arc · Sui)"]`.
- Sección nueva opcional **"Settlement Adapters"**: interfaz común + cómo la implementa cada cadena
  (Anchor / Yul / Move).

### `docs/why.md`
- 2º diagrama: nodo `CHAIN2["Solana\n(proof hash only)"]` → `CHAIN2["Settlement Chain\n(proof hash only)"]`.
- Matriz competitiva: sin cambios (compara tech de privacidad, no cadenas).

### `docs/roadmap.md` (NUEVO)
Roadmap de **versiones** (≠ verifier roadmap del whitepaper). Eje temporal:
```
v1.0 (Apr 2026) — Solana Frontier      → validación del modelo en una cadena
v2.0 (May 2026) — Sovereign Core [NOW] → ZK engine propio; núcleo desacoplado de la cadena
v2.1 — Multi-Chain Settlement          → Arc (USDC/USYC/Yul) + Sui (Move/PTB, package publicado)
v3+  — Full Crypto Verification        → Honk/Groth16 on-chain (ver Whitepaper §8) + más adaptadores
```
Formato: mermaid `timeline` o tabla. Dejar explícito que el desacople de v2.0 es lo que **habilita** v2.1.
**HONESTIDAD:** marcar claramente qué es `[done]`, `[wired-but-stubbed]`, `[roadmap]`.

## Validación
- `cd docs && bun run docs:build` (o el script de build de VitePress) sin errores.
- `grep -rin "on Solana" docs/*.md docs/.vitepress/config.ts` → 0 resultados (excluir v1/).
- Nav y sidebar muestran "Roadmap".

## Git
```
git checkout main && git pull
git checkout -b feat/docs-narrative-multichain
# … cambios …
git add docs/index.md docs/whitepaper.md docs/architecture.md docs/why.md docs/.vitepress/config.ts docs/roadmap.md
git commit  # commits chicos por archivo o uno coherente
```

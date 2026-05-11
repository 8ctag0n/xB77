# Plan Maestro Deluxe — Webapp Pública xB77

**Fecha:** 2026-05-11
**Branch base:** `feat/docs-vitepress`
**Worktree base:** `/home/exp1/Desktop/xB77/worktree/docs-v2`
**Estado:** Spec aprobado, pendiente de plan de implementación

## 1. North Star

> En 60 segundos, un evaluador hostil pasa de escéptico a *"esto es real y está vivo"*.

Toda decisión de scope/diseño se valida contra esa frase: contribuye al giro de 60s o lo retrasa.

## 2. Audiencia y modo de consumo

- **Visitor primario:** evaluador con 2–5 min (judge hackathon Frontier, VC en call, comité de grant)
- **Modo:** self-explorable **by design** — sin tooltips, sin wizards, sin onboarding modal
- **Mecanismo:** cada pantalla = hero claim + visual que prueba el claim + un solo CTA primario
- **Estilo:** doblamos la apuesta en el sistema ya validado (lime `#c8ff2e` + cyan `#00f0ff` + magenta `#ff2e88` sobre `#08080a`, Space Grotesk + Geist Mono, watermark tipográfico, `// ` heading prefix, terminal animado, dotted grid bg)

## 3. Arco narrativo (Sinek WHY → HOW → WHAT)

Nav consolidado de 8 rutas → **6 rutas**:

| Ruta | Rol | Notas |
|------|-----|-------|
| `/` | HOOK técnico + teaser de manifesto | Claim "Sovereign Commerce Layer" + subhead "ZK-batched payments rail for autonomous agents on Solana". Manifesto cyberpunk como segundo beat, nunca primero. |
| `/why` | WHY | Manifesto + soberanía + por qué ahora |
| `/architecture` | HOW | ZK Pipeline Visualizer expandido + mermaid + componentes |
| `/network` | WHAT proof | Network Pulse (real metrics) + Ghost Audit Portal |
| `/app` | WHAT product | dApp + Explorer fusionados con tabs (Wallet \| Agents \| Pipelines \| Mesh \| Explorer) |
| `/docs` | Drill-down hub | Cards a docs externos, whitepaper, changelog |

**Consolidaciones clave:**
- `dapp` + `explorer` → `/app` con tabs (una sola superficie de producto)
- `whitepaper` + `changelog` + `docs` → `/docs` como hub
- `network` es ruta nueva

## 4. Success criteria

1. Las 6 rutas cargan sin errores en CF Pages prod URL
2. Network Pulse muestra `slot_height` real del validador, subiendo en vivo en el navegador
3. Ghost Audit acepta un tx hash conocido y devuelve verdict real
4. dApp tabs visualmente indistinguibles del Explorer en jerarquía/density/contraste (validar side-by-side)
5. Worker adapter degrada a snapshot con dot ámbar si backend cae (probar matando el podman 10s)
6. Mobile (≥375px): ninguna ruta tiene overflow horizontal
7. Lighthouse perf ≥85 en `/` y `/network`

## 5. Pipeline de datos

```
Browser (webapp_deploy)
  │ fetch('/api/...')
  ▼
CF Worker (gateway/worker/)  ←── adapter layer
  │ env.ZNODE_RPC_URL switch:
  │   dev:  http://localhost:8899 (validador podman via cloudflared tunnel)
  │   prod: https://znode.xb77.dev (post merge-onchain)
  ▼
Solana RPC + xB77 programs
```

### Endpoints del worker (mínimo viable)

| Endpoint | Devuelve |
|---|---|
| `GET /api/network/pulse` | `{slot, blockHeight, agentsOnline, proofsVerified24h}` |
| `GET /api/audit/:txhash` | `{verdict, proofId, agent, timestamp, chunks}` |
| `GET /api/agents` | Lista de agents conocidos |
| `GET /api/pipelines/recent` | Últimas N pipelines |

### Cliente `assets/src/lib/data-source.js`

- Cache en `localStorage` con TTL 30s
- Fallback chain: live fetch → cached → frozen demo snapshot (hardcoded, visualmente idéntico)
- Dot de estado: 🟢 LIVE / 🟡 CACHED 14s / 🔴 SNAPSHOT (sutil, esquina)
- **Nunca** muestra error técnico ni skeleton infinito

## 6. Componentes signature (W2)

### 6.1 Agent Identity Badge

Reusable en `/app`, `/network`, home.

- Generative avatar 8×8 grid simétrico horizontal desde pubkey hash, colores derivados dentro de paleta xB77
- Anatomía: avatar 48px + truncated pubkey `8xK9…Qm2` en Geist Mono + status dot + reputation bar 4px lime
- Interacciones: hover → glow halo + reveal full pubkey + copy; click → drill al detalle
- Animaciones: `badge-shimmer` (scanline diagonal cada 8s), entrada con stagger fly-in si está en lista
- Self-contained, cero deps

### 6.2 ZK Pipeline Visualizer

Hero del home (segundo scroll) + ancla de `/architecture`.

- 5 nodos horizontales en SVG: `AGENT → PROOF_GEN → CHUNK_UPLOAD → VERIFY → SETTLED`
- Pulso "paquete" cyan viaja node-to-node cada 3s con trail; cada nodo se ilumina lime al recibir
- Si data-source LIVE, contadores reales encima de cada nodo; si SNAPSHOT, números frozen pero animación sigue
- Versión `/architecture` expandida con mini-card por nodo (contrato, latencia P50, tamaño chunk)

## 7. Paralelización

### Setup coordinado (vos+yo, secuencial, ~30 min)

1. Tokens y keyframes consolidados en `webapp_deploy/index.html` (agregar: `badge-shimmer`, `pipeline-pulse`, `watermark-drift`, `cached-blink`; activar magenta como warning token)
2. `webapp_deploy/assets/src/CONTRACTS.md` (nuevo) documenta:
   - Signatures de `data-source.js` exportadas por W3 y consumidas por W1/W2
   - Slots del router que W1 expone y W2 referencia
   - Props de `<AgentBadge>` y `<ZKPipelineVisualizer>` (W2 publica, W1 consume)
3. 3 worktrees creados con `superpowers:using-git-worktrees` desde `feat/docs-vitepress`

### Worktrees (ownership estricta)

| Worktree | Branch | Files owned (exclusivo) | Deliverable |
|---|---|---|---|
| **W1: app-rebuild** | `feat/app-deluxe` | `webapp_deploy/assets/src/dapp-*.jsx`, `webapp_deploy/assets/src/explorer-*.jsx`, `webapp_deploy/assets/src/app-tabs.jsx` (nuevo), sección `/app` de `router.jsx` | Página `/app` con 5 tabs coherentes, reusando StatCard/Row/Sparkline/MeshCanvas/Status |
| **W2: signatures-home** | `feat/signatures-deluxe` | `webapp_deploy/assets/src/signatures/*.jsx` (nuevo), `webapp_deploy/assets/src/home-*.jsx`, `webapp_deploy/assets/src/page-why.jsx`, watermark CSS scoped | Agent Badge, ZK Pipeline Visualizer, home con watermark + teaser manifesto, `/why` deluxe |
| **W3: data-infra** | `feat/data-infra` | `gateway/worker/` (nuevo wrangler config + handler), `webapp_deploy/assets/src/lib/data-source.js` (nuevo), `webapp_deploy/assets/src/page-network.jsx` (nuevo) | CF Worker con 4 endpoints, cliente con degradation, página `/network` con Pulse + Ghost Audit |

### Reglas de no-colisión

- Ningún worktree toca `webapp_deploy/index.html` después del setup
- Ningún worktree toca `router.jsx` salvo W1
- Cualquier token CSS nuevo se agrega en setup coordinado, no en worktree
- Merge final via `superpowers:dispatching-parallel-agents` + `git-merger` sub-agent

## 8. Capa de coherencia (cross-cutting)

| Ítem | Acción | Responsable |
|---|---|---|
| Fonts: webapp usa JetBrains Mono, docs usa Geist Mono | Migrar webapp → Geist Mono via `--mono` token | Setup coordinado |
| Watermark gigante "xB77 // SOVEREIGN COMMERCE" | Portar de docs v2 → home (clamp 8rem–28rem, mobile-safe) | W2 |
| Magenta `#ff2e88` definido sin uso | Activar como warning/devnet badge + cached state dot | W3 + audit |
| Dotted grid bg | Validar misma intensidad/spacing docs↔webapp | Audit |
| Heading prefix `// ` | Sweep H1/H2 en todas las rutas | Audit |
| Mobile ≥375px | Sin overflow horizontal; watermark se reduce; nav colapsa | Audit |

## 9. Timeline (wall-clock)

```
T+0:00  Setup coordinado (tokens + CONTRACTS.md + 3 worktrees)        [vos+yo]
T+0:30  Lanzamiento 3 agentes paralelos (W1 + W2 + W3)                [paralelo]
T+3:00  Checkpoint #1: cada worktree muestra avance, ajustes
T+4:00  Checkpoint #2: integración local — merge W1 → W2 → W3
T+4:30  Audit visual de las 6 rutas + mobile spot-check               [vos+yo]
T+5:00  Deploy a CF Pages preview + verificación Lighthouse
T+5:30  Polish final, fix lo que aparezca en audit
T+6:00  Deploy a producción
```

## 10. Deploy y verificación

### Pre-deploy local

1. `./build.sh` — verificar 0 warnings
2. `bunx wrangler pages dev . --port 8788` — smoke test 6 rutas
3. Matar podman 10s + refresh → confirmar caída a SNAPSHOT con dot ámbar (no error)
4. Reload podman → confirmar vuelve a LIVE solo

### Deploy

1. CF Pages preview: `bunx wrangler pages deploy webapp_deploy/ --project-name xb77-preview`
2. CF Worker: `bunx wrangler deploy` desde `gateway/worker/`
3. Smoke test público preview URL
4. Promote a prod (CF Pages prod o subdomain `app.xb77.dev`)
5. Lighthouse desktop + mobile en `/` y `/network` (≥85 perf)

Verificación final con `superpowers:verification-before-completion` — no claim "done" sin output concreto.

## 11. Riesgos y contingencias

| Riesgo | Probabilidad | Mitigación | Plan B |
|---|---|---|---|
| Validador podman flaky mid-build | Media | data-source.js degrada invisible | Demo corre con SNAPSHOT, nadie nota |
| CF Worker quotas/auth (cuenta nueva) | Media | Setup auth en primeros 10 min | `wrangler dev` local + cloudflared tunnel |
| ZK Pipeline Visualizer demora >4h | Media-Alta | Time-box estricto; simplificar a SVG estático con CSS animation | W2 entrega Agent Badge + watermark, ZK visualizer se posterga |
| Merge conflicts entre worktrees | Baja (ownership estricta) | CONTRACTS.md + pre-merge review | `git-merger` skill, fallback rebase manual |
| Mobile breakdown en watermark | Media | Audit explícito en bloque 3 | Watermark se desactiva <640px |
| Deploy CF auth no funciona en tiempo | Baja | Plan B: GitHub Pages como fallback | webapp_deploy/ es estática, sirve cualquier static host |

## 12. Integración con worktree `merge-onchain`

Crítico para que esto no rompa cuando mergee el work paralelo de programs/scripts:

- **W3 worker** define el contrato de endpoints **hoy**; cuando `merge-onchain` mergee, sólo cambia `env.ZNODE_RPC_URL` en CF — la webapp no se entera
- **Pubkeys de programs** se leen via env del worker, no hardcoded en webapp (referencia: `reference_xb77_ids.md` en memoria)
- **Fix .sframe linker** (`reference_xb77_sframe_fix.md`) ya vive en `product-deluxe`; al integrar con `merge-onchain`, asegurar que esa fix esté presente en el branch destino antes de mergear data-infra
- Tras merge final a `bedrock` o branch de release, **un solo commit de integración** updatea `ZNODE_RPC_URL` y redeploya el worker

## 13. Definition of Done

- [ ] 6 rutas live en CF Pages prod URL
- [ ] Network Pulse con `slot_height` real subiendo (verificado en navegador limpio)
- [ ] Ghost Audit responde para un tx hash conocido
- [ ] dApp tabs visualmente coherentes con Explorer (screenshot side-by-side)
- [ ] Mobile spot-check 375px / 768px sin overflow
- [ ] Lighthouse ≥85 perf en `/` y `/network`
- [ ] Memoria actualizada (`project_xb77_webapp_session.md` con estado final)
- [ ] PR/merge a `feat/docs-vitepress` o rama de release

## 14. Out of scope (explícito)

Para evitar scope creep en horas de hackathon:

- **No** se diseña dApp con wallet connect real (Phantom/Solflare integration) — el "Wallet" tab muestra UI con mock state
- **No** se implementa Blink Deluxe Gallery (M4 de la lista signature original) — queda P2
- **No** se construye gateway worker WASM para programs — el worker es JS, sólo proxy/cache
- **No** se reescriben docs v2 (ya están deluxe) — sólo se linkean desde `/docs`
- **No** se hace SEO/OG images optimization — queda P2
- **No** se hace i18n — sólo español/inglés mixto como está hoy

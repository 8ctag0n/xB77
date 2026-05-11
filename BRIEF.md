# 🎨 Worktree W2 — `signatures-deluxe`

> **Misión**: Construir los componentes signature (Agent Identity Badge + ZK Pipeline Visualizer), portar el watermark gigante de los docs al home, y dejar la página `/why` deluxe.

## Coordenadas

- **Branch**: `feat/signatures-deluxe`
- **Worktree path**: `/home/exp1/Desktop/xB77/worktree/signatures-deluxe`
- **Base**: `feat/docs-vitepress` (incluye spec commit `d0a11e6`)
- **Spec completo**: `docs/superpowers/specs/2026-05-11-plan-maestro-deluxe-design.md` (secciones 6, 8)

## Files owned (EXCLUSIVO)

- `webapp_deploy/assets/src/signatures/*.jsx` (NUEVO directorio)
- `webapp_deploy/assets/src/home-*.jsx`, `landing-*.jsx`, `variant-*.jsx`
- `webapp_deploy/assets/src/page-why.jsx`
- `webapp_deploy/assets/src/page-architecture.jsx` (solo donde insertás el ZK Visualizer)
- Scoped CSS dentro de los `.jsx` (NO tocar `index.html`)

## Files PROHIBIDOS

- `webapp_deploy/index.html` (lo toca solo el setup coordinado)
- `webapp_deploy/assets/src/dapp-*.jsx`, `explorer-*.jsx`, `app-tabs.jsx`, `router.jsx` (W1)
- `gateway/worker/`, `lib/`, `page-network.jsx` (W3)

## Deliverables

### 1. `<AgentBadge>` (`signatures/agent-badge.jsx`)

- Generative avatar 8×8 grid simétrico horizontal desde `pubkey` hash
- Paleta dentro de xB77 (lime/cyan/magenta, NO colores random)
- Hover: glow halo + reveal full pubkey + copy-to-clipboard
- Props: `{ pubkey, size=48, showLabel=true, interactive=true }`
- Self-contained, exporta a `window.AgentBadge`

### 2. `<ZKPipelineVisualizer>` (`signatures/zk-pipeline-visualizer.jsx`)

- 5 nodos SVG: `AGENT → PROOF_GEN → CHUNK_UPLOAD → VERIFY → SETTLED`
- Pulso "paquete" cyan viaja node-to-node cada ~9s con drop-shadow
- Variant `compact` (home) y `expanded` (architecture con números encima de cada nodo si hay `liveData`)
- Exporta a `window.ZKPipelineVisualizer`

### 3. Watermark gigante en home

- Texto serif italic "xB77 // SOVEREIGN", `clamp(8rem, 22vw, 28rem)`
- `position:absolute`, `pointer-events:none`, alpha bajo (~0.04)
- Mobile guard: NO renderizar si `window.innerWidth < 640`

### 4. `/why` deluxe

- H1 grande serif italic con dos líneas: "Sovereignty is not given.<br/>It is computed."
- Prefix `// WHY xB77` en mono arriba
- Bajada de 1-2 párrafos
- Subsecciones "The thesis" + "Why now" con lista

## Contratos

Tu output es consumido por W1 (que monta `<AgentBadge>` en las tabs de `/app`) y por la página `/architecture` (que usa `<ZKPipelineVisualizer variant="expanded">`). Respetá las props del CONTRACTS.md (será creado durante setup coordinado).

`liveData` del visualizer en `/architecture` puede ser `null` — el componente debe renderizar igual sin él.

## Cómo verificar

```bash
cd /home/exp1/Desktop/xB77/worktree/signatures-deluxe/webapp_deploy
./build.sh
bunx wrangler@latest pages dev . --port 8788
```

Test en DevTools console:
```js
ReactDOM.render(React.createElement(window.AgentBadge, {pubkey:'8xK9abcdefgQm2HIJKLMNOPxyz123'}), document.body.appendChild(document.createElement('div')))
ReactDOM.render(React.createElement(window.ZKPipelineVisualizer, {variant:'compact'}), document.body.appendChild(document.createElement('div')))
```

Visual check de `#home` y `#why`.

## Cómo commitear

Granular: un commit por entregable (badge, visualizer, watermark, why). Mensajes:

```
feat(signatures): AgentBadge generative from pubkey
feat(signatures): ZKPipelineVisualizer SVG animated
feat(home): watermark gigante portado de docs v2
feat(why): /why deluxe con jerarquía estricta
```

## Handoff

Cuando termines, NO mergees — avisame y yo hago el merge ordenado desde `docs-v2`.

# Rama B — `feat/webapp-multichain`

> Plan ejecutable · no aplicado · enfoque **núcleo chain-agnostic** ·
> Maestro: [../MULTICHAIN-DOCS-PLAN.md](../MULTICHAIN-DOCS-PLAN.md)

## Archivos que esta rama posee (exclusivos — no los tocan A ni C)
- `webapp_deploy/index.html` (solo metas)
- `webapp_deploy/assets/src/page-why.jsx`
- `webapp_deploy/assets/src/page-architecture.jsx`
- `webapp_deploy/assets/src/page-whitepaper.jsx`
- `webapp_deploy/assets/src/page-pitch.jsx`
- `webapp_deploy/assets/src/page-changelog.jsx`
- `webapp_deploy/assets/src/landing-pipeline-demo.jsx`
- `webapp_deploy/assets/js/*.js` (derivados — regenerados por build)

> ⚠️ **NO tocar la dapp funcional:** `dapp-*.jsx`, `assets/src/lib/solana-*`, `idls/`. Es Solana-real (fuera de alcance: esto es mensaje, no recableado).
> ⚠️ Nada de `docs/` (rama A) ni `README.md` (rama C).

## ⚠️ Workflow de build (CRÍTICO)
El contenido vive en `assets/src/*.jsx` → se compila con esbuild → `assets/js/*.js`.
- **Editar SOLO los `.jsx`.** Los `.js` son derivados; `build.sh` los borra y regenera.
- Tras editar: `cd webapp_deploy && ./build.sh`
- Commitear **ambos** (src + js compilado) — el deploy sirve los `.js`.

## Cambios

### `index.html` (metas, 4 ocurrencias)
`…autonomous agents on Solana.` → `…sovereign agents across any chain.`
(`description`, `og:description`, `og:image:alt`, `twitter:description`). Alinear con `config.ts` de rama A.

### `page-why.jsx`
- Reframe núcleo agnóstico (mismo criterio que `docs/why.md`).
- Diagrama/copy: "Solana" como cadena concreta → "Settlement Chain" genérica.

### `page-architecture.jsx`
- Settlement layer = pluggable adapters; mostrar Solana/Arc/Sui como adaptadores de una interfaz común.

### `page-whitepaper.jsx`
- §1/§2 alineado con `docs/whitepaper.md` (rama A): núcleo agnóstico + settlement adapters.
- HONESTIDAD: estado real del verifier (stub hoy / crypto completo roadmap).

### `landing-pipeline-demo.jsx` (hero/landing)
- Copy del hero: quitar "on Solana", sumar cierre multichain (Solana · Arc · Sui).

### `page-pitch.jsx`
- Mensaje multichain explícito en el pitch; el "núcleo portable" como diferencial.

### `page-changelog.jsx`
- Sumar entrada **v2.1 — Multi-Chain Settlement** (Arc + Sui). Mantener honestidad del delta.

## HONESTIDAD (transversal a esta rama)
Marcar dónde el landing afirma cosas que el código no respalda aún:
- "cryptographically enforced / verified on-chain" → suavizar o `(roadmap)` honesto.
- 2.011% como mecanismo vivo → hoy facilitator es placeholder; presentarlo como diseño/roadmap.

## Validación
- `cd webapp_deploy && ./build.sh` sin errores.
- `grep -rin "on Solana" webapp_deploy/index.html webapp_deploy/assets/src/page-*.jsx` → 0.
- `grep -ril -e "\barc\b" -e "\bsui\b" webapp_deploy/assets/src/page-*.jsx` → aparece (antes: 0).
- Abrir `index.html` localmente y revisar landing/why/architecture/pitch.
- Correr tests existentes si aplican: `webapp_deploy/test/*.test.js`.

## Git
```
git checkout main && git pull
git checkout -b feat/webapp-multichain
# … editar .jsx …
cd webapp_deploy && ./build.sh && cd ..
git add webapp_deploy/index.html webapp_deploy/assets/src/page-*.jsx webapp_deploy/assets/src/landing-pipeline-demo.jsx webapp_deploy/assets/js
git commit
```

# HANDOFF — Tomorrow morning checklist

> **Branch**: `post-frontier-enhancement`
> **What changed today**: 4 sponsor-specific Remotion demos rendered, SNS reverse-lookup end-to-end live, MagicBlock toggle wired, ConnectionPill .sol swap functional, 6 sponsor track form drafts ready to paste.

## Antes de dormir (1 acción, ~5 segundos)

```bash
cd <tu-repo>
git status              # confirma que no quedan cambios sin commitear
```

Si quedó algo modificado por mí mientras hacía cleanup, lo verás. Si está clean, te vas a dormir tranquilo. El push a GitHub puede esperar a mañana.

## Mañana — orden recomendado (1-2 horas total)

### Paso 1: Confirmar que los 4 demos terminaron de renderizar (~30 seg)

```bash
ls -la webapp_deploy/remotion/out/demo_*.mp4
```

Deberías ver 4 archivos `demo_bonfida.mp4`, `demo_magicblock.mp4`, `demo_qvac.mp4`, `demo_solana.mp4` — además del `demo_v3.mp4` genérico.

Si alguno falta, mirá `/tmp/remotion_queue.log` para ver dónde se cortó. Re-lanzá con `npm run render:<nombre>` desde `webapp_deploy/remotion/`.

### Paso 2: Push al remote (5 min)

```bash
cd <tu-repo>
git remote add origin https://github.com/8ctag0n/xB77v2.git  # si no estaba
git push -u origin post-frontier-enhancement
```

Si tu local clone aún tiene la historia vieja (pre-rewrite), pulleala primero:
```bash
git fetch origin
git reset --hard origin/post-frontier-enhancement   # acepta la historia rewriteada
```

### Paso 3: Subir los 5 mp4 a YouTube unlisted (~15 min)

Por cada uno:
- studio.youtube.com → UPLOAD
- Drag the mp4
- Title: "xB77 — <track name>"
- Visibility: **Unlisted** (no público en searches, pero accesible vía link)
- Copy share link

Te quedan 5 links públicos:
```
demo_bonfida.mp4    → <youtube link 1>
demo_magicblock.mp4 → <youtube link 2>
demo_qvac.mp4       → <youtube link 3>
demo_solana.mp4     → <youtube link 4>
demo_v3.mp4         → <youtube link 5>   (genérico — Cloudflare + 100xDevs)
```

### Paso 4: Submit los 5 forms (~30 min, 5-7 min cada uno)

Templates listos en `docs/submissions/forms/`. Por cada track:

1. Abrí el archivo `<sponsor>.md`
2. Reemplazá `<YOUTUBE_URL>` con el link correspondiente
3. Reemplazá `<X_HANDLE>` con tu X profile (o dejá vacío)
4. Copy-paste cada code block en el field correspondiente del form
5. Submit

**Orden recomendado**:

| # | Sponsor | Video | Form file |
|---|---|---|---|
| 1 | Cloudflare Workers | `demo_v3.mp4` | `forms/cloudflare.md` |
| 2 | Bonfida / SNS | `demo_bonfida.mp4` | `forms/bonfida.md` |
| 3 | Solana base | `demo_solana.mp4` | `forms/solana.md` |
| 4 | QVAC / Tinfoil | `demo_qvac.mp4` | `forms/qvac.md` |
| 5 | 100xDevs (DOS submits: Colosseum + Superteam Earn) | `demo_v3.mp4` | `forms/100xdevs.md` |
| 6 | MagicBlock (UPDATE — ya está submitido con backup) | `demo_magicblock.mp4` | `forms/magicblock.md` — postear comment o reemplazar Demo Link |

### Paso 5 (opcional, si te queda fuel)

- **Devnet captures + v5 demos con Solscan signatures reales**: en `scripts/demo_capture.sh` con el INGEST_TOKEN del `.cf_deploy_summary`. Re-render con sección onchain nueva. Posteás el v5 como update post-submission.
- **Rotar `INGEST_TOKEN`** (lo filtraste en chat dos veces hoy):
  ```bash
  cd gateway/worker
  NEW=$(python3 -c 'import secrets; print(secrets.token_hex(24))')
  echo "$NEW" | bunx --bun wrangler@latest secret put INGEST_TOKEN
  # update .cf_deploy_summary local con el nuevo
  ```
- **Revocar el CF API token** una vez submittidos todos los forms.

## Recursos

- **Live Worker**: https://xb77-adapter.frontier247hack.workers.dev
- **dApp**: https://xb77-adapter.frontier247hack.workers.dev/app
- **API**: https://xb77-adapter.frontier247hack.workers.dev/api/v1
- **5 programas devnet** (en `explorer.solana.com/?cluster=devnet`):
  - `xb77_core`: `73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3`
  - `xb77_gateway`: `83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4`
  - `xb77_registry`: `HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1`
  - `xb77_compression`: `6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN`
  - `xb77_zk_verifier`: `J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ`
- **Gateway pubkey (current deploy)**: `f1356a96a21ee38cda4eda8facfa068eabc3a62bb76320a5b34bc491c4dcc462`

## Resumen de commits hechos hoy

Sobre `post-frontier-enhancement`:

```
4492e29  fix(sns-reverse): parse actual Bonfida response shape + invalidate cache
3af779d  fix(cf-deploy): trust WORKERS_SUBDOMAIN env when set, skip API roundtrip
1a3a887  perf(deploy): stage assets to /tmp before wrangler — skip walking 670MB
32ee5b6  chore(deploy): also exclude assets/src/ from Worker Static Assets upload
ef36618  docs(specs): sync sponsors specs with post-frontier F1/F3/F6/SNS-e2e
a13ea9d  feat(sns): end-to-end reverse lookup — Worker proxy + browser wire
0b12a3a  feat(magicblock): F1 — Delegation Program path + live shim mode
29086ec  feat(brain,dapp): F6 ConnectionPill .sol swap + F3 brain memory ownership
b9954c9  docs(submissions): paste-ready form drafts for 6 sponsor tracks
fb1fb45  feat(demo): 4 sponsor-specific cuts (Bonfida / MagicBlock / QVAC / Solana)
```

Buen descanso. Mañana levantás, push, suba, submitea, dormís de nuevo.

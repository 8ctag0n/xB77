# 🔁 HANDOFF — SDK WASM-Core Deluxe

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/merge-onchain-deluxe`
> **Branch base**: `merge/onchain-deluxe` @ `6649a1e`
> **Próxima rama de trabajo**: `feat/sdk-wasm-deluxe`
> **Spec**: `docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.md`
> **Addendum**: `docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.addendum.md` (decisiones lockeadas durante Fase 1: canonical bytes, error codes, length protocol, deuda explícita)
> **Budget**: 9.5 horas (scope recortado v1.0 — ver §Scope decision 2026-05-11)
> **Safety rollback**: tag `pre-sdk-wasm-deluxe-2026-05-11` (vive en `feat/docs-vitepress`)

## ⚠️ Scope decision 2026-05-11 (lockeada, no re-discutir)

Hackathon budget total: 12 hrs. SDK v1.0 incluye **Zig + TS + Rust**. Python y Go wrappers van a **v1.1 post-hackathon** con ABI estable garantizada.

**Evolución del scope**:
1. Inicial: 4 lenguajes (Zig+TS+Py+Rust), 15 hrs → no entraba en 12 hrs
2. Recorte: Zig+TS, 9.5 hrs → Python+Rust+Go a v1.1
3. Re-ampliación (post-Fase 6): Fase 1-2-3-6 cerraron en 2.5 hrs (vs 9.5 estimado) → bancamos meter Rust de vuelta

**Por qué Rust y NO Python en v1.0**: audiencia Solana es Rust-nativa; wasmtime-py tiene quirks identificadas en spec §10 (más riesgo). Go queda en v1.1 para audiencia infra/devops.

**Trade-off aceptado**: "SDK day-1 en 3 lenguajes con cross-conformance byte-identical" — mensaje más fuerte que TS-only.

**Safety check explícito**: si Rust wrapper supera 2 hrs, Python+Go quedan firmes en v1.1 sin culpa.

## Por qué este worktree

Acá tenés todo lo pesado integrado:
- `core/` Zig completo (cripto, AWP, merchant, chain, mesh)
- `onchain/programs/xb77_compression` con `solana_poseidon` syscall
- `sdk/` actual (Zig + TS via `bun:ffi`)
- `cli/main.zig` (1158 líneas, fuente de la extracción de keystore)
- Webapp + docs (vinieron en el merge desde docs-v2)

El otro worktree (`docs-v2`, `feat/docs-vitepress`) está trabajando el dapp-public-split en paralelo. No tocar webapp acá.

## Primer paso al volver

```bash
cd /home/exp1/Desktop/xB77/worktree/merge-onchain-deluxe
git status                                                # confirmar limpio
git log --oneline -5                                      # confirmar 6649a1e en top
cat docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.md   # spec completo
git checkout -b feat/sdk-wasm-deluxe
```

## Plan de ejecución (resumen — ver spec §9 para detalle)

| # | Fase | Horas | Estado |
|---|---|---|---|
| 1 | Extraer `keystore` + `signed-request builder` a `core/keystore/` y `core/sdk/` | 4 | v1.0 |
| 2 | WASM build pipeline (`zig build wasm`) + ABI exports | 2 | v1.0 |
| 3 | Wrapper TypeScript (reemplaza `bun:ffi` por `WebAssembly`) | 2 | v1.0 |
| ~~4~~ | ~~Wrapper Python (`wasmtime-py`)~~ | ~~2~~ | **v1.1** |
| 5 | Wrapper Rust (`wasmtime` crate) | 2 | v1.0 (re-añadido) |
| 6 | Tests + ejemplo e2e contra mock gateway (HTTP real, WebCrypto independiente) | 1 | v1.0 (reducido) |
| 6b | Cross-conformance Zig native ↔ TS ↔ Rust byte-identical | 0.5 | v1.0 |
| 7 | Buffer + READMEs (TS + Rust) | 0.5 | v1.0 |
| **Total v1.0** | | **8** | |

**Fallback si Fase 1 excede 5h**: scope cae a "AWP + keystore solamente"; `build_signed_request` se va a v1.1.

## Cierre completo del proyecto (post-SDK, ~2.5 hrs restantes del budget)

Después de Fase 7, en ESTA misma rama:

| # | Tarea | Horas |
|---|---|---|
| C1 | Merge final de worktrees pendientes (verificar product-deluxe, fix-onchain-battle) | 0.5 |
| C2 | Devnet deploy (fondear payer + 3 programas + correr demo --cluster devnet, capturar tx sigs públicas) | 1 |
| C3 | CF deploy (Pages + Worker via wrangler — requiere login previo) | 0.5 |
| C4 | Rewrite commits proton → noreply (filter-branch quirúrgico al final, una sola pasada) | 0.25 |
| C5 | Build deluxe ReleaseSafe + verificación final + bajar servicios | 0.25 |
| **Total cierre** | | **2.5** |

**Si Fase SDK excede 9.5h**: cae primero CF deploy (C3) → queda solo devnet. Si excede 10.5h: cae devnet (C2) → queda solo localnet evidence. Decidir EN EL MOMENTO, no antes.

## Decisiones lockeadas (no re-brainstormear)

- **Scope**: B (merchant-complete). NO scope A (mucho wrapper), NO scope C (MCP/proof/admin → worktree futuro).
- **v1.0 wrappers**: solo Zig native + TS. Python y Rust = v1.1 (ABI estable garantizada, wrappers post-hackathon).
- **Arquitectura**: pure-WASM stateless. WASM **no** hace red. Cada wrapper hace HTTP en su idioma nativo.
- **ABI**: ~10 funciones (ver §5 del spec). JSON cross-boundary (no bincode/postcard).
- **Action enum**: una sola `build_signed_request(action, …)` con enum `u8`. NO N funciones separadas.
- **Distribución v1.0**: `@xb77/sdk` (npm). PyPI + crates.io en v1.1.

## Riesgos a vigilar (§10 del spec)

- Zig → `wasm32-freestanding`: allocator + no-libc constraints. **Mitigación**: buildear el artifact en Fase 2 antes de tocar wrappers. Fail fast.
- `wasmtime-py` ABI quirks (memory pointers). **Mitigación**: Python wrapper después del TS para tener referencia.
- `std.json` en WASM: chequear performance. **Mitigación**: bench en Fase 1; fallback a parser hand-rolled si lento.
- Firma determinística cross-runtime: Ed25519 OK, pero RNG-for-nonce paths revisar. **Mitigación**: tests cross-conformance en Fase 6.

## Success criteria (§11 del spec)

1. `xb77_core.wasm` builds clean.
2. Los 4 targets (Zig native, TS, Py, Rust) producen output **byte-idéntico** para el mismo input.
3. Worked example end-to-end (Python: seal keystore → build order → POST gateway local → verify) pasa contra el podman gateway.
4. READMEs de los 3 wrappers muestran ejemplo canónico (ver §7 del spec).

## Out of scope acá

- **dapp-public-split** → worktree `docs-v2` (en paralelo).
- **CLI modularization** → sesión futura, se beneficia de que `core/keystore/` quede extraído por este trabajo.
- **MCP / proof-verify / admin** (scope C) → worktree futuro sin nombre todavía.

## Frase de arranque sugerida

> "Vuelvo a labura SDK WASM-core deluxe en merge-onchain-deluxe. Leé este HANDOFF y el spec en `docs/superpowers/specs/2026-05-11-sdk-wasm-core-deluxe-design.md`. Arrancamos Fase 1: extracción de keystore a `core/keystore/`."

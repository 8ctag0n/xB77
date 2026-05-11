# 🔁 HANDOFF — Post-Deluxe Gateway v1 + SDK 1.1

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/gateway-realdata`
> **Branch**: `feat/gateway-realdata`
> **Estado**: ✅ Backend gateway v1 100% implementado contra contract. SDK bumped a wire schema 1.1 byte-identical across Zig+TS+Rust.
> **Tests verdes**: 67 (6 zig + 12 rust + 27 ts + 22 worker)
> **Cerrado**: 2026-05-11 noche

---

## TL;DR de qué cambió esta sesión

1. **Wire schema bump 1.0 → 1.1** — agregamos `nonce` 12B + ts en ms + agent_id derivado server-side + `X-API-Version` + idempotency. Canonical bytes siguen binarios (sin JSON canonicalization), preservando la propiedad byte-identical cross-language.

2. **SDK propagado en los 3 lenguajes**:
   - `core/sdk/sdk.zig` — `buildSignedRequest` ahora toma `nonce: [12]u8` + `timestamp_unix_ms`
   - `sdk/wasm/exports.zig` — ABI bumped a 1.1, nuevo param nonce_ptr/nonce_len
   - `sdk/ts/src/index.ts` — wrapper TS con defaults (`nonce` ← `crypto.getRandomValues`, `timestampMs` ← `Date.now()`)
   - `sdk/rs/src/lib.rs` — wrapper Rust, switch a `wasmtime::Func` untyped (TypedFunc tuples capean a 16 params, ahora son 19)
   - `sdk/ts/dev/mock-gateway.ts` + `sdk/rs/examples/cross_fixture.rs` actualizados

3. **Contract v1 (`docs/api-contract-v1.md`)** — fully reescrito al wire 1.1. Incluye §1.5 wire-schema versioning con feature flag para acceptance de schema 1.0.

4. **Gateway worker (`gateway/worker/src/index.js`)** — 640 líneas, single-file:
   - 4 signed actions: `register_agent`, `submit_order`, `claim_credits`, `query_pulse`
   - 7 reads: `network/pulse`, `network/audit`, `agents/fleet`, `agents/:id`, `pipelines/recent`, `wallet/balances`, `wallet/transactions`
   - Auth middleware: Ed25519 verify + ts skew ±30s + nonce replay (KV 5min TTL) + agent_id = `"ag_" + hex(sha256(pubkey)[:9])`
   - Rate-limit token bucket per agent_id (o per-IP unauth), 4 tiers, action costs, `X-RateLimit-*` headers, 429+`Retry-After`
   - Idempotency cache `X-Idempotency-Key` (KV 24h TTL)
   - Gateway response signing (`X-Xb77-Gateway-Signature`)
   - CORS preflight + back-compat aliases (`/api/network/pulse` → `/api/v1/network/pulse`)
   - Dual-schema toggle via `ACCEPT_SCHEMA_1_0` env var

5. **Wrangler config (`gateway/worker/wrangler.toml`)** — 5 KV namespaces declaradas (`AGENTS`, `ORDERS`, `NONCES`, `BUCKETS`, `IDEMP`), `GATEWAY_PRIVKEY_HEX_DEV` con una keypair real generada para dev local.

---

## Cómo correr todo localmente

### Build + Tests
```bash
cd /home/exp1/Desktop/xB77/worktree/gateway-realdata

# Zig: build + tests nativos
zig build           # compila CLI, znode-server, ambos WASM
zig build test      # corre TODOS los tests Zig — debe exit 0
zig build sdk-wasm  # produce zig-out/bin/xb77_core.wasm

# SDK TS tests (necesita el wasm)
cd sdk/ts && bun test       # 27 verde

# SDK Rust tests
cd sdk/rs && cargo test     # 12 verde

# Worker tests (sin wrangler — mockea KV en memoria)
cd gateway/worker && bun test   # 22 verde
```

### Dev server (cuando tengas wrangler instalado)
```bash
cd gateway/worker
bunx wrangler@latest dev --local --port 8787

# Smoke desde otra terminal:
curl -i http://127.0.0.1:8787/                  # gateway metadata + pubkey
curl -i http://127.0.0.1:8787/api/v1/network/pulse
curl -i -X POST http://127.0.0.1:8787/api/v1/actions/register_agent \
  -H 'Content-Type: application/json' \
  -d '{"pubkey":"<64-hex-pubkey>","intent_hint":"merchant","client_version":"@xb77/sdk@1.1.0"}'
```

---

## Próximos pasos (orden sugerido)

### Path A — Cierre de hackathon (8-10h)

1. **Merge** `feat/gateway-realdata` al destino que prefieras (probablemente `merge/onchain-deluxe` primero para sincronizar SDK 1.1, y de ahí a `bedrock`).

2. **E2E visual webapp ↔ gateway** — el frontend (worktree `docs-v2`, branch `feat/dapp-public-split`) tiene que pinear `XB77_GATEWAY` al worker. Hasta que se haga eso, sigue contra el mock `sdk/ts/dev/mock-gateway.ts`.

3. **Deploy CF**:
   ```bash
   cd gateway/worker
   wrangler login                          # interactivo
   for ns in AGENTS ORDERS NONCES BUCKETS IDEMP; do
     wrangler kv namespace create "$ns"
   done
   # Pegar los IDs devueltos en wrangler.toml (reemplazar los `*_local_placeholder`)
   # Generar key prod:  bun -e 'const k = await crypto.subtle.generateKey("Ed25519", true, ["sign","verify"]); ...'
   wrangler secret put GATEWAY_PRIVKEY_HEX
   wrangler deploy
   ```
   Tomar la URL devuelta (`https://xb77-adapter.<account>.workers.dev`) y pinearla en frontend.

4. **Phantom wallet adapter** en webapp — sin esto Colosseum judges restan. El SDK actualmente firma con un keystore interno; agregar Phantom es ~2h: usar `@solana/wallet-adapter` para extraer la pubkey + presentar un challenge para que Phantom firme la primera vez (luego cachear).

5. **Programa Solana real onchain** — el ZK verifier vive en `merge/onchain-deluxe` como stub. Si querés Colosseum-readiness, hay que:
   - Desplegar un programa Anchor mínimo a devnet (basta con `anchor_proof_commit(proof_hash: [u8;32])`)
   - Llamarlo desde `submit_order` cuando una order completa
   - Mostrar la tx en el frontend con link a `explorer.solana.com/...?cluster=devnet`

6. **Demo video 60s** + pitch refresh.

### Path B — Si no llegamos a Colosseum (extender hackathon)

Lo construido es production-quality. Los gaps (Phantom, programa Solana, demo) son work-of-hours, no work-of-architecture. Recomiendo no entregar a Colosseum si no se cierran 4-5 antes; el código merece mejor puntaje que el que sacaríamos sin ellos.

---

## Decisiones técnicas que vale la pena tener presentes

- **Canonical bytes binarios** (no JSON canonical) — esto es lo que permite byte-identical cross-language. Cambiar a JSON canonical sería un foot-gun masivo (RFC 8785/JCS son un nido de bugs en práctica). Si en el futuro alguien propone "agreguemos signing JSON-style", la respuesta corta es **no**.

- **agent_id derivation server-side** (`sha256(pubkey)[:9]`) — el cliente nunca lo envía. Esto permite rotar keys en el futuro manteniendo identidad (cuando agreguemos key-rotation envelope).

- **Dual-schema toggle** (`ACCEPT_SCHEMA_1_0` env) — quedó listo por si aparece un cliente legacy. En prod debe estar OFF; el código defaultea a OFF.

- **wasmtime tuple cap a 16 params** — por eso `build_signed_request` en Rust usa `Func` untyped en vez de `TypedFunc`. Si en el futuro extendemos el ABI a más de 19 params, ya estamos cubiertos.

- **Gateway dev key**: la pubkey actual es `0b7695d319c619c0c80bb667407765107c4538f1a6cc2df1e5701acf1255822c`. **Esto es solo para dev** — en prod la secret `GATEWAY_PRIVKEY_HEX` toma precedencia.

---

## Si algo se rompe — rollback

- **SDK rollback**: tag `pre-sdk-wasm-deluxe-2026-05-11` te lleva al estado pre-SDK-deluxe.
- **Backend rollback**: `git reset --hard 9bf5618` te deja en el estado pre-implementación (contract committed, sin backend).
- **Si el gateway falla en prod**: el frontend tiene fallback en cascada (`DataSource` cached → snapshot). No es disruption total.

---

## Frase de arranque para próxima sesión

> "Estado: gateway v1 completo + SDK 1.1 byte-identical, 67 tests verde. Falta merge → e2e visual → deploy CF → Phantom → programa Solana onchain. Leé `HANDOFF-NEXT-SESSION.md` para el detalle. Arrancamos por el merge o saltamos directo a Phantom?"

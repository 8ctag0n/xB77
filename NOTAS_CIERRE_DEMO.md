# NOTAS · Cierre Demo Deluxe

Estado al **2026-05-10** (post product-deluxe). Para retomar cuando mergeemos con la rama onchain.

## Veredicto honesto

Tier 2 hoy: muy buen vision-demo, pero se cae en Q&A técnico. Con los P0 abajo sube a tier 1 (producto creíble en vivo).

---

## P0 — sin esto NO competimos

### 1. Deploy real del gateway (URL pública)
- **Síntoma:** `zig-out/bin/gateway.wasm` sale en 120 bytes (stub). `gateway.xb77.com` no responde.
- **Por qué duele:** el Blink que generamos en CLI apunta a `https://gateway.xb77.com/api/actions/pay`. Cualquier juez que lo pegue en `dial.to` ve error. Lo mismo con la landing y el `/audit/<sig>`.
- **Acción:**
  - Revisar `gateway/worker.js` + el wrapper de Cloudflare Workers (o evaluar fly.io con el binario nativo de gateway si pesa la rama).
  - Verificar que `wasm` step de `build.zig` realmente compila las routes (hoy parece stub).
  - Apuntar DNS / ruta o usar URL temporal de workers.dev y reemplazar `gateway.xb77.com` en `core/commerce/merchant.zig:99` y `gateway/main.zig` (landing CTAs).

### 2. Una transacción real anclada en devnet
- **Síntoma:** todas las entradas de receipt en el demo tienen `tx_hash: "zk_ghost_pending"`. Audit hace `getTransaction(tx_hash)` contra devnet → NOT FOUND. Cinematic se rompe.
- **Por qué duele:** el "ghost receipt" pierde su mejor momento (verificación matemática contra L1).
- **Acción:**
  - Necesita los programas Solana de la rama `fix-onchain-battle` (Agente 2) desplegados en devnet con SOL en la cuenta del agente.
  - Alternativa de bajo riesgo para demo: hardcodear UN signature real (el del primer anchor exitoso post-merge) y pre-cargarlo en `profiles/hack-demo.toml` como `demo_anchor_sig`. El demo script lo usa para el final del Act 4.
  - El audit ya está listo para mostrar slot+blockTime reales — solo necesita una sig que exista.

---

## P1 — pulir la presentación

### 3. Modo `XB77_DEMO=1` silencioso
- **Síntoma:** cada comando imprime:
  ```
  [Vault] ADVERTENCIA: Vault guardado en texto plano (Modo Inseguro). (x3)
  [MAGIC] Initiating Sovereign Session...
  [SOLANA] Tx failed: AccountNotFound
  [MAGIC] ShadowWire initialization failed: InvalidResponse
  ```
- **Acción:**
  - Wrappear esos `std.debug.print` en `core/security/vault.zig` y `core/magicblock/*.zig` con un `if (std.process.hasEnvVar("XB77_DEMO"))`.
  - Idealmente: ya hay precedente — `cli/main.zig:414` lee `XB77_DEMO`. Reusar el patrón.

### 4. Bug de memoria en `merchant.deinit`
- **Síntoma:** `core/commerce/merchant.zig:88` `allocator.free(self.business_name)` panic con "Invalid free" cuando se ejecuta después de ciertos comandos (ver crash en `xb77 receipt` resuelto bypaseando `ctx.deinit`).
- **Causa probable:** `business_name` puede ser literal cuando `load()` no encuentra archivo (línea 47: `"xB77 Sovereign Agent"`), o se sobrescribe sin liberar el dupe original en `handleSetupShop` (cli/main.zig:839).
- **Acción:** marcar con un flag `owned: bool` o garantizar dupe en todos los paths.

---

## P2 — backup defensivo

### 5. Grabar video del demo
- 60-90s capturando el flow ideal (`hackathon_demo.sh` ejecutado a mano, sin errores).
- Por si la red del venue falla o devnet RPC se cae durante la presentación.

---

## Lo que YA está deluxe (no tocar)

- Build (`zig build` ✅ con zig 0.15.2 / binutils 2.46 — fix en `build.zig` con ABI gnu + PIE off)
- `xb77 watch` con figlet, gauge animado y feed real desde `ledger.jsonl`
- `xb77 receipt [sig]` card cyberpunk
- `xb77 merchant blink` JSON spec-compliant (multi-tier + Custom Tip parametrizado)
- Landing `/` cyberpunk en gateway (cuando se despliegue)
- Audit portal con fetch RPC real (cuando haya sig real)
- Branding SVG en `/api/brand/blink-icon.svg`

---

## Coordinación con Agente 2 (rama onchain)

Lo que necesitamos del merge con `fix-onchain-battle`:

1. Programas Solana **desplegados en devnet** con program IDs estables.
2. Cuenta del agente del demo (`profiles/hack-demo.toml`) **funded** con SOL.
3. Una corrida exitosa del flow CMT → ZK proof → anchor on-chain. Capturar la sig.
4. Confirmar que el `worker.js` del gateway sigue compatible con las rutas que agregamos:
   - `GET /` → landing
   - `GET /api/brand/blink-icon.svg` → SVG
   - `GET /audit/:sig` → portal con RPC fetch

---

## Orden recomendado post-merge

1. Merge con onchain → desplegar gateway → verificar URL pública.
2. Correr el flow real, capturar sig, hardcodearla en demo script.
3. Wrappear logs con `XB77_DEMO=1`.
4. Fix `merchant.deinit`.
5. Grabar video backup.
6. **Demo ready.**

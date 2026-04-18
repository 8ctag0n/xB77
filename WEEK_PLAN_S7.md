# WEEK PLAN S7: THE SOVEREIGN SWAP
**Goal:** Pivot from 3rd party protocols to the native ZDK (Zig-based Development Kit).

## ✅ Progress Checkpoint (Current Session)
- [x] **Limpieza Total:** Limpiamos la estructura del proyecto, eliminando el "ruido" de infraestructuras viejas y consolidando el core en Zig.
- [x] **Identidad Dual:** Implementada la generación y manejo de llaves para Solana y EVM en `core/crypto.zig`.
- [x] **Cerebro (Policies):** Programada la lógica de límites de gasto y validación de políticas en `core/core.zig`.
- [x] **Fontanería (Transaction Serializer):** Implementado el serializador de transacciones de Solana en `core/tx.zig`, incluyendo soporte para compact-u16 y firmas.
- [x] **El Latido (Engine):** Estructura del motor 24/7 con integración MCP lista en `core/engine.zig`.

## 🛠️ Next Session Roadmap
- [ ] **Fix Writer Types:** Corregir los últimos errores de tipos en el `Writer` de Zig (punteros `const` vs `var`).
- [ ] **First Real Payment:** Ejecutar `xb77 pay` y verificar la transacción en Solana Devnet.
- [ ] **Z-Node Bridge:** Iniciar el bridge en Rust para conectar los Yellowstone Streams (QuickNode) con el core en Zig.
- [ ] **Stylus Integration:** Probar la compilación de las Policies a WASM para su ejecución en Arbitrum Stylus.

## Success Criteria
- **Simple:** `xb77` compila y realiza un pago básico en Solana Devnet de forma nativa.
- **Ambicioso:** El agente procesa transacciones automáticas filtradas por políticas de gasto y notificadas vía MCP.

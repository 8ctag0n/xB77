# Technical Debt: Zig v0.16.0 Upgrade

Esta migración ha sido masiva debido al cambio radical en `std.Io`. Aquí se listan las deudas pendientes para estabilizar el sistema:

### 1. Solana & RPC (`solana.zig`, `solana_rpc.zig`)
- **getSignatureStatus:** Se requiere una implementación robusta que maneje correctamente el polling y la recuperación de errores de red con el nuevo `std.http.Client`.
- **Deserialización JSON:** Muchos campos de los resultados de RPC están siendo extraídos manualmente de `std.json.Value`. Sería ideal migrar a structs fuertemente tipados con `parseFromSlice`.

### 2. Networking & IO (`http.zig`, `mesh.zig`)
- **IO Singleton:** Actualmente estamos abusando de `std.Io.Threaded.global_single_threaded.io()` en muchos lugares ("panic patching"). Se debería pasar la instancia de `io` de forma descendente desde el `main`.
- **HTTP Client State:** La gestión de la memoria de `std.http.Client` en v0.16.0 es más estricta. Hay que revisar fugas en los defer de `request`.

### 3. C-Compatibility (`crypto.zig`, `cmt.zig`)
- **base58ToBytes:** Está usando un `DebugAllocator` interno temporal porque la función original perdió el acceso al asignador global. Necesita refactor para recibir un `Allocator`.
- **Extern functions:** Verificar si el `rdynamic` y los símbolos exportados para el Bridge de C siguen funcionando con la nueva convención de nombres de v0.16.

### 4. Build System
- **Hardcoded paths:** Algunos paths de librerías de sistema en `build.zig` (como multiarch linux) deberían ser detectados dinámicamente usando el nuevo `b.graph.io`.

### 5. Formatting
- **Hex conversion:** Dado que `fmtSliceHexLower` desapareció, se están usando loops manuales en `arbitrum_adapter.zig`. Sería mejor mover esto a una utilidad central en `crypto.zig`.

---
*Nota:* El build nativo está al ~90% de éxito. El build de Stylus (WASM) está al 100%.

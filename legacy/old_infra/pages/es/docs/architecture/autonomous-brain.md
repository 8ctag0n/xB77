# El Cerebro Autónomo: Ejecución Estratégica

::: info Estado de Traducción
Este documento ha sido traducido parcialmente.
:::

El agente xB77 gestiona una línea de ejecución híbrida, eligiendo la ruta más eficiente y privada para cada transacción.

## 1. Privacidad Multi-Riel
- **Pagos Blindados (ShadowWire):** El riel por defecto para transacciones B2B seguras.
- **Flujos Ofuscados (Privacy Cash):** Enrutamiento a través de pools para romper el análisis on-chain.
- **Recibos Comprimidos ZK (Light Protocol):** Almacenamos el historial de forma privada on-chain usando compresión ZK.

## 2. Lógica de Decisión
- **Escaneo Forense:** Verificación de riesgo del destinatario.
- **Selección de Ruta:** Elige entre ShadowWire, Privacy Cash o **Modo Fantasma** (wallet efímera).
- **Control de Gobernanza:** Bloqueo automático (Lockdown) si se superan los límites de seguridad.

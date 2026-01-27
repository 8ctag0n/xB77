# The Autonomous Brain: Strategic Execution

The xB77 agent manages a hybrid execution pipeline, choosing the most efficient and private route for every transaction.

## 1. Multi-Rail Privacy
Instead of a single payment method, the agent routes funds through specialized protocols depending on the risk and privacy requirements:

- **Shielded Payments (ShadowWire):** The default rail for secure B2B transactions. Uses stealth-like logic to decouple sender and receiver.
- **Obfuscated Flows (Privacy Cash):** For transactions requiring high anonymity, the agent routes funds through a liquidity pool to break chain-link analysis.
- **ZK-Compressed Receipts (Light Protocol):** Every transaction, regardless of the rail, generates a compressed receipt. This ensures that the agent's history is stored on-chain but remains invisible to public explorers.

## 2. Decision Logic
When an intent is received via **MCP**, the `PaymentStrategyEngine` performs:
1.  **Forensic Scan:** Checks the destination address via Helius/Range simulation.
2.  **Route Selection:** 
    - Low Risk -> ShadowWire (Fast & Shielded).
    - High Privacy Need -> Privacy Cash (Pool Obfuscation).
    - Critical Value -> **Ghost Mode** (Burner wallet relay).
3.  **Governance Check:** If the amount exceeds the autonomous limit, it triggers a **Lockdown** in the Hub.

---

# El Cerebro Autónomo: Ejecución Estratégica (ES)

El agente xB77 gestiona una línea de ejecución híbrida, eligiendo la ruta más eficiente y privada para cada transacción.

## 1. Privacidad Multi-Riel
- **Pagos Blindados (ShadowWire):** El riel por defecto para transacciones B2B seguras.
- **Flujos Ofuscados (Privacy Cash):** Enrutamiento a través de pools para romper el análisis on-chain.
- **Recibos Comprimidos ZK (Light Protocol):** Almacenamos el historial de forma privada on-chain usando compresión ZK.

## 2. Lógica de Decisión
- **Escaneo Forense:** Verificación de riesgo del destinatario.
- **Selección de Ruta:** Elige entre ShadowWire, Privacy Cash o **Modo Fantasma** (wallet efímera).
- **Control de Gobernanza:** Bloqueo automático (Lockdown) si se superan los límites de seguridad.
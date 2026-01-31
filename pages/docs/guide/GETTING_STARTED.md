# Operation Guide

This guide details how to deploy and operate an xB77 Autonomous CFO agent within your infrastructure.

## 1. System Requirements
- **Runtime:** Bun v1.1.0 or higher.
- **Network:** Access to Solana (Mainnet/Devnet) via Helius RPC.
- **Storage:** Local SQLite for private receipt persistence.

## 2. Quick Ignition
To start the ecosystem, you need three distinct components running in parallel. Open three terminals:

```bash
# Terminal 1: The Infrastructure (Listener)
# Manages private state, history, and governance requests.
bun run mcp/src/listener.ts

# Terminal 2: The Interface (Hub)
# Local merchant dashboard for visualization and human oversight.
bun run hub/index.ts

# Terminal 3: The Agent (Brain - HTTP Mode)
# The MCP server that executes tools. HTTP is required for Hub interaction.
bun run mcp/src/http.ts
```

> **Note:** If you only want to use the agent via a local CLI/IDE without the Hub, you can use `bun run mcp/src/index.ts` to connect via **Stdio**.

## 3. Demo Components Explained
1.  **Listener (:7002):** The source of truth for the local environment. It watches Solana events and stores private receipts in SQLite.
2.  **Hub (:7777):** A Vite-powered dashboard that displays your Agent's "Thought Stream," balance (Liquid vs Yielding), and forensic radar.
3.  **MCP Agent (:7001):** The execution engine. It handles `agent.pay`, `agent.audit`, and `agent.strategy`.
If you are building your own agent, integrate the xB77 SDK to handle financial decisions:

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: myKeypair,
  minLiquidityThreshold: 100, // Top-up when below 100 USD1
  targetLiquidity: 500,       // Aim for 500 USD1 in shielded rail
  maxLiquidityThreshold: 1000 // Move excess to Kamino if above 1000
});

// Autonomous Payment with forensic pre-screening
const result = await agent.pay('RECIPIENT_PUBKEY', 50.00, 'USD1');
```

## 4. Governance Workflow
High-value or high-risk transactions will automatically trigger a **Lockdown Mode**. 
1. Agent detects risk via Helius/Range.
2. Transaction is paused.
3. Hub displays a red alert.
4. Human operator must click "Authorize" to provide an Ed25519 override signature.

## 5. Demo Proxy (Podman + nginx)

Si quieres grabar la demo con un solo puerto expuesto (ideal para túneles y grabaciones) puedes usar el proxy nginx empaquetado en `containers/demo-proxy`. Él recibe todo el tráfico en `http://localhost:7777`, sirve una landing estática y enruta los tres procesos reales hacia tu host.

1.  Mantén los tres componentes ejecutándose localmente como siempre, pero evita que el Hub use el puerto 7777 porque el proxy lo está escuchando:
    ```bash
    bun run mcp/src/listener.ts        # escucha webhooks en :7002
    PORT=7778 bun hub/index.ts          # UI en :7778 (proxy la expone en :7777)
    bun run mcp/src/http.ts             # MCP HTTP en :7001
    ```
2.  Construye el proxy de nginx usando Podman (puedes usar el nombre que prefieras):
    ```bash
    podman build -t xb77-demo-proxy containers/demo-proxy
    ```
3.  Ejecuta el proxy unificado (ajusta los puertos según lo que uses en el paso anterior):
    ```bash
    podman run --rm --name xb77-demo-proxy \
      -p 7777:7777 \
      -e HOST_ALIAS=host.containers.internal \
      -e HUB_PORT=7778 \
      -e LISTENER_PORT=7002 \
      -e MCP_PORT=7001 \
      xb77-demo-proxy
    ```
4.  Navega a `http://localhost:7777` en Chrome/Brave. Ahí verás la landing, con enlaces directos a `/hub/`, `/listener/health` y `/agent/health`.

Planea la grabación con las tres pestañas habituales (`Merchant Terminal`, `Governance`, `Tool Runner`), pero recuerda que el navegador se conecta siempre al puerto 7777. `podman logs -f xb77-demo-proxy` te ayuda a verificar los envíos de `/hub/`, `/listener/` y `/agent/`.

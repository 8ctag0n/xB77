# Guía de Operación

Esta guía detalla cómo desplegar y operar un agente CFO Autónomo xB77 dentro de su infraestructura.

## 1. Requisitos del Sistema
- **Runtime:** Bun v1.1.0 o superior.
- **Red:** Acceso a Solana (Mainnet/Devnet) vía Helius RPC.
- **Almacenamiento:** SQLite local para la persistencia de recibos privados.

## 2. Ignición Rápida
Para iniciar el ecosistema, necesita tres componentes distintos corriendo en paralelo:

```bash
# Terminal 1: La Infraestructura (Listener)
# Indexa el estado privado y gestiona la gobernanza global
bun run mcp/src/listener.ts

# Terminal 2: La Interfaz (Hub)
# Proporciona supervisión humana y visualización forense
bun run hub/index.ts

# Terminal 3: El Agente (Cerebro)
# El servidor MCP que ejecuta la lógica autónoma
bun run mcp/src/http.ts
```

## 3. Integración del SDK
Si está construyendo su propio agente, integre el SDK de xB77 para delegar las decisiones financieras:

```typescript
import { PrivacyAgent } from '@xb77/sdk';

const agent = new PrivacyAgent({
  keypair: miKeypair,
  minLiquidityThreshold: 100, // Recargar cuando baje de 100 USD1
  targetLiquidity: 500,       // Mantener 500 USD1 en riel protegido
  maxLiquidityThreshold: 1000 // Mover excedente a Kamino si supera los 1000
});

// Pago Autónomo con pre-escaneo forense
const resultado = await agent.pay('RECIPIENT_PUBKEY', 50.00, 'USD1');
```

## 4. Flujo de Gobernanza
Las transacciones de alto valor o alto riesgo activarán automáticamente el **Modo Lockdown**.
1. El agente detecta riesgo vía Helius/Range.
2. La transacción se pausa.
3. El Hub muestra una alerta roja.
4. El operador humano debe hacer clic en "Autorizar" para firmar el override vía Ed25519.

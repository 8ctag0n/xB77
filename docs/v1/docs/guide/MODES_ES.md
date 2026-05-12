---
pageClass: is-legacy-page
---
# Modos de Ejecución

Los agentes xB77 utilizan cuatro niveles de ejecución distintos para equilibrar costo, velocidad y privacidad estratégica.

## Nivel 1: Fiat Directo (Starpay)
- **Cuándo:** Bajo riesgo, proveedores confiables (ej., AWS, OpenAI).
- **Proceso:** El agente utiliza una liquidación mediante tarjeta virtual off-chain.
- **Privacidad:** Visible públicamente como una transacción de tarjeta tradicional (Riel Web2).
- **Costo:** Bajo (Comisiones de tarjeta estándar).

## Nivel 2: Transferencia Protegida (Light Protocol)
- **Cuándo:** Operaciones B2B estándar con entidades on-chain.
- **Proceso:** Los fondos se mueven dentro del pool privado comprimido por ZK.
- **Privacidad:** El monto y el destinatario están ocultos para los scanners públicos.
- **Costo:** Medio (Comisiones de relayer y verificación ZK).

## Nivel 3: Modo Fantasma (Relay Efímero)
- **Cuándo:** Adquisición de activos de alto valor o pagos sensibles de I+D.
- **Proceso:**
    1. El agente genera un par de llaves burner efímero.
    2. Una transferencia protegida interna fondea al burner.
    3. El burner ejecuta el pago final.
    4. Las llaves del burner se destruyen.
- **Privacidad:** Desacoplamiento total. No existe vínculo on-chain entre la Tesorería del Agente y el Vendedor.
- **Costo:** Alto (Requiere dos transacciones y gas adicional).

## Nivel 4: Optimizado (Modo Yield)
- **Cuándo:** Se detecta liquidez ociosa.
- **Proceso:** El agente retira fondos del Riel Protegido y los deposita en Kamino Lending.
- **Impacto:** Cubre automáticamente la "Tasa de Quema" (Burn Rate) operativa del agente.

---
pageClass: is-legacy-page
---
# Integración con Privacy Cash

**Estado:** ![Activo](https://img.shields.io/badge/Status-Activo-brightgreen)
**Rol:** Obfuscación de Transacciones y Ruptura de Enlaces

Mientras ShadowWire protege el *contenido* de una transacción, Privacy Cash está diseñado para romper el análisis de *tiempo y agrupación*. Funciona como un protocolo tipo mixer que agrega múltiples flujos pequeños en denominaciones estandarizadas para maximizar el conjunto de anonimato.

## La Capa de Obfuscación

Privacy Cash se sitúa entre la Tesorería del Agente y la ejecución final del pago.

- **Estandarización:** Todos los movimientos internos se desglosan en montos estándar (ej. 10, 100, 1000 USDC). Esto hace que todas las transacciones se vean idénticas en la cadena.
- **Relayers:** Las transacciones se despachan a través de una red de Relayers que pagan las tarifas de gas, disociando la billetera pública del Agente de la ejecución de la transacción.

## Integración con MCP
El Agente utiliza la herramienta `agent.privacy_cash.transfer` para enrutar pagos sensibles.

```typescript
// Ejecución de Herramienta MCP
await useTool('agent.privacy_cash.transfer', {
    amount: 500,
    recipient: 'vendor_address',
    obfuscationLevel: 'HIGH'
});
```

Esta herramienta calcula automáticamente el desglose óptimo de denominaciones y las enruta a través del protocolo Privacy Cash.

---
pageClass: is-legacy-page
---
# Integración MCP: La Interfaz Universal

::: info Estado de Traducción
Este documento ha sido traducido parcialmente.
:::

xB77 está construido sobre el **Model Context Protocol (MCP)**, un estándar abierto que permite a los modelos de IA interactuar con herramientas externas.

## ¿Por qué MCP?
- **Agnóstico al Modelo:** Funciona con cualquier IA (Claude, GPT, etc.).
- **Seguridad Estricta:** La IA solo puede ejecutar herramientas financieras validadas, no código arbitrario.
- **Contexto en Tiempo Real:** El agente inyecta estados financieros directamente en la "ventana de contexto" de la IA.

## Herramientas Disponibles
- `agent.pay`: Ejecuta un pago con selección de estrategia autónoma.
- `agent.strategy.evaluate`: Escanea riesgos antes de pagar.
- `agent.audit.report`: Genera un recibo certificado con ZK.

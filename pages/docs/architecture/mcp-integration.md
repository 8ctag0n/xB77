# MCP Integration: The Universal Interface

xB77 is built on the **Model Context Protocol (MCP)**, an open standard that enables AI models to interact with external tools and data sources seamlessly. 

## Why MCP?
- **Model Agnostic:** Whether you use Claude, GPT-4, or a local Llama model, the interface remains the same.
- **Strict Security:** Tools are explicitly defined. The LLM cannot execute arbitrary code; it can only request execution of validated financial tools.
- **Context Awareness:** The agent provides real-time state snapshots (balance, treasury efficiency, latest receipts) directly into the LLM's context window.

## Available Tools
The xB77 MCP Server exposes the following core capabilities:
- `agent.pay`: Executes a payment with autonomous strategy selection.
- `agent.strategy.evaluate`: Pre-screens a transaction for risk and compliance.
- `agent.status`: Retrieves the current financial health of the agent.
- `agent.audit.report`: Generates a ZK-certified selective disclosure for a specific receipt.
- `cfo.treasury.rebalance`: Triggers autonomous liquidity management between rails.

---

# Integración MCP: La Interfaz Universal (ES)

xB77 está construido sobre el **Model Context Protocol (MCP)**, un estándar abierto que permite a los modelos de IA interactuar con herramientas externas.

## ¿Por qué MCP?
- **Agnóstico al Modelo:** Funciona con cualquier IA (Claude, GPT, etc.).
- **Seguridad Estricta:** La IA solo puede ejecutar herramientas financieras validadas, no código arbitrario.
- **Contexto en Tiempo Real:** El agente inyecta estados financieros directamente en la "ventana de contexto" de la IA.

## Herramientas Disponibles
- `agent.pay`: Ejecuta un pago con selección de estrategia autónoma.
- `agent.strategy.evaluate`: Escanea riesgos antes de pagar.
- `agent.audit.report`: Genera un recibo certificado con ZK.

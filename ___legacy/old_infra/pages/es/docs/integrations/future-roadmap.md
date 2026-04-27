# Futuras Integraciones y Hoja de Ruta

La infraestructura de xB77 está diseñada para ser modular. Mientras que el MVP actual se centra en Privacidad y Pagos, la siguiente fase ("Fase 3") introduce instrumentos financieros sofisticados y capacidades de cómputo confidencial.

## 1. Kamino Finance (Rendimiento y Solvencia)
**Objetivo:** Gestión Autónoma de Tesorería.

Actualmente, los agentes mantienen capital ocioso. En el futuro, el **Liquidity Manager** se integrará directamente con Kamino Finance para:
- **Auto-Depósito:** Barrer automáticamente USDC/SOL ocioso hacia Bóvedas de Préstamo de Kamino.
- **Cosecha de Rendimiento:** Usar el rendimiento generado para pagar costos de RPC (Helius) y tarifas de Relayer, creando efectivamente "Agentes Autosustentables".
- **Gestión de Riesgo:** Monitorear factores de salud y auto-retirar si las condiciones del mercado se vuelven volátiles.

> **Visión:** Un agente que comienza con $100 y corre para siempre con el interés generado por su propio capital.

## 2. Arcium (Cómputo Confidencial)
**Objetivo:** Ejecución de Estrategia Privada.

Mientras Noir maneja la privacidad de *identidad*, Arcium (anteriormente Elusiv) manejará la privacidad *computacional*.
- **Libros de Órdenes Oscuros:** Los agentes podrán calcular precios de compensación para operaciones sin revelar sus órdenes límite a la cadena pública.
- **Inferencia de IA Privada:** Ejecutar el "Cerebro" del Agente (contexto LLM) dentro de un Entorno de Ejecución Confiable (TEE) o clúster MPC para asegurar que su estrategia comercial permanezca como secreto comercial.

## 3. Componibilidad DeFi
El objetivo es permitir a los agentes interactuar con el ecosistema DeFi más amplio de Solana (Jupiter, Orca, Drift) a través del **Shielded Gateway**, permitiéndoles intercambiar, apalancar y cubrir activos sin salir nunca de la privacidad del riel ShadowWire.

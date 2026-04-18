# xB77 — Sovereign Agent Infrastructure (REWIRE 2026)

Este documento centraliza la visión técnica y estratégica del rewrite en Zig, integrando Solana, EVM (Arbitrum Stylus) y orquestación por IA.

## 🎯 Objetivos Estratégicos
1.  **Dominio Multi-Chain**: Settlement nativo en Solana y L2s (Base/Arbitrum).
2.  **Infraestructura Verificable**: Uso de Arbitrum Stylus (WASM) para mover lógica de seguridad on-chain.
3.  **Operación 24/7**: Deploy en el Edge (Cloudflare Workers) con consciencia situacional vía Z-Node.
4.  **Simplicidad de Negocio**: Protocolo `xb77.json` para descubrimiento de merchants.

---

## 🛠️ Roadmap de Ejecución (Rewire Phase)

### Bloque 1: Cimientos Multichain (TERMINADO ✅)
- [x] Criptografía Ed25519 y Base58 (Solana).
- [x] Criptografía Keccak256 y Hex (EVM).
- [x] Identidad dual del agente.

### Bloque 2: El Cerebro Constitucional (EN CURSO 🚧)
- **Vault Policies**: Lógica de "Spend Limits" que impide que la IA vacíe los fondos.
- **Multi-Chain Router**: Selección automática entre SOL/USDC-SOL/USDC-Base.
- **ZK-Ready Receipts**: Recibos firmados para auditoría selectiva.

### Bloque 3: Los Ojos (Z-Node + Streams)
- **Yellowstone Bridge**: Conexión a QuickNode para ingerir bloques en tiempo real.
- **History Parser**: Convertir data cruda de la red en contexto para el LLM.
- **IPFS Checkpoints**: Publicación diaria de "State Proofs" en IPFS via QuickNode para auditabilidad descentralizada. 🚀

### Bloque 4: La Conexión AI (MCP Server)
- **Bridge a Claude**: Exponer herramientas para que la IA pueda investigar y actuar.
- **Autonomous Engine**: Loop de larga ejecución (24/7) en Zig.

### Bloque 5: Verificabilidad (Arbitrum Stylus)
- **Stylus Module**: Compilar el "Policy Verifier" de Zig a WASM para Arbitrum.
- **Grant Magnet**: Aplicar a Arbitrum Foundation por el uso novel de Zig en Stylus.

---

## 💰 Bounties & Grants Map
- **ETHGlobal OpenAgents (24 Abr)**: Presentar el stack multichain + Edge WASM.
- **Arbitrum Stylus**: Bounty por contratos en Zig/WASM.
- **Coinbase AgentKit**: Integración de xB77 como el rail de pagos oficial para AgentKit.
- **Colosseum (Solana)**: Z-Node y eficiencia extrema del runtime en Zig.

*"Tu agente no solo firma, decide. No solo paga, cumple."*

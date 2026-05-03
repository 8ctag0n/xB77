# WEEK PLAN S8: MULTI-CHAIN ASCENSION

**Estado:** Solana HFT funcional. Persistencia activa. Visión soberana definida.
**Meta:** Habilitar Ethereum/EVM y sentar las bases de Bitcoin Light Node.

##  Prioridades Inmediatas (Hackathon Ready)

1. **[EVM Crypto]**: Implementar Secp256k1 y Keccak256 en `core/crypto.zig`. Es el bloqueador principal para ETH/BTC.
2. **[EVM Client]**: Desarrollar el cliente RPC para Ethereum/Base en `core/evm.zig` (Get Nonce, Gas Price).
3. **[EVM Tx]**: Implementar el constructor de transacciones EIP-1559 en `core/tx.zig`.
4. **[AgentKit Bridge]**: Crear un adaptador para que el Engine pueda orquestar acciones de Coinbase AgentKit.

## ️ Tareas Técnicas / Deuda

- [ ] Integrar el nuevo `RiskScorer` (0.11% tax) en los flujos de EVM.
- [ ] Refactorizar `Vault` para manejar llaves Secp256k1 en paralelo a Ed25519.
- [ ] Prototipar el Verificador en Arbitrum Stylus (Zig to WASM).

##  Vision Milestones (Pre-Bitcoin)

- **Dual Identity**:  El agente muestra su dirección de Solana y Ethereum en el comando `status`.
- **EVM Direct Pay**: Primer pago exitoso en Base Devnet desde el CLI de Zig.
- **ZK-Verification**: Validar la primera ZK-Factura generada en una transacción de Base.

## Métricas de Éxito
- Soporte nativo Secp256k1 sin dependencias externas pesadas.
- Binario WASM compatible con Cloudflare Workers incluyendo lógica EVM.
- Latencia de firma Secp256k1 < 10ms.

## 🔜 Siguiente Fase: "Path to Production" (Un-Mocking)
Para la próxima sesión (post-hackathons), debemos reemplazar los mocks locales por integraciones reales:
1. **Brain (LLM)**: Habilitar cliente HTTP en `brain.zig` apuntando a Ollama local (`localhost:11434/api/generate`) para inferencia real con Gemma 4.
2. **Z-Node (Red)**: Reemplazar el mock por la conexión WebSocket WSS real a QuickNode/Helius en `znode.c` / `znode_bridge.zig`.
3. **Firmas en L1**: Enlazar la llave Ed25519 del `Vault` con `core/chain/solana.zig` para firmar y emitir las transacciones reales en Devnet/Mainnet en lugar de solo imprimir los logs.
